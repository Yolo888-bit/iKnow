import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
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
  @State habit: HabitInsight = { bestWindow: '08:00 - 10:00', bestRate: 0, lowWindow: '晚间 21 点后', lowNote: '容易分心', advice: '难题优先安排上午攻克。' }
  @State aiAdvice: string = ''
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
    states: []
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

  aboutToAppear(): void {
    const store = AppStore.getInstance()
    const sessions: FocusSession[] = store.getSessions()
    const tasks: Task[] = store.getTasks()
    const now = Date.now()

    this.summary = Metrics.last30DaysSummary(sessions, tasks, now)
    this.practice = Metrics.practiceSummary(sessions, tasks)
    this.habit = Metrics.habitInsights(sessions)

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

    // 默认选中「今天」
    this.dayStart = TimeUtils.dayStart(now)

    // 初始化日历弹层（选中日 = 今天，视图定位到当月）
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
          .fontColor(Colors.PRIMARY)
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
    .shadow({ radius: 24, color: '#26000000', offsetX: 0, offsetY: 8 })
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
    this.daySuggestions = AIService.getInstance().daySuggestions(this.day.studyMinutes, this.day.focusRate)
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
    grad.addColorStop(0, 'rgba(127,191,151,0.35)')
    grad.addColorStop(1, 'rgba(127,191,151,0.02)')
    c.fillStyle = grad
    c.fill()

    // 平滑曲线
    c.beginPath()
    c.moveTo(points[0][0], points[0][1])
    this.curveThrough(c, points)
    c.strokeStyle = '#7FBF97'
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
      c.strokeStyle = 'rgba(127,191,151,0.55)'
      c.lineWidth = 1
      c.stroke()

      // 高亮点
      c.beginPath()
      c.arc(px, py, 5, 0, Math.PI * 2)
      c.fillStyle = '#FFFFFF'
      c.fill()
      c.lineWidth = 3
      c.strokeStyle = '#7FBF97'
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

  /** 顶部日期 chip 文案：长期=今天，按天=所选日期 */
  private chipLabel(): string {
    if (this.mode === 0) {
      return `${this.todayM + 1}月${this.todayD}日`
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
  @Builder
  dayView() {
    // 顶部状态卡
    Column({ space: Spacing.SM }) {
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
        Row() {
          CircularProgress({ percent: this.day.focusRate, boxSize: 96, label: '专注率' })
          FocusChart({ levels: this.day.levels, states: this.day.states })
            .layoutWeight(1)
            .height(90)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 4 })
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
      this.metricTile('专注分数', `${this.day.focusRate}`, '分')
      this.metricTile('答疑回顾', `${this.day.qaSessions}`, '次')
    }
    .width('100%')

    // AI 洞察
    Column({ space: Spacing.SM }) {
      this.sectionHeader('⭐', 'AI 洞察')
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
      Text('你的专注稳定性正在提升')
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
          .backgroundColor('#CC2F2A26')
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
        Row() {
          Text('练习内容总结')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
          Blank()
          Text('›')
            .fontSize(20)
            .fontColor(Colors.TEXT_TERTIARY)
        }
        .width('100%')

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

          Row({ space: Spacing.SM }) {
            Text('全科稳步提升')
              .fontSize(11)
              .fontColor('#7FBF97')
              .padding({ top: 4, bottom: 4, left: 8, right: 8 })
              .backgroundColor('#E4F1E9')
              .borderRadius(10)
            Text('数学进步明显')
              .fontSize(11)
              .fontColor('#7FBF97')
              .padding({ top: 4, bottom: 4, left: 8, right: 8 })
              .backgroundColor('#E4F1E9')
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

    // AI 学习建议
    Column({ space: Spacing.SM }) {
      this.sectionHeader('💡', 'AI 学习建议')
      Text(this.aiAdvice.length > 0 ? this.aiAdvice : '完成更多专注后，我会根据你的真实数据给出学习建议。')
        .fontSize(14)
        .fontColor(Colors.TEXT_PRIMARY)
        .lineHeight(22)
        .margin({ top: 6 })
        .width('100%')

      Button('查看详细报告')
        .type(ButtonType.Capsule)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#7FBF97')
        .width('60%')
        .margin({ top: 10 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/StudyReport' })
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    // 学习习惯洞察
    Column({ space: Spacing.SM }) {
      this.sectionHeader('🕐', '学习习惯洞察')
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
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)

    // 规划提升方案
    Button('规划提升方案')
      .type(ButtonType.Capsule)
      .fontSize(16)
      .fontColor(Colors.TEXT_PRIMARY)
      .backgroundColor('#E4F1E9')
      .width('70%')
      .margin({ top: 8, bottom: 24 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/TaskPlanning' })
      })
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

      Row({ space: 6 }) {
        Text('📅').fontSize(15)
        Text(this.chipLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(this.showPicker ? '▴' : '▾')
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(Colors.CARD)
      .borderRadius(16)
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
        Column({ space: Spacing.MD }) {
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
