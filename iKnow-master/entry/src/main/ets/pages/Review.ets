import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { Metrics, Last30DaysSummary, PracticeSummaryItem, HabitInsight } from '../services/Metrics'
import { AIService } from '../services/AIService'
import { FocusProfile } from '../models/FocusProfile'
import { RadarChart } from '../components/RadarChart'
import { FocusSession } from '../models/FocusSession'
import { Task } from '../models/Task'

/** 长期学习总结 —— 单屏区块式复盘页（参考 UI：近30天表现 / 画像 / 练习 / AI建议 / 习惯洞察） */
@Entry
@Component
export struct Review {
  @State summary: Last30DaysSummary = { totalHours: 0, completedTasks: 0, focusRate: 0, trend: [] }
  @State practice: PracticeSummaryItem[] = []
  @State habit: HabitInsight = { bestWindow: '08:00 - 10:00', bestRate: 0, lowWindow: '晚间 21 点后', lowNote: '容易分心', advice: '难题优先安排上午攻克。' }
  @State aiAdvice: string = ''
  @State profile: FocusProfile = new FocusProfile()
  @State dimValues: number[] = []
  @State canShowRadar: boolean = false
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

    // 渐变填充区域
    c.beginPath()
    c.moveTo(points[0][0], padTop + chartH)
    for (const p of points) {
      c.lineTo(p[0], p[1])
    }
    c.lineTo(points[points.length - 1][0], padTop + chartH)
    c.closePath()
    const grad = c.createLinearGradient(0, padTop, 0, padTop + chartH)
    grad.addColorStop(0, 'rgba(127,191,151,0.35)')
    grad.addColorStop(1, 'rgba(127,191,151,0.02)')
    c.fillStyle = grad
    c.fill()

    // 折线
    c.beginPath()
    for (let i = 0; i < points.length; i++) {
      const p = points[i]
      if (i === 0) {
        c.moveTo(p[0], p[1])
      } else {
        c.lineTo(p[0], p[1])
      }
    }
    c.strokeStyle = '#7FBF97'
    c.lineWidth = 3
    c.lineJoin = 'round'
    c.lineCap = 'round'
    c.stroke()

    // 顶点
    for (const p of points) {
      c.beginPath()
      c.arc(p[0], p[1], 4, 0, Math.PI * 2)
      c.fillStyle = '#FFFFFF'
      c.fill()
      c.lineWidth = 2
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

  build() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        // 顶部标题栏
        Row() {
          Text('iKnow')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.PRIMARY)
          Blank()
          Text('长期学习总结')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Blank()
          Text('📅')
            .fontSize(22)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })

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

          Canvas(this.lineCtx)
            .width('100%')
            .height(150)
            .margin({ top: 8, bottom: 8 })
            .onReady(() => {
              this.onLineChartReady()
            })

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
          // 个人专注画像
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

          // 练习内容总结
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

        Blank().height(20)
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }
}
