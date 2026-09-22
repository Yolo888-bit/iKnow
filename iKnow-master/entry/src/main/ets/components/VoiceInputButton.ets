import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { Colors } from '../common/Theme'
import { VoiceInputService, VoiceInputHandlers } from '../services/VoiceInputService'

/**
 * 按住说话按钮 —— 任务规划页与专注答疑页共用。
 *
 * 交互：按住 → 开始采集，松开 → 结束并等最终识别结果，结果通过 `onFinal` 交给页面写回输入框。
 * 按钮上方只显示状态小字（正在听 / 识别中），不逐字回显识别内容 —— 见 `onPartial` 处的说明。
 *
 * 降级：设备/模拟器用不了语音时，`VoiceInputService.start()` 返回 false，
 * 这里弹一句 toast 并把状态复位 —— 输入框本身始终可用，功能不因语音不可用而残缺。
 */
@Component
export struct VoiceInputButton {
  /** 最终识别结果；空串表示什么都没识别出来 */
  onFinal: (text: string) => void = (text: string) => {}

  /** 正被按住 */
  @State recording: boolean = false
  /** 松开后等结果的过渡态 */
  @State finishing: boolean = false
  /** 小字提示：等待授权 / 正在听 / 识别中 */
  @State hint: string = ''
  private timeoutId: number = -1
  /**
   * 正在进行的 `begin()`。
   * 启动是异步的（要申请权限、建引擎），用户"按一下马上松手"时 `end()` 可能先到，
   * 那时麦克风刚被打开却没人去关 —— 所以 `end()` 必须等这次启动落地再停。
   */
  private beginTask: Promise<void> | null = null

  aboutToDisappear(): void {
    this.clearTimer()
    // 离开页面时若还在录，主动放弃，不要留下悬空的采集会话
    VoiceInputService.getInstance().cancel().catch((): void => {})
  }

  private clearTimer(): void {
    if (this.timeoutId >= 0) {
      clearTimeout(this.timeoutId)
      this.timeoutId = -1
    }
  }

  private async begin(): Promise<void> {
    if (this.recording || this.finishing) {
      return
    }
    this.recording = true
    this.hint = '正在听…'
    const ctx = getContext(this) as common.UIAbilityContext
    const handlers: VoiceInputHandlers = {
      // 中间结果**不上屏**：逐字刷新会抖，而且输入行只有 360vp，
      // 一小段实时文字就会把输入框挤窄。松开后一次性给最终结果更稳。
      onPartial: (text: string): void => {},
      onFinal: (text: string): void => {
        this.clearTimer()
        this.finishing = false
        this.hint = ''
        this.onFinal(text)
      },
      onError: (message: string): void => {
        this.clearTimer()
        this.finishing = false
        this.hint = ''
        promptAction.showToast({ message: message })
      }
    }
    const ok = await VoiceInputService.getInstance().start(ctx, handlers)
    if (!ok) {
      this.recording = false
      this.hint = ''
    }
  }

  private async end(): Promise<void> {
    if (!this.recording) {
      return
    }
    this.recording = false
    this.finishing = true
    this.hint = '识别中…'
    // 兜底：系统语音服务没给最终结果时别把按钮永久锁在"识别中"
    this.clearTimer()
    this.timeoutId = setTimeout(() => {
      this.timeoutId = -1
      this.finishing = false
      this.hint = ''
    }, 10000)
    // 先等这次启动落地，否则"按一下马上松手"会让麦克风一直开着
    const starting = this.beginTask
    this.beginTask = null
    if (starting !== null) {
      await starting
    }
    await VoiceInputService.getInstance().stop()
  }

  build() {
    Column({ space: 2 }) {
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 84 })
      }

      Text(this.recording ? '🎙' : '🎤')
        .fontSize(20)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .borderRadius(22)
        .backgroundColor(this.recording ? Colors.CAMERA_RED : Colors.CARD)
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            const task = this.begin()
            this.beginTask = task
            task.catch((): void => {})
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.end().catch((): void => {})
          }
        })
    }
    .alignItems(HorizontalAlign.Center)
  }
}
