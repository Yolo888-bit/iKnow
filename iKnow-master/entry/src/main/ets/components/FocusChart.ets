import { Colors } from '../common/Theme'
import { FocusStateUi } from '../common/FocusStateUi'

/** 一个「状态段」：从 fromSec 到 toSec 一直是同一个状态 */
interface StateRun {
  fromSec: number
  toSec: number
  state: string
}

/**
 * 专注状态时间轴（色带图，Canvas 绘制）
 *
 * 为什么不是"曲线"：底层数据是**离散的分段状态**（专注 / 轻度分心 / 分心），
 * 画成连续折线本身就是伪连续 —— 整场只有一种状态时，折线必然退化成一条水平直线，
 * 用户看到的就是"纵坐标怎么是一条线"。改成按段涂色的时间轴之后：
 *  - 一眼看出「什么时候是什么状态」「切换了几次」；
 *  - 只有一段时就是一条纯色带，语义正确，不会看起来像坏图；
 *  - 横轴标出分钟刻度。
 *
 * ## 横轴口径（这一版修的就是它）
 * 横轴 = **已判定的学习秒数**（净专注 + 分心，不含答疑 / 休息 / 暂停）。
 * 之前按 `minute`（取整）定位，而采样间隔 30 s 会让同一分钟落两个点：
 *  - 同分钟的两点 x 相同 → 段宽 0 → 被 `Math.max(1, …)` 强行撑成 1 px，
 *    颜色还取自"这一分钟里第一个采样点"，于是色带里专注/分心的宽度
 *    和复盘里显示的时长对不上；
 *  - 最后一个采样点之后直接收尾，最后一段状态在图上没有宽度。
 * 现在：按秒定位 + **把连续同状态的采样点合并成段** + 最后一段延伸到 `endSec`，
 * 色带里各状态的宽度就与「专注 / 分心时长」严格成比例。
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
  /** 与 levels 一一对应的「累计已判定学习秒数」（优先用它定位） */
  @Prop seconds: number[] = []
  /** 与 levels 一一对应的「会话内相对分钟」（seconds 缺失时按 minute × 60 兜底） */
  @Prop minutes: number[] = []
  /** 横轴终点（秒）。传会话/当天的 judgedSec，保证最后一段状态也被画出来 */
  @Prop endSec: number = 0
  /** 多次会话拼接时的分界点（**秒**，与 seconds 同一坐标系） */
  @Prop separatorsSec: number[] = []
  /** 旧口径的分界点（分钟）；仅在 separatorsSec 为空时兜底使用 */
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

  private stateAt(i: number): string {
    return i < this.states.length ? this.states[i] : 'FOCUSED'
  }

  /** 第 i 个采样点的时间位置（秒）：优先 seconds，其次 minutes × 60，最后按索引等距 */
  private secOf(i: number): number {
    const n = this.levels.length
    if (this.seconds.length === n && n > 0) {
      return this.seconds[i]
    }
    if (this.minutes.length === n && n > 0) {
      return this.minutes[i] * 60
    }
    return i * 60
  }

  /** 横轴范围（秒）：起点取第一个采样点，终点优先用调用方给的 endSec */
  private secRange(): number[] {
    const n = this.levels.length
    if (n === 0) {
      return [0, 60]
    }
    const start = this.secOf(0)
    let end = this.secOf(n - 1)
    if (this.endSec > end) {
      end = this.endSec
    }
    // 只有单个采样点、或时间没有推进时，给一个最小跨度，避免整条带被画成 0 宽
    if (end - start < 1) {
      end = start + 60
    }
    return [start, end]
  }

  /**
   * 把连续同状态的采样点合并成「状态段」。
   * 不合并的话，一个持续 30 分钟的专注会因为每 30 秒一个采样点被切成 60 个碎片，
   * 既没必要，也让"段宽 = 时长"这个关系容易被 1 px 下限破坏。
   */
  private buildRuns(): StateRun[] {
    const n = this.levels.length
    const out: StateRun[] = []
    if (n === 0) {
      return out
    }
    const end = this.secRange()[1]
    let runStart = this.secOf(0)
    let runState = this.stateAt(0)
    for (let i = 1; i < n; i++) {
      const s = this.stateAt(i)
      if (s !== runState) {
        const cut = this.secOf(i)
        if (cut > runStart) {
          out.push({ fromSec: runStart, toSec: cut, state: runState })
        }
        runStart = cut
        runState = s
      }
    }
    // 最后一段延伸到横轴终点：否则最后一个状态在图上没有宽度
    if (end > runStart) {
      out.push({ fromSec: runStart, toSec: end, state: runState })
    }
    return out
  }

  /** 分界点（秒）：优先新口径，其次把旧的分钟值 × 60 */
  private separatorSecs(): number[] {
    if (this.separatorsSec.length > 0) {
      return this.separatorsSec
    }
    const out: number[] = []
    for (const m of this.separators) {
      out.push(m * 60)
    }
    return out
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

    // ---- 图例：颜色到底代表什么 ----
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

    const range = this.secRange()
    const span = range[1] - range[0]
    const usable = w - pad * 2
    const xOf = (sec: number): number => pad + usable * (sec - range[0]) / span

    // ---- 色带：按「状态段」涂色，宽度与真实时长严格成比例 ----
    const runs = this.buildRuns()
    for (const r of runs) {
      const x1 = xOf(r.fromSec)
      const x2 = xOf(r.toSec)
      const rw = x2 - x1
      if (rw <= 0) {
        continue
      }
      c.fillStyle = FocusStateUi.color(r.state)
      c.fillRect(x1, bandTop, rw, bandH)
    }
    c.strokeStyle = Colors.LINE
    c.lineWidth = 1
    c.strokeRect(pad, bandTop, usable, bandH)

    // ---- 多次专注的分界：白色竖线压在色带之上 ----
    const seps = this.separatorSecs()
    if (seps.length > 0) {
      c.strokeStyle = '#FFFFFF'
      c.lineWidth = 2
      for (const sep of seps) {
        const x = xOf(sep)
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
      const x = pad + usable * k / ticks
      c.strokeStyle = Colors.LINE
      c.lineWidth = 1
      c.beginPath()
      c.moveTo(x, bandBottom)
      c.lineTo(x, bandBottom + 5)
      c.stroke()
      // 刻度值以分钟显示（横轴内部按秒算）
      const mv = (range[0] + span * k / ticks) / 60
      c.fillStyle = Colors.TEXT_TERTIARY
      c.textAlign = k === 0 ? 'left' : (k === ticks ? 'right' : 'center')
      c.fillText(`${Math.round(mv)}`, x, bandBottom + 20)
    }
  }
}
