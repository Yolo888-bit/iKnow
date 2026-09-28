import { vibrator } from '@kit.SensorServiceKit'
import { media } from '@kit.MediaKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { resourceManager } from '@kit.LocalizationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'
import { ReminderLines, ReminderLevel } from '../common/ReminderLines'
import { StorageService } from './StorageService'

const DOMAIN = 0x0000
const TAG = 'iKnow.Feedback'

/** 等播放真正开始的超时：既没到 playing 也没报错时，如实报"超时"而不是假装播过 */
const PLAY_TIMEOUT_MS = 3000

/**
 * 反馈服务 —— 云端**确认**分心后的触达手段。
 *
 * 设计约束（重要）：
 *  - 只在"识别结果明确"时调用，且由 `FocusController.evaluateIntervention()` 在
 *    **产生了重度干预事件**时触发（那条路径自带冷却与 10 分钟预算），
 *    不跟手表线索联动 —— 线索一变就响会变成骚扰；
 *  - 所有调用**失败静默**：无振动器、权限未授、音频文件缺失、播放器报错，
 *    都不影响专注主流程。
 *
 * 发声用**用户提供的语音包**（`resources/rawfile/` 下的 mp3，见 `common/ReminderLines.ets`），
 * 不使用系统语音合成。文案与音频的对应关系只有 `ReminderLines` 一份，这里不重写句子。
 *
 * ⚠️ **AVPlayer 必须走状态机**，不能设完 `fdSrc` 就直接 `play()`：
 *     fdSrc → initialized → `prepare()` → prepared → `play()` → playing
 *  `play()` 的文档前置条件是 prepared/paused/completed，跳步会抛 5400102
 *  Operation not allowed —— 表现就是"没有声音、也没有任何界面提示"。
 *
 * 哪些情况**不出声**（都是设计如此，不是故障）：
 *  - 轻度（黄灯）：语音包只有重度文案，没有轻度录音；
 *  - 极简安静型：产品要求"无文字话术、无语音"，只出界面徽标；
 *  - 分心未持续到重度门槛（见 `FocusTuning.INTERVENTION_HEAVY_AFTER_MS`）。
 */
export class FeedbackService {
  private static inst: FeedbackService | null = null
  /** 当前正在播放的播放器；非空即表示"正在响"，新的请求直接忽略，避免叠音 */
  private player: media.AVPlayer | null = null
  /** 正在播放的 rawfile 名：播完要按名 closeRawFdSync，不能泄漏 fd */
  private playingRawName: string = ''
  /** 最近一次发声的结果说明，供试听按钮如实显示 */
  private lastDiag: string = '还没试听过'

  static getInstance(): FeedbackService {
    if (FeedbackService.inst === null) {
      FeedbackService.inst = new FeedbackService()
    }
    return FeedbackService.inst
  }

  private switchOn(key: string, defaultOn: boolean): boolean {
    const raw: number | undefined = AppStorage.get<number>(key)
    if (raw === undefined) {
      return defaultOn
    }
    return raw === 1
  }

  /** 震动开关（默认开） */
  isVibrateOn(): boolean {
    return this.switchOn(StorageKey.VIBRATE_ON, true)
  }

  /** 语音提醒开关（默认**开**） */
  isVoiceOn(): boolean {
    return this.switchOn(StorageKey.VOICE_ON, true)
  }

  private currentPersonality(): string {
    return AppStorage.get<string>(StorageKey.USER_PERSONALITY) ?? 'GENTLE'
  }

  /**
   * 短震一次。用于"确认分心"的提醒。
   *
   * 极简安静型**不震**：产品给它的设定是"手表轻震/强震 + 界面徽标"，
   * 而当前设备没有手表 —— 按项目既有的"绝不假装震动"口径，它就只有徽标。
   */
  vibrateOnce(): void {
    if (!this.isVibrateOn() || this.currentPersonality() === 'QUIET') {
      return
    }
    try {
      vibrator.startVibration(
        { type: 'time', duration: 300 },
        { usage: 'alarm' }
      ).catch((e: Error) => {
        hilog.info(DOMAIN, TAG, '震动不可用（可忽略）：%{public}s', e.message)
      })
    } catch (e) {
      hilog.info(DOMAIN, TAG, '震动调用异常（可忽略）')
    }
  }

  // ---------- 发声 ----------

  /**
   * 重度分心提醒：播当前人格对应的那段录音（同人格多段轮换），并**一直循环**下去。
   *
   * 循环是产品要求：确认长时间分心之后，提醒要一直响到人回来为止，
   * 而不是响一句就没了。停止由 `FocusController.syncVoiceLoop()` 在**离开分心态**时调用
   * `stopReminder()` —— 也就是说：回到专注、休息、暂停、答疑、结束都会立刻停。
   *
   * 不 await、不抛出 —— 触达不能阻塞专注主流程。
   */
  remind(level: ReminderLevel): void {
    if (!this.isVoiceOn()) {
      this.lastDiag = '语音提醒开关是关着的'
      return
    }
    // 已经在循环就不重启（也避免白白推进轮换游标、跳过一句录音）——
    // 新的重度事件不该打断正在响的循环
    if (this.isReminding()) {
      this.lastDiag = '提醒正在循环播放中，本次不重启'
      return
    }
    const line = ReminderLines.nextForVoice(this.currentPersonality(), level)
    if (line === null) {
      // 没有对应录音：极简安静型、或这一档本来就没录音 —— 如实记下，不假装播过
      this.lastDiag = ReminderLines.hasVoice(this.currentPersonality(), level)
        ? '没有可用的录音文件'
        : `${this.currentPersonality()} 的${level === 'HEAVY' ? '重度' : '轻度'}提醒没有录音，本次只出界面提示`
      hilog.info(DOMAIN, TAG, '无对应录音：%{public}s', this.lastDiag)
      return
    }
    this.playFile(line.file, line.text, true).catch((): void => {})
  }

  /**
   * 停止提醒（含正在循环的）。
   * 幂等：没在播时什么都不做 —— 状态同步点（`FocusController.syncVoiceLoop`）每秒都会调它。
   */
  stopReminder(): void {
    if (this.player === null) {
      return
    }
    const p = this.player
    try {
      p.stop().catch((): void => {})
    } catch (e) {
      // 忽略：状态不允许 stop 时直接释放也一样停
    }
    this.releasePlayer()
    hilog.info(DOMAIN, TAG, '已停止分心提醒')
  }

  /** 是否正在响（含循环中）—— 供状态同步点判断，避免重复启动 */
  isReminding(): boolean {
    return this.player !== null
  }

  /**
   * 试听：播一句当前人格的重度提醒，**等播放真正开始/失败之后**再返回结果说明。
   *
   * 为什么必须等：播放是异步的，早先的实现直接返回"已播放…"，
   * 结果实际抛了 5400102（状态机跳步）却显示成功 —— 排查时完全被误导。
   * 现在只有真的进到 playing 才算成功，出错/超时都如实回显。
   */
  async tryout(): Promise<string> {
    if (!this.isVoiceOn()) {
      this.lastDiag = '语音提醒开关是关着的，先打开「识别到分心时语音提醒」'
      return this.lastDiag
    }
    const personality = this.currentPersonality()
    const line = ReminderLines.nextForVoice(personality, 'HEAVY')
    if (line === null) {
      this.lastDiag = personality === 'QUIET'
        ? '极简安静型不出声：界面只显示「⚠️轻度分心 / 🔴重度分心」徽标'
        : '当前人格还没有录音文件'
      return this.lastDiag
    }
    // 试听只播一遍，不循环 —— 循环是"分心没回来"才有的行为
    await this.playFile(line.file, line.text, false)
    return this.lastDiag
  }

  /** 最近一次发声的结果说明（诚实的失败原因，不是"应该可以"） */
  getDiagnosis(): string {
    return this.lastDiag
  }

  /** 当前人格的语音包情况（页面用来如实说明"这一档会不会出声"） */
  describeVoicePack(): string {
    const p = this.currentPersonality()
    if (p === 'QUIET') {
      return '极简安静型不出声：界面只显示「⚠️轻度分心 / 🔴重度分心」徽标'
    }
    if (!ReminderLines.hasVoice(p, 'HEAVY')) {
      return '当前人格还没有录音文件，分心时不会出声'
    }
    return '重度分心后一直循环播放，回到专注就停（同一人格的多段录音轮流使用）'
  }

  /**
   * 播放一个 rawfile 音频。返回 true = 真的开始播了。
   *
   * AVPlayer 的状态机（**必须按顺序走**，跳步会抛 5400102）：
   *   createAVPlayer() → idle
   *   设 fdSrc        → initialized   ← 在这里 prepare()
   *   prepare() 完成  → prepared      ← 在这里 play()
   *   play()          → playing
   *
   * `loop = true` 时用播放器自带的循环（播完停在 playing，不会到 completed），
   * 要停只能由 `stopReminder()` 显式来停。
   */
  private playFile(file: string, text: string, loop: boolean): Promise<boolean> {
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      if (this.player !== null) {
        this.lastDiag = '上一次提醒还在播，本次跳过'
        hilog.info(DOMAIN, TAG, '上一次提醒还在播，忽略这次请求')
        resolve(false)
        return
      }
      const ctx = StorageService.getInstance().appContext()
      if (ctx === null) {
        this.lastDiag = '拿不到应用上下文，无法播放'
        resolve(false)
        return
      }
      let raw: resourceManager.RawFileDescriptor
      try {
        raw = ctx.resourceManager.getRawFdSync(file)
      } catch (e) {
        hilog.info(DOMAIN, TAG, '语音包文件 %{public}s 读不到', file)
        this.lastDiag = `语音包文件 ${file} 读不到（rawfile 里没有？），本次只出界面提示`
        resolve(false)
        return
      }

      let settled = false
      let timer: number = -1
      const finish = (ok: boolean, note: string): void => {
        if (settled) {
          return
        }
        settled = true
        if (timer >= 0) {
          clearTimeout(timer)
          timer = -1
        }
        this.lastDiag = note
        hilog.info(DOMAIN, TAG, '播放结果 %{public}s：%{public}s', ok ? 'OK' : 'FAIL', note)
        if (!ok) {
          this.releasePlayer()
        }
        resolve(ok)
      }

      this.playingRawName = file
      media.createAVPlayer().then((player: media.AVPlayer): void => {
        this.player = player
        // 循环播放由播放器自己做（播完自动重头），比在 completed 里手动重播可靠
        player.loop = loop
        // 超时兜底**必须先挂上**：状态回调可能在 fdSrc 赋值后立刻到达，
        // 那时若还没挂 timer，成功路径就漏掉了清理（定时器会白跑 3 秒）
        timer = setTimeout(() => {
          finish(false, `播放超时（${PLAY_TIMEOUT_MS} ms 内没有进入播放状态）`)
        }, PLAY_TIMEOUT_MS)
        player.on('stateChange', (state: media.AVPlayerState) => {
          if (state === 'initialized') {
            // fdSrc 设好才会到这里；**先 prepare，不能直接 play**
            player.prepare().catch((e: BusinessError): void => {
              finish(false, `prepare 失败 ${e.code}：${e.message}`)
            })
          } else if (state === 'prepared') {
            player.play()
          } else if (state === 'playing') {
            finish(true, loop ? `正在循环播放 ${file}：「${text}」` : `正在播放 ${file}：「${text}」`)
          } else if (state === 'completed') {
            // 只在"播一遍"的模式下会到这里；循环模式下播放器自己重头，不会完成。
            // 释放掉，否则下一次请求会被"正在播"挡住，提醒从此哑掉。
            this.releasePlayer()
          } else if (state === 'error') {
            finish(false, '播放状态变为 error')
          }
        })
        player.on('error', (err: BusinessError) => {
          finish(false, `播放失败 ${err.code}：${err.message}`)
        })
        player.fdSrc = { fd: raw.fd, offset: raw.offset, length: raw.length }
      }).catch((err: BusinessError): void => {
        finish(false, `播放器创建失败 ${err.code}：${err.message}`)
      })
    })
  }

  private releasePlayer(): void {
    const p = this.player
    if (p !== null) {
      this.player = null
      try {
        p.release().catch((): void => {})
      } catch (e) {
        // 忽略
      }
    }
    // fd 用完要还回去（系统要求配套 close），否则播放次数多了会泄漏
    const name = this.playingRawName
    this.playingRawName = ''
    if (name.length === 0) {
      return
    }
    const ctx = StorageService.getInstance().appContext()
    if (ctx === null) {
      return
    }
    try {
      ctx.resourceManager.closeRawFdSync(name)
    } catch (e) {
      // 忽略
    }
  }
}
