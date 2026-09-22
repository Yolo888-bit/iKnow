import { audio } from '@kit.AudioKit'
import { speechRecognizer } from '@kit.CoreSpeechKit'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PermissionService } from './PermissionService'
import { IdUtils } from '../utils/IdUtils'

const DOMAIN = 0x0000
const TAG = 'iKnow.Voice'

/** 识别引擎要求每次写入 640 或 1280 字节，这里固定按 1280 切块 */
const WRITE_CHUNK = 1280

/** 一次语音输入的出口：中间结果 / 最终结果 / 失败原因 */
export interface VoiceInputHandlers {
  onPartial: (text: string) => void
  onFinal: (text: string) => void
  onError: (message: string) => void
}

/**
 * 语音输入服务（按住说话 → 文字）。
 *
 * 链路：麦克风采集（`@kit.AudioKit` audioCapturer）→ 按 1280 字节切块喂给系统语音识别引擎
 * （`@kit.CoreSpeechKit` speechRecognizer）→ 中间结果实时回调、最终结果一次性回调。
 *
 * ⚠️ 关于"能不能用"，如实说明（不要当成已跑通）：
 *  - 本机只有手机模拟器，**这条链路大概率在模拟器上不可用**——模拟器往往没有真实麦克风输入，
 *    系统语音服务（SystemCapability.AI.SpeechRecognizer）也未必可用。因此本服务把"不可用"
 *    当成正常分支：所有异常都吞掉，由 `start()` 返回 false，页面提示改用键盘，
 *    绝不抛到页面、不影响打字。
 *  - 识别按**在线模式**请求，由系统语音服务完成（理由见 `ensureEngine()` 里的注释）。
 *  - 权限（ohos.permission.MICROPHONE）是 user_grant，start 前先走 PermissionService 申请。
 */
export class VoiceInputService {
  private static inst: VoiceInputService | null = null
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null
  private capturer: audio.AudioCapturer | null = null
  private sessionId: string = ''
  private listening: boolean = false
  /** 引擎创建结果缓存：-1 未探测 / 0 不可用 / 1 可用。避免每次按下都重试一遍建引擎 */
  private engineOk: number = -1
  /** 上一次写入剩下的零头，拼到下一块前面，避免 40ms 级的断音 */
  private carry: Uint8Array = new Uint8Array(0)

  static getInstance(): VoiceInputService {
    if (VoiceInputService.inst === null) {
      VoiceInputService.inst = new VoiceInputService()
    }
    return VoiceInputService.inst
  }

  isListening(): boolean {
    return this.listening
  }

  /** 创建识别引擎（失败即判定"这台设备用不了"，并缓存结论） */
  private async ensureEngine(): Promise<boolean> {
    if (this.engineOk === 0) {
      return false
    }
    if (this.engine !== null) {
      return true
    }
    try {
      const params: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        // ⚠️ 字段叫 online，但语义是反的：0 = 在线，1 = 离线（SDK 文档原文）。
        // 这里选**在线**：转出来的文字下一步就要发给云端模型做答疑，
        // 所以要求"语音识别必须在本机完成"并不能多保护什么，反而要赌设备装没装离线模型；
        // 在线识别的可用性和准确率都更稳。
        online: 0,
        extraParams: { 'recognitionMode': 0 }
      }
      this.engine = await speechRecognizer.createEngine(params)
      this.engineOk = 1
      return true
    } catch (e) {
      this.engine = null
      this.engineOk = 0
      hilog.info(DOMAIN, TAG, '语音识别引擎不可用（可忽略，走键盘输入）')
      return false
    }
  }

  /** 建麦克风采集器：16 kHz / 单声道 / 16 位 PCM，识别引擎要求的输入格式 */
  private async ensureCapturer(): Promise<audio.AudioCapturer> {
    if (this.capturer !== null) {
      return this.capturer
    }
    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    }
    const capturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    }
    const opts: audio.AudioCapturerOptions = {
      streamInfo: streamInfo,
      capturerInfo: capturerInfo
    }
    const c = await audio.createAudioCapturer(opts)
    this.capturer = c
    return c
  }

  /**
   * 把采集到的一块音频切成 640/1280 字节后写入引擎。
   * 零头留到下一块 —— 直接丢弃会在字与字之间留缝，识别会断字。
   */
  private writeAudioChunk(buffer: ArrayBuffer): void {
    const engine = this.engine
    if (engine === null || !this.listening) {
      return
    }
    const incoming = new Uint8Array(buffer)
    const merged = new Uint8Array(this.carry.length + incoming.length)
    merged.set(this.carry, 0)
    merged.set(incoming, this.carry.length)
    let off = 0
    while (off + WRITE_CHUNK <= merged.length) {
      try {
        engine.writeAudio(this.sessionId, merged.slice(off, off + WRITE_CHUNK))
      } catch (e) {
        // 单块写入失败（超长/引擎状态变化）不中断整段识别
      }
      off += WRITE_CHUNK
    }
    this.carry = merged.slice(off)
  }

  /**
   * 开始一次语音输入。返回 false 表示"这次用不了语音"，调用方应提示用户改用键盘 ——
   * 这是模拟器上最可能的分支，属于正常路径而非错误。
   */
  async start(ctx: common.UIAbilityContext, handlers: VoiceInputHandlers): Promise<boolean> {
    if (this.listening) {
      return false
    }
    // 先要系统权限；没给就直接走键盘
    const granted = await PermissionService.getInstance().ensureMicrophone(ctx)
    if (!granted) {
      handlers.onError('没有麦克风权限，直接打字也可以')
      return false
    }
    if (!await this.ensureEngine()) {
      handlers.onError('这台设备暂时用不了语音输入，直接打字吧')
      return false
    }
    const engine = this.engine
    if (engine === null) {
      handlers.onError('这台设备暂时用不了语音输入，直接打字吧')
      return false
    }

    this.sessionId = IdUtils.uuid()
    this.carry = new Uint8Array(0)

    // RecognitionListener 的五个回调都是必填，缺一个编译不过
    engine.setListener({
      onStart: (sessionId: string, eventMessage: string): void => {},
      onEvent: (sessionId: string, eventCode: number, eventMessage: string): void => {},
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
        if (sessionId !== this.sessionId) {
          return
        }
        const text = result.result.length > 0 ? result.result : ''
        if (result.isFinal) {
          handlers.onFinal(text)
        } else {
          handlers.onPartial(text)
        }
      },
      onComplete: (sessionId: string): void => {
        this.teardown()
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string): void => {
        hilog.info(DOMAIN, TAG, '识别出错：%{public}d %{public}s', errorCode, errorMessage)
        handlers.onError('没听清，再说一次或直接打字吧')
        // 出错也要把采集资源收干净，否则下一次按下会"启不起来"
        this.teardown()
      }
    })

    try {
      const audioInfo: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      }
      const startParams: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: audioInfo,
        extraParams: { 'recognitionMode': 0, 'vadBegin': 2000, 'vadEnd': 3000, 'maxAudioDuration': 20000 }
      }
      engine.startListening(startParams)

      const capturer = await this.ensureCapturer()
      capturer.on('readData', (buffer: ArrayBuffer) => {
        this.writeAudioChunk(buffer)
      })
      await capturer.start()
      this.listening = true
      return true
    } catch (e) {
      hilog.info(DOMAIN, TAG, '启动语音输入失败（可忽略）')
      this.teardown()
      handlers.onError('这台设备暂时用不了语音输入，直接打字吧')
      return false
    }
  }

  /**
   * 松开按钮：结束这次说话，等引擎给出最终结果（onComplete 里回收采集资源）。
   *
   * 判据用 `sessionId` 而不是 `listening`：`start()` 是异步的，
   * 用户"按一下马上松手"时 stop 可能赶在 start 落地之前到达 ——
   * 这时 listening 还是 false，按它判断就会直接返回，把麦克风留在开着。
   */
  async stop(): Promise<void> {
    const sid = this.sessionId
    if (sid.length === 0) {
      return
    }
    this.listening = false
    await this.stopCapturer()
    const engine = this.engine
    if (engine !== null) {
      try {
        engine.finish(sid)
        return
      } catch (e) {
        // finish 失败就直接回收，避免资源悬空
      }
    }
    this.teardown()
  }

  /** 主动放弃这次输入（如离开页面）：不产出结果 */
  async cancel(): Promise<void> {
    const sid = this.sessionId
    this.listening = false
    await this.stopCapturer()
    if (sid.length === 0) {
      return
    }
    const engine = this.engine
    if (engine !== null) {
      try {
        engine.cancel(sid)
      } catch (e) {
        // 忽略：cancel 失败也照样回收
      }
    }
    this.teardown()
  }

  private async stopCapturer(): Promise<void> {
    const c = this.capturer
    if (c === null) {
      return
    }
    this.capturer = null
    try {
      c.off('readData')
    } catch (e) {
      // 未注册过监听时会抛，忽略
    }
    try {
      await c.stop()
    } catch (e) {
      // 未 start 过时会抛，忽略
    }
    try {
      await c.release()
    } catch (e) {
      // 忽略
    }
  }

  /**
   * 清掉这一次的会话状态。
   * 只回收麦克风采集器，**引擎保留复用** —— 重建引擎有明显延迟，
   * 每次进页面都重建会让"按下说话"第一句明显卡顿。
   */
  private teardown(): void {
    this.listening = false
    this.sessionId = ''
    this.carry = new Uint8Array(0)
    if (this.capturer !== null) {
      // 不 await：这是从引擎回调里调的，不能阻塞回调线程
      this.stopCapturer().catch((): void => {})
    }
  }
}
