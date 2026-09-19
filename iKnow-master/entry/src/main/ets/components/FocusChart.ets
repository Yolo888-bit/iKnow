import { Colors } from '../common/Theme'
import { FocusStateUi } from '../common/FocusStateUi'

/**
 * 专注曲线（绿/黄/红分段**阶梯**图，Canvas 绘制）
 *
 * 诚实性约定（第三轮改造）：
 *  - 纵轴是「状态等级」（绿=92 / 黄=62 / 红=30 三档确定性取值），不是连续的"专注度"，
 *    因此画成阶梯线而非平滑曲线，并在图内标注纵轴含义。
 *  - 横轴按**真实分钟**线性排布（采样在状态切换时会额外触发，按采样索引等距会让时间比例失真）。
 */
@Component
export struct FocusChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop @Watch('redraw') levels: number[] = []
  @Prop states: string[] = []
  /** 与 levels 一一对应的「会话内相对分钟」，用于横轴按真实时间排布 */
  @Prop minutes: number[] = []
  /** 多次会话拼接时的分界点（分钟）：画虚线分隔，避免误读成一次连续学习 */
  @Prop separators: number[] = []
  private chartH: number = 180
  private ready: boolean = false

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(this.chartH)
      .onReady(() => {
        this.ready = true
        this.draw()
      })
  }

  private redraw(): void {
    if (this.ready) {
      this.draw()
    }
  }

  private yFor(level: number, h: number, pad: number): number {
    const ratio = Math.max(0, Math.min(100, level)) / 100
    return h - pad - ratio * (h - pad * 2)
  }

  /** 第 i 个采样点的横坐标：有 minutes 时按真实时间比例，否则退回按索引等距 */
  private xFor(i: number, w: number, pad: number): number {
    const n = this.levels.length
    const usable = w - pad * 2
    if (this.minutes.length !== n || n <= 1) {
      return pad + (n <= 1 ? 0 : i * usable / (n - 1))
    }
    const span = this.minutes[n - 1] - this.minutes[0]
    if (span <= 0) {
      return pad + i * usable / (n - 1)
    }
    const offset = this.minutes[i] - this.minutes[0]
    return pad + usable * offset / span
  }

  private draw(): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    if (this.levels.length === 0) {
      return
    }
    const pad = 10
    const n = this.levels.length

    // 三档参考线：让"高度代表什么"一眼可见（92 专注 / 62 走神 / 30 分心）
    const refLevels: number[] = [92, 62, 30]
    for (const lv of refLevels) {
      const y = this.yFor(lv, h, pad)
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1
      c.beginPath()
      c.moveTo(pad, y)
      c.lineTo(w - pad, y)
      c.stroke()
    }

    // 多次专注之间的分隔虚线
    if (this.separators.length > 0 && this.minutes.length === n && n > 1) {
      const m0 = this.minutes[0]
      const span = this.minutes[n - 1] - m0
      if (span > 0) {
        c.strokeStyle = Colors.TEXT_TERTIARY
        c.lineWidth = 1
        for (const sep of this.separators) {
          const x = pad + (w - pad * 2) * (sep - m0) / span
          if (x <= pad || x >= w - pad) {
            continue
          }
          c.beginPath()
          c.moveTo(x, pad)
          c.lineTo(x, h - pad)
          c.stroke()
        }
      }
    }

    // 基线
    c.strokeStyle = Colors.LINE
    c.lineWidth = 1
    c.beginPath()
    c.moveTo(pad, h - pad)
    c.lineTo(w - pad, h - pad)
    c.stroke()

    // 阶梯线：先水平走到下一个时间点，再垂直落到新等级
    for (let i = 0; i < n - 1; i++) {
      const x1 = this.xFor(i, w, pad)
      const x2 = this.xFor(i + 1, w, pad)
      const y1 = this.yFor(this.levels[i], h, pad)
      const y2 = this.yFor(this.levels[i + 1], h, pad)
      const color = i < this.states.length ? FocusStateUi.color(this.states[i]) : Colors.GREEN
      c.strokeStyle = color
      c.lineWidth = 3
      c.beginPath()
      c.moveTo(x1, y1)
      c.lineTo(x2, y1)
      c.stroke()

      if (y2 !== y1) {
        c.beginPath()
        c.moveTo(x2, y1)
        c.lineTo(x2, y2)
        c.stroke()
      }
    }

    // 首点
    c.fillStyle = Colors.PRIMARY
    c.beginPath()
    c.arc(this.xFor(0, w, pad), this.yFor(this.levels[0], h, pad), 3, 0, Math.PI * 2)
    c.fill()
  }
}
