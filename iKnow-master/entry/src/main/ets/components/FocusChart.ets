import { Colors } from '../common/Theme'

/**
 * 一个「状态段」：从 `fromMs` 到 `toMs` 一直是 `state`（**绝对时间**，毫秒）。
 *
 * 用绝对时间而不是"会话内第几秒"：复盘的横轴是**真实钟点**
 * （"14:05 → 14:12 一直是专注"），而会话内秒数在休息 / 暂停期间不前进，
 * 排不出真实时间轴。由调用方（单次复盘页）按 `session.startTime` 与
 * 状态时间线（`timeline` 的 `atMs`）组装好再传进来。
 */
@Observed
export class StateRun {
  fromMs: number = 0
  toMs: number = 0
  state: string = ''
}

/**
 * 专注状态时间轴 + 心率曲线区（Canvas 绘制）
 *
 * ## 横轴 = 真实时间
 * 按**时刻**定位（刻度直接标 `14:05`），一段状态就是一条色带，
 * 于是"某时刻到某时刻是什么状态"可以直接读出来。
 *
 * ## 颜色只有四档，含义唯一
 *  - 绿 = 专注
 *  - 红 = **分心（含轻度分心）** —— 轻度走神在这张图上不再单独配色，
 *    黄色的槽位让给了「休息」（用户明确要求：休息=黄、专注=绿、分心=红）；
 *  - 黄 = 休息
 *  - 灰绿 = 暂停 / 答疑（中性态：既不是专注也不是分心，不参与专注率计算）
 *
 * ## 纵轴 = 心率（目前是占位）
 * 设计上纵轴是心率曲线（bpm）。当前版本**没有把心率按时间采集成会话数据**
 * （`SensorService` 只做实时展示，会话里没有留痕），所以这里画一条虚线占位，
 * 并在图内写明"暂无数据"。等会话开始记录心率采样点后，只需调用方把
 * `hrPoints` 传进来即可变成真实曲线，组件本身不用再改。
 *
 * 诚实性约定：**图上看不出真实数据的地方必须写清楚** —— 占位线要标"占位"，
 * 旧记录排不出真实时间轴时由调用方在图注里说明。
 */
@Component
export struct FocusChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  /** 状态段（按绝对时间排好序、已合并连续同状态） */
  @Prop @Watch('redraw') runs: StateRun[] = []
  /** 横轴起点（毫秒）：一般传 session.startTime */
  @Prop @Watch('redraw') startMs: number = 0
  /** 横轴终点（毫秒）：一般传 session.endTime，保证最后一段状态也有宽度 */
  @Prop @Watch('redraw') endMs: number = 0
  /**
   * 心率采样点（bpm）。**当前一律传空数组** —— 会话里还没有心率留痕。
   * 传空时画占位虚线并注明"暂无数据"；将来有数据了直接传值即可。
   */
  @Prop @Watch('redraw') hrPoints: number[] = []
  private chartH: number = 200
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

  /** 状态 → 色带颜色（含义见文件头，四档） */
  private colorOf(state: string): string {
    if (state === 'RESTING') {
      return Colors.YELLOW
    }
    if (state === 'PAUSED' || state === 'QA_MODE') {
      // 中性灰绿：暂停 / 答疑既不是专注也不是分心
      return Colors.TEXT_TERTIARY
    }
    if (state === 'SLIGHTLY_DISTRACTED' || state === 'DISTRACTED') {
      return Colors.RED
    }
    return Colors.GREEN
  }

  /** 毫秒 → "14:05"（横轴刻度用的真实钟点） */
  private clockOf(ms: number): string {
    const d = new Date(ms)
    const m = d.getMinutes()
    const mm = m < 10 ? `0${m}` : `${m}`
    return `${d.getHours()}:${mm}`
  }

  /** 横轴范围（毫秒）：以调用方给的 start/end 为准，异常时退回首个状态段 */
  private msRange(): number[] {
    let start = this.startMs
    let end = this.endMs
    if (start <= 0 && this.runs.length > 0) {
      start = this.runs[0].fromMs
    }
    if (end <= start && this.runs.length > 0) {
      end = this.runs[this.runs.length - 1].toMs
    }
    if (end <= start) {
      end = start + 60 * 1000
    }
    return [start, end]
  }

  private draw(): void {
    const c = this.ctx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)
    if (this.runs.length === 0) {
      c.fillStyle = Colors.TEXT_TERTIARY
      c.font = this.fontOf(12)
      c.textAlign = 'center'
      c.fillText('本次没有状态记录', w / 2, h / 2)
      return
    }

    const padLeft = 40
    const padRight = 12
    const usable = w - padLeft - padRight
    const range = this.msRange()
    const span = range[1] - range[0]
    const xOf = (ms: number): number => padLeft + usable * (ms - range[0]) / span

    // ---------- 图例 ----------
    const names: string[] = ['专注', '分心', '休息', '暂停 · 答疑']
    const keys: string[] = ['FOCUSED', 'DISTRACTED', 'RESTING', 'PAUSED']
    c.font = this.fontOf(10)
    c.textAlign = 'left'
    let lx = padLeft - 26
    for (let i = 0; i < keys.length; i++) {
      c.fillStyle = this.colorOf(keys[i])
      c.fillRect(lx, 5, 10, 10)
      c.fillStyle = Colors.TEXT_SECONDARY
      c.fillText(names[i], lx + 14, 14)
      lx += 14 + names[i].length * 10 + 10
    }

    // ---------- 纵轴区：心率曲线（当前为占位） ----------
    const hrTop = 28
    const hrBottom = 118
    // 区域边框：让"这里是曲线绘制区"一眼可见
    c.strokeStyle = Colors.LINE
    c.lineWidth = 1
    c.strokeRect(padLeft, hrTop, usable, hrBottom - hrTop)
    c.fillStyle = Colors.TEXT_TERTIARY
    c.font = this.fontOf(10)
    c.textAlign = 'right'
    c.fillText('bpm', padLeft - 4, hrTop + 8)

    const hrMid = (hrTop + hrBottom) / 2
    if (this.hrPoints.length === 0) {
      // 占位：一条虚线 + 明确说明。**不能**画成看似有数据的曲线
      c.setLineDash([6, 5])
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1.5
      c.beginPath()
      c.moveTo(padLeft, hrMid)
      c.lineTo(w - padRight, hrMid)
      c.stroke()
      c.setLineDash([])
      c.fillStyle = Colors.TEXT_TERTIARY
      c.font = this.fontOf(11)
      c.textAlign = 'center'
      c.fillText('心率曲线（占位）：本次未接入心率设备，暂无数据', padLeft + usable / 2, hrMid + 18)
    } else {
      // 有数据时按 60~160 bpm 归一：低于 60 贴底、高于 160 贴顶，不改变"高低关系"
      const lo = 60
      const hi = 160
      c.strokeStyle = Colors.RED
      c.lineWidth = 2
      c.beginPath()
      for (let i = 0; i < this.hrPoints.length; i++) {
        let v = this.hrPoints[i]
        if (v < lo) {
          v = lo
        }
        if (v > hi) {
          v = hi
        }
        const x = padLeft + usable * (this.hrPoints.length > 1 ? i / (this.hrPoints.length - 1) : 0.5)
        const y = hrBottom - (v - lo) / (hi - lo) * (hrBottom - hrTop)
        if (i === 0) {
          c.moveTo(x, y)
        } else {
          c.lineTo(x, y)
        }
      }
      c.stroke()
    }

    // ---------- 状态色带（按真实时间填色，宽度与真实时长严格成比例） ----------
    const bandTop = 132
    const bandBottom = 172
    for (const r of this.runs) {
      const x1 = xOf(r.fromMs)
      const x2 = xOf(r.toMs)
      const rw = x2 - x1
      if (rw <= 0) {
        continue
      }
      c.fillStyle = this.colorOf(r.state)
      c.fillRect(x1, bandTop, rw, bandBottom - bandTop)
    }
    c.strokeStyle = Colors.LINE
    c.lineWidth = 1
    c.strokeRect(padLeft, bandTop, usable, bandBottom - bandTop)

    // ---------- 横轴：真实钟点刻度（5 档） ----------
    const ticks = 4
    c.font = this.fontOf(10)
    for (let k = 0; k <= ticks; k++) {
      const x = padLeft + usable * k / ticks
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1
      c.beginPath()
      c.moveTo(x, bandBottom)
      c.lineTo(x, bandBottom + 4)
      c.stroke()
      c.fillStyle = Colors.TEXT_TERTIARY
      // 首尾贴边对齐，避免文字被裁掉
      c.textAlign = k === 0 ? 'left' : (k === ticks ? 'right' : 'center')
      c.fillText(this.clockOf(range[0] + span * k / ticks), x, bandBottom + 17)
    }
  }
}
