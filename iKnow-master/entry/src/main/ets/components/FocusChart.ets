import { Colors } from '../common/Theme'
import { FocusStateUi } from '../common/FocusStateUi'

/** 专注曲线（绿/黄/红分段折线图，Canvas 绘制） */
@Component
export struct FocusChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop levels: number[] = []
  @Prop states: string[] = []
  private chartH: number = 180

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(this.chartH)
      .onReady(() => {
        this.draw()
      })
  }

  private yFor(level: number, h: number, pad: number): number {
    const ratio = Math.max(0, Math.min(100, level)) / 100
    return h - pad - ratio * (h - pad * 2)
  }

  private draw(): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    if (this.levels.length === 0) {
      return
    }
    const pad = 16
    const n = this.levels.length
    const stepX = (w - pad * 2) / Math.max(1, n - 1)

    // 基线
    c.strokeStyle = Colors.LINE
    c.lineWidth = 1
    c.beginPath()
    c.moveTo(pad, h - pad)
    c.lineTo(w - pad, h - pad)
    c.stroke()

    // 分段折线
    for (let i = 0; i < n - 1; i++) {
      const x1 = pad + i * stepX
      const x2 = pad + (i + 1) * stepX
      const y1 = this.yFor(this.levels[i], h, pad)
      const y2 = this.yFor(this.levels[i + 1], h, pad)
      const color = i < this.states.length ? FocusStateUi.color(this.states[i]) : Colors.GREEN
      c.strokeStyle = color
      c.lineWidth = 3
      c.beginPath()
      c.moveTo(x1, y1)
      c.lineTo(x2, y2)
      c.stroke()
    }

    // 首末数据点
    c.fillStyle = Colors.PRIMARY
    c.beginPath()
    c.arc(pad, this.yFor(this.levels[0], h, pad), 3, 0, Math.PI * 2)
    c.fill()
  }
}
