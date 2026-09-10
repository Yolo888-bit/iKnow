import { Colors } from '../common/Theme'

/** 极简柱状图（周学习趋势） */
@Component
export struct BarChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop values: number[] = []
  @Prop labels: string[] = []
  private chartH: number = 160

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(this.chartH)
      .onReady(() => {
        this.draw()
      })
  }

  private draw(): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    if (this.values.length === 0) {
      return
    }
    let maxV = 1
    for (const v of this.values) {
      if (v > maxV) {
        maxV = v
      }
    }
    const pad = 16
    const n = this.values.length
    const slot = (w - pad * 2) / n
    const barW = slot * 0.55
    const bottom = h - pad - 20
    const topH = h - pad * 2 - 20

    for (let i = 0; i < n; i++) {
      const v = this.values[i]
      const bh = topH * (v / maxV)
      const x = pad + i * slot + (slot - barW) / 2
      const y = bottom - bh
      c.fillStyle = Colors.PRIMARY
      c.fillRect(x, y, barW, bh)

      c.fillStyle = Colors.TEXT_SECONDARY
      c.font = '10px sans-serif'
      c.textAlign = 'center'
      const label = i < this.labels.length ? this.labels[i] : ''
      c.fillText(label, pad + i * slot + slot / 2, h - 6)
    }
  }
}
