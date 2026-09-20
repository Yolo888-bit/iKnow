import { Colors } from '../common/Theme'
import { FocusStateUi } from '../common/FocusStateUi'

/**
 * 专注状态时间轴（色带图，Canvas 绘制）
 *
 * 为什么不是"曲线"：底层数据是**离散的分段状态**（专注 / 轻度分心 / 分心），
 * 画成连续折线本身就是伪连续 —— 整场只有一种状态时，折线必然退化成一条水平直线，
 * 用户看到的就是"纵坐标怎么是一条线"。改成按段涂色的时间轴之后：
 *  - 一眼看出「什么时候是什么状态」「切换了几次」；
 *  - 只有一段时就是一条纯色带，语义正确，不会看起来像坏图；
 *  - 横轴标出分钟刻度（此前 `minutes` 只参与换算、从不显示，等于没有横轴）。
 *
 * 诚实性约定：
 *  - 颜色的含义只有三档（绿=专注 / 黄=轻度分心 / 红=分心），**不是**"专注度"连续值；
 *  - 白色竖线 = 多次专注之间的分界（同一天可能跑了好几段），含义由调用方的文字说明给出。
 */
@Component
export struct FocusChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop @Watch('redraw') levels: number[] = []
  @Prop states: string[] = []
  /** 与 levels 一一对应的「会话内相对分钟」，用于横轴按真实时间排布 */
  @Prop minutes: number[] = []
  /** 多次会话拼接时的分界点（分钟）：画竖线分隔，避免误读成一次连续学习 */
  @Prop separators: number[] = []
  /** 是否在图内画图例。调用方自己已经有图例时置 false，避免同一屏出现两份 */
  @Prop showLegend: boolean = true
  private chartH: number = 140
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

  /**
   * Canvas 的 `font` 单位是**物理 px**（默认值就是 `14px sans-serif`），而画布坐标是 vp。
   * 于是 `13px` 在 3x 屏上实际只有约 4vp —— 这就是"坐标文字小到看不见"的真正原因，
   * 只把数字从 9 调到 14 是没用的。统一按 vp 换算，让画布文字与页面上的字号同一尺度。
   */
  private fontOf(vpSize: number): string {
    return `${vp2px(vpSize)}px sans-serif`
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

  /** 色带覆盖的时间范围（分钟）：minutes 不可用时退回"第 0 分钟 → 第 n-1 分钟" */
  private timeRange(): number[] {
    const n = this.levels.length
    if (this.minutes.length === n && n > 0) {
      return [this.minutes[0], this.minutes[n - 1]]
    }
    return [0, Math.max(1, n - 1)]
  }

  private draw(): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    const n = this.levels.length
    if (n === 0) {
      return
    }
    const pad = 12
    const bandTop = this.showLegend ? 44 : 16
    const bandBottom = h - 30
    const bandH = bandBottom - bandTop

    // ---- 图例：颜色到底代表什么（这是上一版最缺的东西）----
    // 字号 13：与项目里一直在用的 RadarChart 同档；原来的 9~10 在手机上看不清。
    // 分界线（白色竖线）不进图例 —— 一是放不下（三档图例 + 长文案会超出画布宽），
    // 二是它只在按天复盘出现，那里已有文字说明。
    if (this.showLegend) {
      const legendStates: string[] = ['FOCUSED', 'SLIGHTLY_DISTRACTED', 'DISTRACTED']
      const legendNames: string[] = ['专注', '轻度分心', '分心']
      c.font = this.fontOf(11)
      c.textAlign = 'left'
      let lx = pad
      for (let i = 0; i < legendStates.length; i++) {
        c.fillStyle = FocusStateUi.color(legendStates[i])
        c.fillRect(lx, 7, 12, 12)
        c.fillStyle = Colors.TEXT_SECONDARY
        c.fillText(legendNames[i], lx + 16, 18)
        lx += 16 + legendNames[i].length * 11 + 14
      }
    }

    // 横轴的单位说明：横轴是时间（分钟）
    c.fillStyle = Colors.TEXT_TERTIARY
    c.font = this.fontOf(10)
    c.textAlign = 'left'
    c.fillText('分钟', pad, bandTop - 6)

    // ---- 色带：按段涂色 ----
    if (n === 1) {
      // 只有一个采样点：整条带就是那一个状态，语义上完全成立
      c.fillStyle = FocusStateUi.color(this.states.length > 0 ? this.states[0] : 'FOCUSED')
      c.fillRect(pad, bandTop, w - pad * 2, bandH)
    } else {
      for (let i = 0; i < n - 1; i++) {
        const x1 = this.xFor(i, w, pad)
        const x2 = this.xFor(i + 1, w, pad)
        const color = i < this.states.length ? FocusStateUi.color(this.states[i]) : Colors.GREEN
        c.fillStyle = color
        c.fillRect(x1, bandTop, Math.max(1, x2 - x1), bandH)
      }
    }
    c.strokeStyle = Colors.LINE
    c.lineWidth = 1
    c.strokeRect(pad, bandTop, w - pad * 2, bandH)

    // ---- 多次专注的分界：白色竖线压在色带之上 ----
    const range = this.timeRange()
    const span = range[1] - range[0]
    if (this.separators.length > 0 && span > 0) {
      c.strokeStyle = '#FFFFFF'
      c.lineWidth = 2
      for (const sep of this.separators) {
        const x = pad + (w - pad * 2) * (sep - range[0]) / span
        if (x <= pad || x >= w - pad) {
          continue
        }
        c.beginPath()
        c.moveTo(x, bandTop)
        c.lineTo(x, bandBottom)
        c.stroke()
      }
    }

    // ---- 横轴：分钟刻度（0 / 1/4 / 1/2 / 3/4 / 末点）----
    const ticks = 4
    c.font = this.fontOf(11)
    for (let k = 0; k <= ticks; k++) {
      const x = pad + (w - pad * 2) * k / ticks
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1
      c.beginPath()
      c.moveTo(x, bandBottom)
      c.lineTo(x, bandBottom + 5)
      c.stroke()
      const mv = range[0] + span * k / ticks
      c.fillStyle = Colors.TEXT_TERTIARY
      c.textAlign = k === 0 ? 'left' : (k === ticks ? 'right' : 'center')
      c.fillText(`${Math.round(mv)}`, x, bandBottom + 20)
    }
  }
}
