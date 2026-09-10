import { Colors } from '../common/Theme'

/** 五维雷达图（个人专注画像，Canvas 绘制） */
@Component
export struct RadarChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop values: number[] = []
  @Prop labels: string[] = []
  @Prop chartSize: number = 260

  build() {
    Canvas(this.ctx)
      .width(this.chartSize)
      .height(this.chartSize)
      .onReady(() => {
        this.draw()
      })
  }

  private angle(i: number, n: number): number {
    return -Math.PI / 2 + i * 2 * Math.PI / n
  }

  private draw(): void {
    const c = this.ctx
    const n = this.values.length
    if (n === 0) {
      return
    }
    const cx = this.chartSize / 2
    const cy = this.chartSize / 2
    const r = this.chartSize / 2 - 30
    c.clearRect(0, 0, this.chartSize, this.chartSize)

    // 网格
    for (let g = 1; g <= 4; g++) {
      const rr = r * g / 4
      c.beginPath()
      for (let i = 0; i < n; i++) {
        const ang = this.angle(i, n)
        const x = cx + rr * Math.cos(ang)
        const y = cy + rr * Math.sin(ang)
        if (i === 0) {
          c.moveTo(x, y)
        } else {
          c.lineTo(x, y)
        }
      }
      c.closePath()
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1
      c.stroke()
    }

    // 轴线
    for (let i = 0; i < n; i++) {
      const ang = this.angle(i, n)
      c.beginPath()
      c.moveTo(cx, cy)
      c.lineTo(cx + r * Math.cos(ang), cy + r * Math.sin(ang))
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1
      c.stroke()
    }

    // 数据多边形
    c.beginPath()
    for (let i = 0; i < n; i++) {
      const ang = this.angle(i, n)
      const rr = r * Math.max(0, Math.min(100, this.values[i])) / 100
      const x = cx + rr * Math.cos(ang)
      const y = cy + rr * Math.sin(ang)
      if (i === 0) {
        c.moveTo(x, y)
      } else {
        c.lineTo(x, y)
      }
    }
    c.closePath()
    c.fillStyle = Colors.PRIMARY_SOFT
    c.fill()
    c.strokeStyle = Colors.PRIMARY
    c.lineWidth = 2
    c.stroke()

    // 顶点
    for (let i = 0; i < n; i++) {
      const ang = this.angle(i, n)
      const rr = r * Math.max(0, Math.min(100, this.values[i])) / 100
      c.fillStyle = Colors.PRIMARY
      c.beginPath()
      c.arc(cx + rr * Math.cos(ang), cy + rr * Math.sin(ang), 3, 0, Math.PI * 2)
      c.fill()
    }

    // 标签
    c.fillStyle = Colors.TEXT_SECONDARY
    c.font = '13px sans-serif'
    c.textAlign = 'center'
    for (let i = 0; i < n; i++) {
      const ang = this.angle(i, n)
      const lx = cx + (r + 20) * Math.cos(ang)
      const ly = cy + (r + 20) * Math.sin(ang)
      const value = `${this.labels[i]} ${Math.round(this.values[i])}`
      c.fillText(value, lx, ly + 4)
    }
  }
}
