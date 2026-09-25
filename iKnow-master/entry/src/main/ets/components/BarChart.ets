import { Colors } from '../common/Theme'

/** 极简柱状图（周学习趋势） */
@Component
export struct BarChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop @Watch('redraw') values: number[] = []
  @Prop labels: string[] = []
  private chartH: number = 160
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

  /** Canvas 的 font 单位是物理 px（画布坐标是 vp）：直接写 px 在高密度屏上只有 1/3 大小 */
  private fontOf(vpSize: number): string {
    return `${vp2px(vpSize)}px sans-serif`
  }

  private draw(): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    if (this.values.length === 0) {
      return
    }
    // 量程：按「学习时长（分钟）」自适应 —— 纵轴上限紧贴这一周里最长的那天，
    // 向上取整到 5 分钟的整数倍，起步下限 10 分钟（避免"只学 1 分钟也把柱子画满"）。
    // 轻度使用（十几分钟）时顶端也会跟着变（12→15、28→30、33→35），不会出现"卡在 30"。
    let peak = 0
    for (const v of this.values) {
      if (v > peak) {
        peak = v
      }
    }
    const scale = Math.max(10, Math.ceil(peak / 5) * 5)

    const padLeft = 34
    const padRight = 12
    const bottom = h - 34
    const top = 12
    const topH = bottom - top
    const n = this.values.length
    const slot = (w - padLeft - padRight) / n
    const barW = slot * 0.55

    // 纵轴刻度（0 / 一半 / 满格）+ 网格线：让"柱子代表多少分钟"可核对
    c.font = this.fontOf(11)
    c.textAlign = 'right'
    const ticks: number[] = [scale, scale / 2, 0]
    for (const t of ticks) {
      const y = bottom - topH * (t / scale)
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1
      c.beginPath()
      c.moveTo(padLeft, y)
      c.lineTo(w - padRight, y)
      c.stroke()
      c.fillStyle = Colors.TEXT_TERTIARY
      c.fillText(`${Math.round(t)}`, padLeft - 6, y + 4)
    }

    for (let i = 0; i < n; i++) {
      const v = this.values[i]
      const bh = topH * (v / scale)
      const x = padLeft + i * slot + (slot - barW) / 2
      const y = bottom - bh
      c.fillStyle = Colors.PRIMARY
      c.fillRect(x, y, barW, bh)

      c.fillStyle = Colors.TEXT_SECONDARY
      c.font = this.fontOf(11)
      c.textAlign = 'center'
      const label = i < this.labels.length ? this.labels[i] : ''
      c.fillText(label, padLeft + i * slot + slot / 2, h - 8)
    }
  }
}
