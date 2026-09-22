import { vibrator } from '@kit.SensorServiceKit'
import { media } from '@kit.MediaKit'
import { textToSpeech } from '@kit.CoreSpeechKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { resourceManager } from '@kit.LocalizationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'
import { StorageService } from './StorageService'
import { IdUtils } from '../utils/IdUtils'

const DOMAIN = 0x0000
const TAG = 'iKnow.Feedback'

/** 语音提醒的两种场景 */
export type ReminderKind = 'PHONE' | 'AWAY'

/**
 * 反馈服务 —— 云端**确认**分心后的触达手段。
 *
 * 设计约束（重要）：
 *  - 只在"识别结果明确"时调用，**且必须由状态机真正转入分心那一刻触发**
 *    （见 `FocusController.onDetection`），不跟手表线索联动 —— 线索一变就响会变成骚扰；
 *  - 所有调用**失败静默**：无振动器、权限未授、模拟器不支持、语音引擎或音频文件缺失，
 *    都不影响专注主流程。
 *
 * 发声走**两级通道**：
 *  ① 系统语音合成（`@kit.CoreSpeechKit` textToSpeech）—— 按文档以**离线模式**请求
 *     （`CreateEngineParams.online`：0 = 在线，1 = 离线。字段名叫 online 但语义是反的，别写错）。
 *     好处是提醒语能随人格变化，而且不必往仓库里塞音频文件。
 *  ② 内置音频文件（`resources/rawfile/`）—— 引擎建不起来时兜底。
 *     没放文件也不会报错，只是这一次没有声音，卡片照常出现。
 *
 * ⚠️ 引擎与离线中文音色是否存在取决于设备（本机只有模拟器，无法验证）。
 * 首次发声时探测一次，结论缓存下来；探测失败就整段会话都走 ②。
 */
export class FeedbackService {
  private static inst: FeedbackService | null = null
  /** 当前正在播放的播放器；非空即表示"正在响"，新的请求直接忽略，避免叠音 */
  private player: media.AVPlayer | null = null
  /** 正在播放的 rawfile 名：播完要按名 closeRawFdSync，不能泄漏 fd */
  private playingRawName: string = ''
  /** 语音合成引擎；懒建一次，之后复用 */
  private tts: textToSpeech.TextToSpeechEngine | null = null
  /** 引擎探测结论：-1 未探测 / 0 不可用 / 1 可用。避免每次提醒都重试一遍建引擎 */
  private ttsOk: number = -1

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

  /**
   * 语音提醒开关（默认**开**）。
   * 原先是默认关，理由是"依赖 HMS，环境不支持时无意义"；现在提醒音是内置音频文件，
   * 不依赖任何系统语音能力，默认关着只会让人以为功能没接上。
   */
  isVoiceOn(): boolean {
    return this.switchOn(StorageKey.VOICE_ON, true)
  }

  /**
   * 短震一次（约 0.3 秒）。用于"云端确认分心"的提醒。
   * 失败静默——没有振动器或权限未授时不该影响专注流程。
   */
  vibrateOnce(): void {
    if (!this.isVibrateOn()) {
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

  /** 兜底音频文件名：放在 `entry/src/main/resources/rawfile/` 下，可选 */
  private fileNameOf(kind: ReminderKind): string {
    return kind === 'PHONE' ? 'remind_phone.wav' : 'remind_away.wav'
  }

  /**
   * 兜底通道：播放内置提醒音（仅在语音合成引擎不可用时走这里）。
   *
   * 缺文件 / 播放失败都只记一行日志，**不弹错、不打断专注流程** ——
   * 没放音频文件是正常情况（提醒语本来就由语音合成负责），
   * 不能因为没放文件就让专注页出问题。
   */
  private async playReminder(kind: ReminderKind): Promise<void> {
    const name = this.fileNameOf(kind)
    const ctx = StorageService.getInstance().appContext()
    if (ctx === null) {
      return
    }
    let raw: resourceManager.RawFileDescriptor
    try {
      raw = ctx.resourceManager.getRawFdSync(name)
    } catch (e) {
      // 文件不存在时会抛 —— 这是"还没录音频"的正常情况，不当成错误
      hilog.info(DOMAIN, TAG, '提醒音 %{public}s 不存在，本次只出提示卡片', name)
      return
    }
    // 先记下文件名：这样后面任何一步失败，`releasePlayer()` 都能把 fd 还回去
    this.playingRawName = name
    try {
      const player = await media.createAVPlayer()
      this.player = player
      player.on('stateChange', (state: media.AVPlayerState) => {
        // 播完或出错都要释放，否则下一次请求会被"正在播"挡住，提醒从此哑掉
        if (state === 'completed' || state === 'error') {
          this.releasePlayer()
        }
      })
      player.on('error', (err: BusinessError) => {
        hilog.info(DOMAIN, TAG, '提醒音播放失败（可忽略）：%{public}s', err.message)
        this.releasePlayer()
      })
      player.fdSrc = { fd: raw.fd, offset: raw.offset, length: raw.length }
      player.play()
      hilog.info(DOMAIN, TAG, '播放分心提醒音：%{public}s', name)
    } catch (e) {
      hilog.info(DOMAIN, TAG, '提醒音播放器创建失败（可忽略），本次只出提示卡片')
      this.releasePlayer()
    }
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

  /**
   * 按考伴人格给一句提醒词 —— **本地模板**，不走网络。
   * 分心那一刻需要的是立刻出声，等一次大模型往返会把"提醒"变成"迟到"。
   */
  private reminderText(kind: ReminderKind): string {
    const p: string = AppStorage.get<string>(StorageKey.USER_PERSONALITY) ?? 'GENTLE'
    if (kind === 'PHONE') {
      if (p === 'STRICT') {
        return '手机先放下，把手头这条做完。'
      }
      if (p === 'QUIET') {
        return '放下手机，继续。'
      }
      return '看到你在看手机，我们回来接着学吧。'
    }
    if (p === 'STRICT') {
      return '人不在座位上，回来继续。'
    }
    if (p === 'QUIET') {
      return '回来继续。'
    }
    return '画面里没看到你，还在吗？回来接着学吧。'
  }

  /**
   * 分心语音提醒（按场景）。
   *
   * 优先用系统语音合成朗读；**建引擎失败**（设备没这能力）才回落到内置音频文件。
   * 引擎建起来了但某次朗读出错就只记日志 —— 那时多半已经出声，
   * 再放一遍音频文件会变成重复提醒。
   *
   * 全程不 await、不抛出：触达不能阻塞专注主流程。
   */
  speak(kind: ReminderKind): void {
    if (!this.isVoiceOn()) {
      return
    }
    const text = this.reminderText(kind)
    hilog.info(DOMAIN, TAG, '分心提醒：%{public}s', text)
    this.byVoiceChannel(text, kind).catch((): void => {})
  }

  /**
   * 先试语音合成，不行再放音频文件。
   *
   * 只对音频通道做"正在播就跳过"的判断：语音合成那边不需要 ——
   * 提醒只在确认转入分心时触发，而红级冷却就有 5 分钟，两次提醒不可能挨在一起。
   */
  private async byVoiceChannel(text: string, kind: ReminderKind): Promise<void> {
    if (this.player !== null) {
      hilog.info(DOMAIN, TAG, '上一次提醒音还在播，忽略这次请求')
      return
    }
    if (this.ttsOk !== 0 && await this.ensureTts()) {
      this.speakByTts(text)
      return
    }
    await this.playReminder(kind)
  }

  /** 建语音合成引擎（只在首次发声时探测一次，结论缓存） */
  private async ensureTts(): Promise<boolean> {
    if (this.ttsOk === 0) {
      return false
    }
    if (this.tts !== null) {
      return true
    }
    try {
      const params: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 0,
        // 0 = 在线，1 = 离线（SDK 文档口径，与字段名相反）。这里要的是离线。
        online: 1
      }
      this.tts = await textToSpeech.createEngine(params)
      this.ttsOk = 1
      hilog.info(DOMAIN, TAG, '语音合成引擎就绪（离线）')
      return true
    } catch (e) {
      this.tts = null
      this.ttsOk = 0
      hilog.info(DOMAIN, TAG, '语音合成引擎不可用，回落到内置提醒音')
      return false
    }
  }

  /**
   * 念一句提醒词。回调只做记录 —— 已经出声了，这时候再回落到音频文件反而会重复响。
   */
  private speakByTts(text: string): void {
    const engine = this.tts
    if (engine === null) {
      return
    }
    const requestId = IdUtils.uuid()
    engine.setListener({
      onStart: (id: string, response: textToSpeech.StartResponse): void => {},
      onComplete: (id: string, response: textToSpeech.CompleteResponse): void => {},
      onStop: (id: string, response: textToSpeech.StopResponse): void => {},
      onError: (id: string, errorCode: number, errorMessage: string): void => {
        hilog.info(DOMAIN, TAG, '语音合成出错（可忽略）：%{public}d %{public}s', errorCode, errorMessage)
      }
    })
    try {
      engine.speak(text, { requestId: requestId })
    } catch (e) {
      hilog.info(DOMAIN, TAG, '语音合成调用失败（可忽略）')
    }
  }
}
