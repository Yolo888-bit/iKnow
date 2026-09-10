import { Colors } from '../common/Theme'

/** 柔和圆环进度（用于今日专注概览） */
@Component
export struct CircularProgress {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop percent: number = 0
  @Prop boxSize: number = 140
  @Prop label: string = '净专注率'

  build() {
    Stack() {
      Canvas(this.ctx)
        .width(this.boxSize)
        .height(this.boxSize)
        .onReady(() => {
          this.draw()
        })

      Column() {
        Text(this.label)
          .fontSize(13)
          .fontColor(Colors.TEXT_SECONDARY)
        Text(`${this.percent}%`)
          .fontSize(30)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .margin({ top: 6 })
      }
    }
    .width(this.boxSize)
    .height(this.boxSize)
  }

  private draw(): void {
    const c = this.ctx
    const cx = this.boxSize / 2
    const cy = this.boxSize / 2
    const r = this.boxSize / 2 - 8
    c.clearRect(0, 0, this.boxSize, this.boxSize)
    c.lineWidth = 8
    c.lineCap = 'round'
    c.strokeStyle = Colors.LINE
    c.beginPath()
    c.arc(cx, cy, r, 0, Math.PI * 2)
    c.stroke()

    const start = -Math.PI / 2
    const end = start + Math.PI * 2 * this.percent / 100
    c.strokeStyle = Colors.PRIMARY
    c.beginPath()
    c.arc(cx, cy, r, start, end)
    c.stroke()
  }
}
