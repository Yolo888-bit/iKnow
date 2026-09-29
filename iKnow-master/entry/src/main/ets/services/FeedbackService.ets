import { vibrator } from '@kit.SensorServiceKit'
import { media } from '@kit.MediaKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { resourceManager } from '@kit.LocalizationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'
import { FocusTuning } from '../common/FocusTuning'
import { ReminderLines } from '../common/ReminderLines'
import { StorageService } from './StorageService'

const DOMAIN = 0x0000
const TAG = 'iKnow.Feedback'

/** 等播放真正开始的超时：既没到 playing 也没报错时，如实报"超时"而不是假装播过 */
const PLAY_TIMEOUT_MS = 3000

/**
 * 反馈服务 —— 分心时的触达手段（震动 + 语音）。
 *
 * 分级由 `FocusController.syncReminderTier()` 按**分心持续时长**驱动，这里只负责执行：
 *
 * | 等级 | 触发 | 动作 |
 * |---|---|---|
 * | 黄 20s | `vibrateShort()` | 短震一下（文字由界面状态文案负责） |
 * | 红 1min | `vibrateRed()` + `speakOnce()` | 连续震约 2s + 语音**播一遍** |
 * | 强 5min | `holdStrongVibration()` + `startVoiceLoop()` | 一直震（封顶 30s）+ 语音**一直循环** |
 *
 * 发声用**用户提供的语音包**（`resources/rawfile/` 的 mp3，见 `common/ReminderLines.ets`），
 * 不使用系统语音合成，也不上传任何东西。文案与音频的对应关系只有 `ReminderLines` 一份。
 *
 * ⚠️ **AVPlayer 必须走状态机**，不能设完 `fdSrc` 就直接 `play()`：
 *     fdSrc → initialized → `prepare()` → prepared → `play()` → playing
 *  `play()` 的文档前置条件是 prepared/paused/completed，跳步会抛 5400102
 *  Operation not allowed —— 表现就是"没有声音、也没有任何界面提示"。
 *
 * 所有调用**失败静默**：无振动器、权限未授、音频文件缺失、播放器报错，都不影响专注主流程。
 * 极简安静型（QUIET）**不出声也不震动** —— 它只有界面徽标（见 `ReminderLines` 表头）。
 */
export class FeedbackService {
  private static inst: FeedbackService | null = null
  /** 当前正在播放的播放器；非空即表示"正在响"，新的请求直接忽略，避免叠音 */
  private player: media.AVPlayer | null = null
  /** 正在播放的 rawfile 名：播完要按名 closeRawFdSync，不能泄漏 fd */
  private playingRawName: string = ''
  /** 最近一次发声的结果说明，供「我的 → 考伴 → 试听」如实显示 */
  private lastDiag: string = '还没试听过'
  /** 强提醒震动的续震定时器（-1 = 未在续震） */
  private strongTimerId: number = -1
  /** 强提醒震动已经震了多久（用于封顶） */
  private strongElapsedMs: number = 0

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

  /** 极简安静型：不出声也不震动，只有界面徽标 */
  private isSilentPersonality(): boolean {
    return this.currentPersonality() === 'QUIET'
  }

  // ---------- 震动 ----------

  /**
   * 黄灯：短震一下。
   *
   * 这里用**手机**震动，不假装手表 —— 当前设备没有手表，
   * 项目口径是"绝不假装震动"（`InterventionEngine` 里也有同一条：无手表 RED 走 phone-sound）。
   */
  vibrateShort(): void {
    this.vibrateFor(FocusTuning.VIBRATE_SHORT_MS)
  }

  /** 红灯：连续震动一段 */
  vibrateRed(): void {
    this.vibrateFor(FocusTuning.VIBRATE_RED_MS)
  }

  /**
   * 强提醒：持续震动，最长 `FocusTuning.VIBRATE_STRONG_MAX_MS` 就自动停（语音继续循环）。
   *
   * 分片续震的原因：部分设备对单次 `startVibration` 的时长有限制，一次给 30s 会被拒（401）
   * 从而完全不振。按 `VIBRATE_CHUNK_MS` 一块块续，既安全又能凑到封顶值。
   */
  holdStrongVibration(): void {
    if (this.strongTimerId >= 0) {
      return
    }
    if (!this.isVibrateOn() || this.isSilentPersonality()) {
      return
    }
    this.strongElapsedMs = 0
    this.vibrateFor(FocusTuning.VIBRATE_CHUNK_MS)
    this.strongTimerId = setInterval(() => {
      this.strongElapsedMs += FocusTuning.VIBRATE_CHUNK_MS
      if (this.strongElapsedMs >= FocusTuning.VIBRATE_STRONG_MAX_MS) {
        hilog.info(DOMAIN, TAG, '强提醒震动已达上限 %{public}d ms，停止震动（语音继续）',
          FocusTuning.VIBRATE_STRONG_MAX_MS)
        this.stopVibration()
        return
      }
      this.vibrateFor(FocusTuning.VIBRATE_CHUNK_MS)
    }, FocusTuning.VIBRATE_CHUNK_MS)
  }

  /** 停止震动（含正在续震的强提醒），幂等 */
  stopVibration(): void {
    if (this.strongTimerId >= 0) {
      clearInterval(this.strongTimerId)
      this.strongTimerId = -1
    }
    this.strongElapsedMs = 0
    try {
      vibrator.stopVibration().catch((): void => {})
    } catch (e) {
      // 没在震时可能抛，忽略
    }
  }

  private vibrateFor(ms: number): void {
    if (!this.isVibrateOn() || this.isSilentPersonality()) {
      return
    }
    try {
      vibrator.startVibration(
        { type: 'time', duration: ms },
        { usage: 'alarm' }
      ).catch((e: Error) => {
        hilog.info(DOMAIN, TAG, '震动不可用（可忽略）：%{public}s', e.message)
      })
    } catch (e) {
      hilog.info(DOMAIN, TAG, '震动调用异常（可忽略）')
    }
  }

  // ---------- 语音 ----------

  /** 红灯：播一遍当前人格的提醒（不循环） */
  speakOnce(): void {
    this.playReminder(false)
  }

  /** 强提醒：一直循环播到人回来（由 `stopReminder()` 停） */
  startVoiceLoop(): void {
    if (this.isReminding()) {
      return
    }
    this.playReminder(true)
  }

  /** 停止语音提醒（含正在循环的），幂等 */
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
    hilog.info(DOMAIN, TAG, '已停止语音提醒')
  }

  /** 停掉一切提醒（语音 + 震动）。回到专注、切模式、会话结束都走这里 */
  stopAll(): void {
    this.stopReminder()
    this.stopVibration()
  }

  /** 是否正在响（含循环中） */
  isReminding(): boolean {
    return this.player !== null
  }

  /** 最近一次发声的结果说明（诚实的失败原因，不是"应该可以"） */
  getDiagnosis(): string {
    return this.lastDiag
  }

  /** 当前人格的语音包情况（页面用来如实说明"这一档会不会出声"） */
  describeVoicePack(): string {
    const p = this.currentPersonality()
    if (p === 'QUIET') {
      return '极简安静型不出声、不震动：界面只显示「⚠️轻度分心 / 🔴重度分心」徽标'
    }
    if (!ReminderLines.hasVoice(p, 'HEAVY')) {
      return '当前人格还没有录音文件，分心时不会出声'
    }
    return '分心满 1 分钟播一遍，满 5 分钟一直循环到你回来为止'
  }

  /**
   * 试听：播一遍当前人格的提醒，**等播放真正开始/失败之后**再返回结果说明。
   *
   * 为什么必须等：播放是异步的，早先的实现直接返回"已播放…"，
   * 结果实际抛了 5400102（状态机跳步）却显示成功 —— 排查时完全被误导。
   */
  async tryout(): Promise<string> {
    if (!this.isVoiceOn()) {
      this.lastDiag = '语音提醒开关是关着的，先打开「识别到分心时语音提醒」'
      return this.lastDiag
    }
    const personality = this.currentPersonality()
    const line = ReminderLines.firstOf(personality, 'HEAVY')
    if (line === null) {
      this.lastDiag = personality === 'QUIET'
        ? '极简安静型不出声：界面只显示「⚠️轻度分心 / 🔴重度分心」徽标'
        : '当前人格还没有录音文件'
      return this.lastDiag
    }
    await this.playFile(line.file, line.text, false)
    return this.lastDiag
  }

  /** 取录音并起播（loop = 是否循环） */
  private playReminder(loop: boolean): void {
    if (!this.isVoiceOn()) {
      this.lastDiag = '语音提醒开关是关着的'
      return
    }
    // 已经在响就不重启：新的等级变化不该打断正在播的提醒
    if (this.isReminding()) {
      return
    }
    const line = ReminderLines.firstOf(this.currentPersonality(), 'HEAVY')
    if (line === null) {
      this.lastDiag = this.isSilentPersonality()
        ? '极简安静型不出声，本次只出界面徽标'
        : '没有可用的录音文件，本次只出界面提示'
      hilog.info(DOMAIN, TAG, '无对应录音：%{public}s', this.lastDiag)
      return
    }
    this.playFile(line.file, line.text, loop).catch((): void => {})
  }

  // ---------- 播放实现 ----------

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

  /** 释放播放器并归还 fd（系统要求配套 closeRawFdSync，否则播放次数多了会泄漏） */
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
