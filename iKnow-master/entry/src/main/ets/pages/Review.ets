import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { Metrics, Last30DaysSummary, PracticeSummaryItem, HabitInsight, DaySummary } from '../services/Metrics'
import { AIService } from '../services/AIService'
import { FocusProfile } from '../models/FocusProfile'
import { RadarChart } from '../components/RadarChart'
import { FocusChart } from '../components/FocusChart'
import { CircularProgress } from '../components/CircularProgress'
import { FocusSession } from '../models/FocusSession'
import { Task } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { DateChip } from '../components/DateChip'
import { StorageService } from '../services/StorageService'
import { StudyPlan } from '../models/StudyPlan'
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 长期学习总结 / 单日学习复盘 —— 单屏区块式复盘页
 *
 *  - 右上角日历：点击弹出日期选择，切换到「某天学习总结」（图3样式）；再点 ✕ 返回长期总结。
 *  - 近30天表现曲线改为平滑曲线（二次贝塞尔过中点），不再是一折一折的折线。
 *  - 指标全部走 Metrics（§3），AI 文案全部走 AIService（§1）。
 */
@Entry
@Component
export struct Review {
  // ---------- 长期总结状态 ----------
  @State summary: Last30DaysSummary = { totalHours: 0, completedTasks: 0, focusRate: 0, trend: [] }
  @State practice: PracticeSummaryItem[] = []
  @State habit: HabitInsight = { bestWindow: '', bestRate: 0, lowWindow: '', lowNote: '', advice: '' }
  @State aiAdvice: string = ''
  /** 长期计划（study_plan 表，此前零调用；长期视图里设置） */
  @State longPlan: StudyPlan | null = null
  @State profile: FocusProfile = new FocusProfile()
  @State dimValues: number[] = []
  @State canShowRadar: boolean = false

  // ---------- 单日复盘状态 ----------
  /** 0 = 长期学习总结；1 = 某天学习总结 */
  @State mode: number = 0
  @State dayStart: number = 0
  @State day: DaySummary = {
    hasData: false,
    studyMinutes: 0,
    focusRate: 0,
    completedTasks: 0,
    totalTasks: 0,
    qaSessions: 0,
    sessionCount: 0,
    bestPeriod: '',
    levels: [],
    states: [],
    minutes: [],
    separators: []
  }
  @State dayInsight: string = ''
  @State daySuggestions: string[] = []

  // 右上角下拉面板：切换「长期复盘 / 按天复盘」，按天时内嵌月历
  @State showPicker: boolean = false
  /** 下拉面板里是否已展开「按天复盘」的月历 */
  @State pickDayMode: boolean = false
  @State calYear: number = 2026
  @State calMonth: number = 8
  private todayY: number = 2026
  private todayM: number = 8
  private todayD: number = 1
  private selY: number = 2026
  private selM: number = 8
  private selD: number = 1

  // 曲线交互：当前选中的数据点（-1 表示未选中，则不画任何点）
  @State activeIndex: number = -1
  @State bubbleX: number = 0
  @State bubbleY: number = 0
  private geoL: number = 0
  private geoStep: number = 0
  private geoT: number = 0
  private geoChartH: number = 0
  private geoMaxV: number = 1
  private geoN: number = 0
  private geoW: number = 0

  private dimLabels: string[] = ['效率', '专注度', '稳定性', '执行力', '抗干扰']
  private chartSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private lineCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.chartSettings)
  /** 会话结束后 DATA_VERSION 会自增：据此重取数据，避免复盘 Tab 一直显示旧值 */
  @StorageProp(StorageKey.DATA_VERSION) @Watch('reload') dataVersion: number = 0

  /** 数据版本变化即刷新（按当前视图模式重取） */
  private reload(): void {
    this.loadAll()
  }

  aboutToAppear(): void {
    // 默认选中「今天」+ 初始化日历弹层：只在首次进入时定位，
    // 避免数据刷新（reload）把用户选中的日期重置回今天
    const now = Date.now()
    this.dayStart = TimeUtils.dayStart(now)
    const sd = new Date(this.dayStart)
    this.selY = sd.getFullYear()
    this.selM = sd.getMonth()
    this.selD = sd.getDate()
    this.calYear = this.selY
    this.calMonth = this.selM
    const tnow = new Date(now)
    this.todayY = tnow.getFullYear()
    this.todayM = tnow.getMonth()
    this.todayD = tnow.getDate()
    this.loadAll()
  }

  private loadAll(): void {
    const store = AppStore.getInstance()
    const sessions: FocusSession[] = store.getSessions()
    const tasks: Task[] = store.getTasks()
    const now = Date.now()

    this.summary = Metrics.last30DaysSummary(sessions, tasks, now)
    this.practice = Metrics.practiceSummary(sessions, tasks)
    this.habit = Metrics.habitInsights(sessions)
    // 排查用：把库里实际加载到的会话数打到日志，便于判断"历史是否真的落库"
    hilog.info(0x0000, 'iKnow.Review', '复盘数据：会话 %{public}d 条，任务 %{public}d 条',
      sessions.length, tasks.length)

    this.profile = store.getProfile()
    this.dimValues = [
      this.profile.efficiency,
      this.profile.concentration,
      this.profile.stability,
      this.profile.execution,
      this.profile.antiDistraction
    ]
    this.canShowRadar = Metrics.canShowProfile(this.profile.sampleCount)

    const hardest = this.hardestSubject()
    this.aiAdvice = AIService.getInstance().longTermAnalysis(this.profile, hardest)

    // 长期计划（设置页改完回来要刷新）
    StorageService.getInstance().loadStudyPlan().then((p: StudyPlan | null) => {
      this.longPlan = p
    }).catch(() => {
      this.longPlan = null
    })

    // 按天视图下同步刷新当天数据，否则结束后仍显示旧值
    if (this.mode === 1) {
      this.loadDay()
    }
  }

  /** 目标一行：考试 + 倒计时 + 科目（与长期计划合并后一起展示，空则如实说明） */
  private goalLine(): string {
    const g = AppStore.getInstance().getGoal()
    if (g.examType.length === 0 && g.subjects.length === 0) {
      return '还没设置目标考试与科目，在「长期计划与目标」里填写后，倒计时与规划会更准。'
    }
    const parts: string[] = []
    if (g.examType.length > 0) {
      const days = g.targetDate > 0 ? `，距考试 ${TimeUtils.daysUntil(g.targetDate, Date.now())} 天` : '（未填考试日期）'
      parts.push(`目标：${g.examType}${days}`)
    }
    if (g.subjects.length > 0) {
      parts.push(`科目：${g.subjects.join('、')}`)
    }
    return parts.join(' · ')
  }

  /**
   * 长期视图的样本量说明。
   * 既解决"长期看起来只有今天"的理解问题，也是**排查历史是否真的落库**的证据：
   * 如果这里只显示 1 次，说明库里就只有 1 条（写入侧或数据被清），而不是显示逻辑的问题。
   */
  private sampleLine(): string {
    const list = AppStore.getInstance().getSessions()
    if (list.length === 0) {
      return '范围：近 30 天 · 库里暂无专注记录'
    }
    const days: number[] = []
    let earliest = list[0].startTime
    let earliestDuration = list[0].totalDuration
    for (const s of list) {
      const d = TimeUtils.dayStart(s.startTime)
      if (days.indexOf(d) < 0) {
        days.push(d)
      }
      if (s.startTime < earliest) {
        earliest = s.startTime
        earliestDuration = s.totalDuration
      }
    }
    const e = new Date(earliest)
    return `范围：近 30 天 · 库里共 ${list.length} 次专注 · 覆盖 ${days.length} 天 · 最早一次 ${e.getMonth() + 1}月${e.getDate()}日（${Math.round(earliestDuration / 60)} 分钟）`
  }

  private hardestSubject(): string {
    const subs = AppStore.getInstance().getDashboard().subjectProgress
    if (subs.length === 0) {
      return '数学类任务'
    }
    let hardest = subs[0]
    for (const s of subs) {
      if (s.percent < hardest.percent) {
        hardest = s
      }
    }
    return `${hardest.subject}类任务`
  }

  // ===================== 单日复盘 =====================

  /** 右上角日期 chip：下拉出「长期复盘 / 按天复盘」切换面板 */
  private pickDay(): void {
    this.showPicker = !this.showPicker
  }

  // ===================== 日历弹层（月历） =====================

  /** 当月网格：前导空格用 0 占位，之后是 1..daysInMonth */
  private calCells(): number[] {
    const first = new Date(this.calYear, this.calMonth, 1).getDay()
    const days = new Date(this.calYear, this.calMonth + 1, 0).getDate()
    const cells: number[] = []
    for (let i = 0; i < first; i++) {
      cells.push(0)
    }
    for (let d = 1; d <= days; d++) {
      cells.push(d)
    }
    return cells
  }

  private isFuture(y: number, m: number, d: number): boolean {
    const today = new Date(this.todayY, this.todayM, this.todayD)
    const sel = new Date(y, m, d)
    return sel.getTime() > today.getTime()
  }

  private isSameDay(y: number, m: number, d: number, sy: number, sm: number, sd: number): boolean {
    return y === sy && m === sm && d === sd
  }

  private shiftMonth(delta: number): void {
    let m = this.calMonth + delta
    let y = this.calYear
    if (m < 0) {
      m = 11
      y -= 1
    }
    if (m > 11) {
      m = 0
      y += 1
    }
    this.calYear = y
    this.calMonth = m
  }

  private confirmDay(day: number): void {
    const ts = new Date(this.calYear, this.calMonth, day).getTime()
    this.dayStart = TimeUtils.dayStart(ts)
    this.selY = this.calYear
    this.selM = this.calMonth
    this.selD = day
    this.loadDay()
    this.mode = 1
    this.showPicker = false
  }

  @Builder
  calDayCell(day: number) {
    Column() {
      Text(`${day}`)
        .fontSize(14)
        .fontColor(this.isFuture(this.calYear, this.calMonth, day) ? Colors.TEXT_TERTIARY : Colors.TEXT_PRIMARY)
        .fontWeight(this.isSameDay(this.calYear, this.calMonth, day, this.selY, this.selM, this.selD)
          ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height(34)
    .borderRadius(17)
    .backgroundColor(
      this.isSameDay(this.calYear, this.calMonth, day, this.selY, this.selM, this.selD)
        ? Colors.PRIMARY_SOFT
        : (this.isSameDay(this.calYear, this.calMonth, day, this.todayY, this.todayM, this.todayD)
          ? Colors.GREEN_SOFT : Color.Transparent)
    )
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.isFuture(this.calYear, this.calMonth, day)) {
        return
      }
      this.confirmDay(day)
    })
  }

  /** 下拉面板里的一个模式选项 */
  @Builder
  modeOption(icon: string, title: string, desc: string, m: number) {
    Row({ space: 10 }) {
      Text(icon).fontSize(18)
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(desc)
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.mode === m) {
        Text('✓')
          .fontSize(16)
          .fontColor(Colors.PRIMARY_DARK)
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(Radius.MD)
    .backgroundColor(this.mode === m ? Colors.PRIMARY_SOFT : Color.Transparent)
    .onClick(() => {
      if (m === 0) {
        // 切回长期复盘并收起面板
        this.mode = 0
        this.pickDayMode = false
        this.showPicker = false
        this.onLineChartReady()
      } else {
        // 展开月历，由用户挑具体某天
        this.pickDayMode = true
      }
    })
  }

  /** 右上角下拉面板：长期复盘 / 按天复盘（按天时在面板里内嵌月历） */
  @Builder
  pickerPanel() {
    Column({ space: Spacing.SM }) {
      this.modeOption('📈', '长期复盘', '近 30 天整体表现', 0)
      this.modeOption('📅', '按天复盘', '查看某一天的专注记录', 1)

      if (this.pickDayMode) {
        Divider()
          .color(Colors.LINE)
          .margin({ top: 4, bottom: 8 })

        // 年月 + 上/下月切换
        Row() {
          Text('‹')
            .fontSize(22)
            .fontColor(Colors.TEXT_PRIMARY)
            .padding({ left: 6, right: 6 })
            .onClick(() => {
              this.shiftMonth(-1)
            })
          Blank()
          Text(`${this.calYear}年${this.calMonth + 1}月`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
          Blank()
          Text('›')
            .fontSize(22)
            .fontColor(Colors.TEXT_PRIMARY)
            .padding({ left: 6, right: 6 })
            .onClick(() => {
              this.shiftMonth(1)
            })
        }
        .width('100%')

        // 星期表头
        Row() {
          ForEach(['日', '一', '二', '三', '四', '五', '六'], (w: string) => {
            Text(w)
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
          }, (w: string) => w)
        }
        .width('100%')

        // 日期网格
        Grid() {
          ForEach(this.calCells(), (cell: number, idx: number) => {
            GridItem() {
              if (cell > 0) {
                this.calDayCell(cell)
              } else {
                Text('').width('100%').height(34)
              }
            }
          }, (cell: number, idx: number) => `${idx}_${cell}`)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsGap(2)
        .columnsGap(2)
        .height(210)
        .width('100%')
      }
    }
    .width(300)
    .padding(12)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .shadow({ radius: 24, color: Colors.SHADOW_LAYER, offsetX: 0, offsetY: 8 })
  }

  private backToLong(): void {
    this.mode = 0
    this.onLineChartReady()
  }

  private dayLabel(): string {
    const d = new Date(this.dayStart)
    return `${d.getMonth() + 1}月${d.getDate()}日`
  }

  private loadDay(): void {
    const sessions: FocusSession[] = AppStore.getInstance().getSessions()
    this.day = Metrics.daySummary(sessions, this.dayStart)
    this.dayInsight = AIService.getInstance().dayInsight(
      this.dayLabel(), this.day.focusRate, this.day.bestPeriod, this.day.hasData)
    // 最多 3 条：建议太多反而把页面挤满
    this.daySuggestions = AIService.getInstance()
      .daySuggestions(this.day.studyMinutes, this.day.focusRate)
      .slice(0, 3)
  }

  private dayStatusText(): string {
    if (!this.day.hasData) {
      return '这一天还没有学习记录'
    }
    if (this.day.focusRate >= 80) {
      return '状态不错，继续保持'
    }
    if (this.day.focusRate >= 60) {
      return '状态稳定，继续保持'
    }
    return '有提升空间，再接再厉'
  }

  private dayStatusTag(): string {
    if (this.day.focusRate >= 80) {
      return '专注度 高'
    }
    if (this.day.focusRate >= 60) {
      return '专注度 中'
    }
    return '专注度 低'
  }

  // ===================== 长期曲线（平滑） =====================

  /** 用「二次贝塞尔过中点」把折线变成平滑曲线（调用前需先把当前点移到首点） */
  private curveThrough(c: CanvasRenderingContext2D, pts: number[][]): void {
    const n = pts.length
    if (n < 2) {
      return
    }
    for (let i = 1; i < n - 1; i++) {
      const midX = (pts[i][0] + pts[i + 1][0]) / 2
      const midY = (pts[i][1] + pts[i + 1][1]) / 2
      c.quadraticCurveTo(pts[i][0], pts[i][1], midX, midY)
    }
    c.quadraticCurveTo(pts[n - 1][0], pts[n - 1][1], pts[n - 1][0], pts[n - 1][1])
  }

  private onLineChartReady(): void {
    const c = this.lineCtx
    const w = c.width
    const h = c.height
    c.clearRect(0, 0, w, h)

    const values = this.summary.trend
    if (values.length === 0) {
      return
    }

    const padLeft = 8
    const padRight = 8
    const padTop = 16
    const padBottom = 24
    const chartW = w - padLeft - padRight
    const chartH = h - padTop - padBottom
    const baseY = padTop + chartH

    let maxV = 1
    for (const v of values) {
      if (v > maxV) {
        maxV = v
      }
    }
    const n = values.length
    const stepX = n > 1 ? chartW / (n - 1) : chartW

    const points: number[][] = []
    for (let i = 0; i < n; i++) {
      const x = padLeft + i * stepX
      const y = padTop + chartH - (values[i] / maxV) * chartH
      points.push([x, y])
    }

    // 缓存几何参数，供触摸时「按 x 定位最近数据点」
    this.geoL = padLeft
    this.geoStep = stepX
    this.geoT = padTop
    this.geoChartH = chartH
    this.geoMaxV = maxV
    this.geoN = n
    this.geoW = w

    // 渐变填充区域（平滑上边）
    c.beginPath()
    c.moveTo(points[0][0], baseY)
    c.lineTo(points[0][0], points[0][1])
    this.curveThrough(c, points)
    c.lineTo(points[n - 1][0], baseY)
    c.closePath()
    const grad = c.createLinearGradient(0, padTop, 0, baseY)
    grad.addColorStop(0, 'rgba(29,199,138,0.32)')
    grad.addColorStop(1, 'rgba(29,199,138,0.02)')
    c.fillStyle = grad
    c.fill()

    // 平滑曲线
    c.beginPath()
    c.moveTo(points[0][0], points[0][1])
    this.curveThrough(c, points)
    c.strokeStyle = Colors.PRIMARY
    c.lineWidth = 3
    c.lineJoin = 'round'
    c.lineCap = 'round'
    c.stroke()

    // 默认不画任何数据点；只有用户点按 / 拖拽曲线时才高亮当前点
    if (this.activeIndex >= 0 && this.activeIndex < n) {
      const i = this.activeIndex
      const px = points[i][0]
      const py = points[i][1]

      // 垂直参考线
      c.beginPath()
      c.moveTo(px, padTop)
      c.lineTo(px, baseY)
      c.strokeStyle = 'rgba(29,199,138,0.5)'
      c.lineWidth = 1
      c.stroke()

      // 高亮点
      c.beginPath()
      c.arc(px, py, 5, 0, Math.PI * 2)
      c.fillStyle = '#FFFFFF'
      c.fill()
      c.lineWidth = 3
      c.strokeStyle = Colors.PRIMARY
      c.stroke()
    }

    // 首尾标签
    c.fillStyle = Colors.TEXT_SECONDARY
    c.font = '10px sans-serif'
    c.textAlign = 'left'
    c.fillText('30天前', padLeft, h - 6)
    c.textAlign = 'right'
    c.fillText('今天', w - padRight, h - 6)
  }

  /** 曲线触摸：按 x 定位最近的数据点（点按显示点、左右拖拽数值实时变化） */
  private onChartTouch(event: TouchEvent): void {
    if (this.geoN === 0 || event.touches.length === 0) {
      return
    }
    const type = event.type
    if (type === TouchType.Up || type === TouchType.Cancel) {
      // 松手后保留当前点，方便读数
      return
    }
    const x = event.touches[0].x
    let idx = 0
    if (this.geoStep > 0) {
      idx = Math.round((x - this.geoL) / this.geoStep)
    }
    if (idx < 0) {
      idx = 0
    }
    if (idx > this.geoN - 1) {
      idx = this.geoN - 1
    }
    if (idx !== this.activeIndex) {
      this.activeIndex = idx
      this.updateBubblePos()
      this.onLineChartReady()
    }
  }

  /** 数值气泡位置（跟随选中点，贴边自动收敛） */
  private updateBubblePos(): void {
    const values = this.summary.trend
    const i = this.activeIndex
    if (i < 0 || i >= values.length || this.geoMaxV <= 0) {
      return
    }
    const px = this.geoL + i * this.geoStep
    const py = this.geoT + this.geoChartH - (values[i] / this.geoMaxV) * this.geoChartH
    let bx = px - 52
    if (bx < 0) {
      bx = 0
    }
    const maxBx = this.geoW - 104
    if (bx > maxBx) {
      bx = maxBx > 0 ? maxBx : 0
    }
    let by = py - 58
    if (by < 0) {
      by = 0
    }
    this.bubbleX = bx
    this.bubbleY = by
  }

  /** 选中点对应的日期（trend[0] = 29 天前，最后一格 = 今天） */
  private activeDateLabel(): string {
    const dayMs = 24 * 3600 * 1000
    const ds = TimeUtils.dayStart(Date.now()) - (29 - this.activeIndex) * dayMs
    const d = new Date(ds)
    return `${d.getMonth() + 1}月${d.getDate()}日`
  }

  private activeMinutes(): number {
    const values = this.summary.trend
    if (this.activeIndex < 0 || this.activeIndex >= values.length) {
      return 0
    }
    return values[this.activeIndex]
  }

  /** 顶部日历图标里的日期数字：长期=今天，按天=所选日 */
  private chipDay(): number {
    return this.mode === 0 ? this.todayD : this.selD
  }

  /** 顶部 chip 文案：长期模式显示「长期复盘」，只有选中单日才显示具体日期 */
  private chipLabel(): string {
    if (this.mode === 0) {
      return '长期复盘'
    }
    return this.dayLabel()
  }

  // ===================== View builders =====================

  @Builder
  statCard(label: string, value: string, unit: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(Colors.TEXT_SECONDARY)
      Row() {
        Text(value)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(unit)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ left: 4, bottom: 4 })
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  metricTile(label: string, value: string, unit: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(Colors.TEXT_SECONDARY)
      Row() {
        Text(value)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        if (unit.length > 0) {
          Text(unit)
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ left: 3, bottom: 3 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 6 })
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  sectionHeader(icon: string, title: string) {
    Row() {
      Text(icon)
        .fontSize(18)
        .margin({ right: 6 })
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
      Blank()
    }
    .width('100%')
  }

  /** 单日学习总结视图 */
  /** 曲线图例与口径说明（画布内不放文字，避免与曲线重叠） */
  @Builder
  curveLegend() {
    Column() {
      Row({ space: 14 }) {
        this.legendDot(Colors.GREEN, '专注')
        this.legendDot(Colors.YELLOW, '走神')
        this.legendDot(Colors.RED, '分心')
      }
      .width('100%')

      Text(this.curveCaption())
        .fontSize(11)
        .fontColor(Colors.TEXT_TERTIARY)
        .lineHeight(16)
        .width('100%')
        .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 4 })
  }

  @Builder
  legendDot(color: string, label: string) {
    Row() {
      Circle()
        .width(6)
        .height(6)
        .fill(color)
      Text(label)
        .fontSize(11)
        .fontColor(Colors.TEXT_SECONDARY)
        .margin({ left: 4 })
    }
  }

  /** 近 30 天趋势标题：由趋势数组前后半段均值对比得出，样本不足时如实说明 */
  private trendHeadline(): string {
    const t = this.summary.trend
    if (t.length < 4 || this.summary.totalHours <= 0) {
      return `近 30 天累计学习 ${this.summary.totalHours} 小时，数据还不足以判断趋势`
    }
    const half = Math.floor(t.length / 2)
    let a = 0
    let b = 0
    for (let i = 0; i < half; i++) {
      a += t[i]
    }
    for (let i = half; i < t.length; i++) {
      b += t[i]
    }
    const avgA = a / half
    const avgB = b / (t.length - half)
    if (avgA <= 0 && avgB <= 0) {
      return '近 30 天暂无每日净专注记录'
    }
    const pct = avgA > 0 ? Math.round((avgB - avgA) / avgA * 100) : 0
    if (pct >= 10) {
      return `后半段日均净专注比前半段高约 ${pct}%`
    }
    if (pct <= -10) {
      return `后半段日均净专注比前半段低约 ${Math.abs(pct)}%`
    }
    return `日均净专注基本持平（前后半段相差 ${Math.abs(pct)}% 以内）`
  }

  /** 曲线口径：明确纵轴是三档等级、横轴是当天累计分钟，多次专注用虚线分隔 */
  private curveCaption(): string {
    const n = this.day.minutes.length
    const span = n > 1 ? this.day.minutes[n - 1] - this.day.minutes[0] : 0
    const base = `纵轴：状态等级（绿 92 / 黄 62 / 红 30 三档，不是连续分数）· 横轴：当天累计学习 0–${span} 分钟`
    if (this.day.sessionCount > 1) {
      return `${base}；当天共 ${this.day.sessionCount} 次专注，虚线为两次之间的分界`
    }
    return base
  }

  @Builder
  dayView() {
    // 顶部状态卡
    Column({ space: Spacing.MD }) {
      // 范围标识：让用户一眼知道这一屏只讲"这一天"
      Text(`范围：${this.dayLabel()} 这一天`)
        .fontSize(11)
        .fontColor(Colors.TEXT_TERTIARY)
        .width('100%')
      Row() {
        Column() {
          Text(this.dayStatusText())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Text(`本次学习 ${this.day.studyMinutes} 分钟，任务完成 ${this.day.completedTasks}/${this.day.totalTasks}`)
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.dayStatusTag())
          .fontSize(11)
          .fontColor(Colors.GREEN)
          .padding({ top: 4, bottom: 4, left: 10, right: 10 })
          .backgroundColor(Colors.GREEN_SOFT)
          .borderRadius(10)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.day.hasData) {
        // 圆环与曲线各自独占一行：并排会把 360vp 屏上的图压到约 180vp，看着很挤
        Row() {
          CircularProgress({ percent: this.day.focusRate, boxSize: 88, label: '专注率' })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 4 })

        Column() {
          FocusChart({
            levels: this.day.levels,
            states: this.day.states,
            minutes: this.day.minutes,
            separators: this.day.separators
          })
            .width('100%')
            .height(140)
          this.curveLegend()
        }
        .width('100%')
        .margin({ top: 8 })
      } else {
        Column() {
          Text('🌱')
            .fontSize(30)
          Text('这一天还没有专注记录')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 6 })
        }
        .width('100%')
        .height(110)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    // 四项指标
    Row({ space: Spacing.MD }) {
      this.metricTile('学习时长', `${this.day.studyMinutes}`, '分钟')
      this.metricTile('任务完成率', `${this.day.completedTasks}/${this.day.totalTasks}`, '')
    }
    .width('100%')

    Row({ space: Spacing.MD }) {
      this.metricTile('净专注率', `${this.day.focusRate}`, '%')
      this.metricTile('答疑回顾', `${this.day.qaSessions}`, '次')
    }
    .width('100%')

    // 本次洞察
    Column({ space: Spacing.SM }) {
      this.sectionHeader('⭐', '本次洞察')
      Text(this.dayInsight.length > 0 ? this.dayInsight : '完成更多专注后，我会根据真实数据给出洞察。')
        .fontSize(14)
        .fontColor(Colors.TEXT_PRIMARY)
        .lineHeight(22)
        .margin({ top: 6 })
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    // 学习建议
    Column({ space: Spacing.SM }) {
      this.sectionHeader('💡', '学习建议')
      ForEach(this.daySuggestions, (s: string) => {
        Row() {
          Circle()
            .width(6)
            .height(6)
            .fill(Colors.GREEN)
            .margin({ top: 7 })
          Text(s)
            .fontSize(14)
            .fontColor(Colors.TEXT_PRIMARY)
            .margin({ left: 10 })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ top: 8 })
      }, (s: string) => s)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    Button('返回长期总结')
      .type(ButtonType.Capsule)
      .fontSize(16)
      .fontColor(Colors.TEXT_PRIMARY)
      .backgroundColor(Colors.GREEN_SOFT)
      .width('70%')
      .margin({ top: 8, bottom: 24 })
      .onClick(() => {
        this.backToLong()
      })
  }

  /** 长期学习总结视图 */
  @Builder
  longView() {
    // 近30天学习表现
    Column({ space: Spacing.SM }) {
      Text('近30天学习表现')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')
      Text(this.sampleLine())
        .fontSize(11)
        .fontColor(Colors.TEXT_TERTIARY)
        .lineHeight(16)
        .width('100%')
        .margin({ top: 4 })
      Text(this.trendHeadline())
        .fontSize(13)
        .fontColor(Colors.TEXT_SECONDARY)
        .width('100%')

      // 曲线默认无数据点；点按 / 左右拖拽时显示当前点的日期与数值
      Stack({ alignContent: Alignment.TopStart }) {
        Canvas(this.lineCtx)
          .width('100%')
          .height(150)
          .onReady(() => {
            this.onLineChartReady()
          })
          .onTouch((e: TouchEvent) => {
            this.onChartTouch(e)
          })

        if (this.activeIndex >= 0) {
          Column() {
            Text(this.activeDateLabel())
              .fontSize(10)
              .fontColor('#FFFFFF')
            Text(`${this.activeMinutes()} 分钟`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .margin({ top: 2 })
          }
          .width(104)
          .padding({ top: 6, bottom: 6 })
          .backgroundColor('#CC22302A')
          .borderRadius(10)
          .alignItems(HorizontalAlign.Center)
          .position({ x: this.bubbleX, y: this.bubbleY })
        }
      }
      .width('100%')
      .height(150)
      .margin({ top: 8, bottom: 8 })

      Row() {
        this.statCard('学习', `${this.summary.totalHours}`, '小时')
        this.statCard('完成', `${this.summary.completedTasks}`, '个任务')
        this.statCard('专注率', `${this.summary.focusRate}`, '%')
      }
      .width('100%')
      .padding({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    // 第二行：个人专注画像 + 练习内容总结
    Row({ space: Spacing.MD }) {
      Column({ space: Spacing.SM }) {
        Text('个人专注画像')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

        if (this.canShowRadar) {
          RadarChart({ values: this.dimValues, labels: this.dimLabels, chartSize: 150 })
            .margin({ top: 4 })
        } else {
          Column() {
            Text('🌱')
              .fontSize(32)
            Text('还在了解你')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 6 })
          }
          .width('100%')
          .height(150)
          .justifyContent(FlexAlign.Center)
        }
      }
      .layoutWeight(1)
      .padding(14)
      .backgroundColor(Colors.CARD)
      .borderRadius(Radius.LG)
      .alignItems(HorizontalAlign.Start)

      Column({ space: Spacing.SM }) {
        // 原先这里有一个「›」，暗示可点开详情页，但并没有这个页面 —— 去掉误导
        Text('练习内容总结')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
        // 窄卡片放不下全部练习内容，这里给一个明确的入口看完整列表
        Text('查看全部练习内容 ›')
          .fontSize(12)
          .fontColor(Colors.PRIMARY_DARK)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: 'pages/PracticeDetail' })
          })

        if (this.practice.length > 0) {
          ForEach(this.practice, (item: PracticeSummaryItem, index: number) => {
            Row() {
              Column() {
                Text(`${item.subject}：${item.content}`)
                  .fontSize(13)
                  .fontColor(Colors.TEXT_PRIMARY)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(`${item.count}次`)
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
          }, (item: PracticeSummaryItem, index: number) => `${item.subject}_${index}`)

          // 原先这里是「全科稳步提升 / 数学进步明显」两个写死的标签，与用户数据无关
          Row({ space: Spacing.SM }) {
            Text(`累计完成 ${this.summary.completedTasks} 个任务`)
              .fontSize(11)
              .fontColor(Colors.PRIMARY_DARK)
              .padding({ top: 4, bottom: 4, left: 8, right: 8 })
              .backgroundColor(Colors.PRIMARY_SOFT)
              .borderRadius(10)
            Text(`净专注率 ${this.summary.focusRate}%`)
              .fontSize(11)
              .fontColor(Colors.PRIMARY_DARK)
              .padding({ top: 4, bottom: 4, left: 8, right: 8 })
              .backgroundColor(Colors.PRIMARY_SOFT)
              .borderRadius(10)
          }
          .margin({ top: 6 })
        } else {
          Text('暂无练习记录')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 20, bottom: 20 })
            .width('100%')
            .textAlign(TextAlign.Center)
        }
      }
      .layoutWeight(1)
      .padding(14)
      .backgroundColor(Colors.CARD)
      .borderRadius(Radius.LG)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)

    // 长期建议
    Column({ space: Spacing.SM }) {
      this.sectionHeader('💡', '长期建议')
      Text(this.aiAdvice.length > 0 ? this.aiAdvice : '完成更多专注后，我会根据你的真实数据给出学习建议。')
        .fontSize(14)
        .fontColor(Colors.TEXT_PRIMARY)
        .lineHeight(22)
        .margin({ top: 6 })
        .width('100%')

    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    // 学习习惯洞察（全部来自真实数据；无数据时显示空态，不给与用户无关的建议）
    Column({ space: Spacing.SM }) {
      this.sectionHeader('🕐', '学习习惯洞察')
      // 数据来源与生成逻辑：算得出来就该讲得清，避免用户把规则结论当成"AI 猜的"
      Text('数据来源：取每一次已完成专注的**开始时间**，按每 2 小时归入一个时段（全天 12 个时段）；' +
        '时段专注率 = 该时段的净专注时长 ÷ 该时段总学习时长（总学习 = 墙钟 − 休息 − 暂停）。\n' +
        '生成逻辑：高峰 = 总学习时长最多的时段，低谷 = 总学习时长最少的时段；' +
        '若低谷的专注率比高峰低 10 个百分点以上，记为「容易分心」，否则记为「投入偏少」。' +
        '建议由这两者的对比自动生成，没有写死的文案；只统计到一个时段时会如实说明，不做外推。')
        .fontSize(11)
        .fontColor(Colors.TEXT_TERTIARY)
        .lineHeight(17)
        .width('100%')
        .margin({ top: 6 })

      if (this.habit.advice.length === 0) {
        Text('还没有足够的时段数据。多在不同时段完成几次专注，这里会给出你的高峰与低谷。')
          .fontSize(13)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')
          .margin({ top: 8 })
      } else {
      Column({ space: Spacing.XS }) {
        Row() {
          Text('最佳学习时段：')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
          Text(`${this.habit.bestWindow}（专注率 ${this.habit.bestRate}%）`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
        }
        .width('100%')

        if (this.habit.lowWindow.length > 0) {
          Row() {
            Text('低谷时段：')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
            Text(`${this.habit.lowWindow}（${this.habit.lowNote}）`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
          }
          .width('100%')
        }

        Row() {
          Text('习惯建议：')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
          Text(this.habit.advice)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .layoutWeight(1)
        }
        .width('100%')
      }
      .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    // 长期计划与目标（原「规划提升方案」的位置）
    // 注意：这个地方**不应该**跳到单次/当日的规划器——那是"今天做什么"，
    // 与"长期总结"语境是断的，还会把今日计划冲掉。所以改成设置长期计划本身。
    Column({ space: Spacing.SM }) {
      Row() {
        Text('长期计划与目标')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(this.longPlan === null ? '未设置' : '已设置')
          .fontSize(12)
          .fontColor(this.longPlan === null ? Colors.TEXT_TERTIARY : Colors.GREEN)
      }
      .width('100%')

      Text(this.goalLine())
        .fontSize(12)
        .fontColor(Colors.TEXT_SECONDARY)
        .lineHeight(18)
        .width('100%')

      if (this.longPlan === null) {
        Text('还没有长期计划。设一个"这段时间要做成什么"，规划时会作为背景参考。')
          .fontSize(13)
          .fontColor(Colors.TEXT_SECONDARY)
          .lineHeight(20)
          .width('100%')
      } else {
        Text(`${this.longPlan.title}${this.longPlan.examType.length > 0 ? ' · ' + this.longPlan.examType : ''}${this.longPlan.totalEstimatedMinutes > 0 ? ' · 目标 ' + Math.round(this.longPlan.totalEstimatedMinutes / 60) + ' 小时' : ''}`)
          .fontSize(14)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
      }

      Button('修改长期计划与目标')
        .type(ButtonType.Capsule)
        .fontSize(14)
        .fontColor(Colors.TEXT_PRIMARY)
        .backgroundColor(Colors.PRIMARY_SOFT)
        .width('70%')
        .margin({ top: 6 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/LongTermPlan' })
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    Blank().height(24)
  }

  /** 顶部栏：左侧标题（不再显示 iKnow）+ 右上角「日历图标 + 日期」下拉触发 */
  @Builder
  topBar() {
    Row() {
      Text(this.mode === 0 ? '长期学习总结' : '学习复盘')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)

      Blank()

      Row({ space: 8 }) {
        // 动态日历图标：长期=今天，按天=所选日期
        DateChip({ day: this.chipDay(), chipSize: 24 })
        Text(this.chipLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(this.showPicker ? '▴' : '▾')
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
      }
      .padding({ left: 10, right: 12, top: 6, bottom: 6 })
      .backgroundColor(Colors.CARD)
      .borderRadius(16)
      .border({ width: 1, color: Colors.LINE })
      .onClick(() => {
        this.pickDay()
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column({ space: Spacing.LG }) {
          this.topBar()

          if (this.mode === 0) {
            this.longView()
          } else {
            this.dayView()
          }

          Blank().height(20)
        }
        .padding(20)
        .width('100%')
      }
      .backgroundColor(Colors.BG)
      .width('100%')
      .height('100%')

      // 右上角下拉面板：遮罩 + 贴着日期 chip 下方弹出的面板
      if (this.showPicker) {
        Column() {}
        .width('100%')
        .height('100%')
        .backgroundColor('#22000000')
        .onClick(() => {
          this.showPicker = false
        })

        Column() {
          this.pickerPanel()
        }
        .margin({ top: 62, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
