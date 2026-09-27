import { Colors } from '../common/Theme'

/** 五维雷达图（个人专注画像，Canvas 绘制） */
@Component
export struct RadarChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @Prop @Watch('redraw') values: number[] = []
  @Prop labels: string[] = []
  /** 哪些维度「无数据」：该轴用灰色虚线 + 「—」呈现，不再把缺失画成 0（看起来像最差） */
  @Prop missing: boolean[] = []
  @Prop chartSize: number = 260
  private ready: boolean = false

  build() {
    Canvas(this.ctx)
      .width(this.chartSize)
      .height(this.chartSize)
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
   * Canvas 的 font 单位是**物理 px**（画布坐标是 vp）：原来写 `13px` 在 3x 屏上只有约 4vp，
   * 等于五个维度的名字与数值一直没显示出来。统一按 vp 换算。
   */
  private fontOf(vpSize: number): string {
    return `${vp2px(vpSize)}px sans-serif`
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
    // 半径留出 40：标签要放到顶点外侧，字号变得可读之后必须给它们留位置（原来留 30 会画到画布外）
    const r = this.chartSize / 2 - 40
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
      if (this.missing[i]) {
        c.strokeStyle = Colors.TEXT_TERTIARY
        c.setLineDash([4, 4])
      } else {
        c.strokeStyle = Colors.LINE
        c.setLineDash([])
      }
      c.lineWidth = 1
      c.stroke()
      c.setLineDash([])
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
      const px = cx + rr * Math.cos(ang)
      const py = cy + rr * Math.sin(ang)
      if (this.missing[i]) {
        // 无数据：空心灰环，强调「这次没算它」而非「得分为 0」
        c.fillStyle = Colors.CARD
        c.strokeStyle = Colors.TEXT_TERTIARY
        c.lineWidth = 1.5
        c.beginPath()
        c.arc(px, py, 3.5, 0, Math.PI * 2)
        c.fill()
        c.stroke()
      } else {
        c.fillStyle = Colors.PRIMARY
        c.beginPath()
        c.arc(px, py, 3, 0, Math.PI * 2)
        c.fill()
      }
    }

    // 标签：名字与数值分两行，并按顶点在左右哪一侧决定对齐方式 ——
    // 一行写「抗干扰 100」在 280vp 宽的画布上会被裁掉
    c.fillStyle = Colors.TEXT_SECONDARY
    c.font = this.fontOf(11)
    for (let i = 0; i < n; i++) {
      const ang = this.angle(i, n)
      const cosv = Math.cos(ang)
      const lx = cx + (r + 8) * cosv
      const ly = cy + (r + 8) * Math.sin(ang)
      c.textAlign = cosv > 0.2 ? 'left' : (cosv < -0.2 ? 'right' : 'center')
      c.fillStyle = this.missing[i] ? Colors.TEXT_TERTIARY : Colors.TEXT_SECONDARY
      c.fillText(this.labels[i], lx, ly)
      c.fillText(this.missing[i] ? '—' : `${Math.round(this.values[i])}`, lx, ly + 14)
    }
  }
}
