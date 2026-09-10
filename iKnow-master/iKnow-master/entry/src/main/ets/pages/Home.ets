import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { AIService } from '../services/AIService'
import { Task } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { TaskCard } from '../components/TaskCard'
import { CircularProgress } from '../components/CircularProgress'

/** 首页 / 今日专注 */
@Component
export struct Home {
  @StorageProp(StorageKey.USER_NICKNAME) nickname: string = '刘灿'
  @StorageProp(StorageKey.TODAY_FOCUS_SEC) todayFocus: number = 0
  @StorageProp(StorageKey.FOCUS_RATE) focusRate: number = 0
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refreshPlan') dataVersion: number = 0
  @State plan: Task[] = []
  @State showProactive: boolean = true

  aboutToAppear(): void {
    this.refreshPlan()
  }

  refreshPlan(): void {
    this.plan = AppStore.getInstance().getCurrentPlan()
  }

  private deltaText(): string {
    const trend = AppStore.getInstance().getDashboard().weekTrend
    if (trend.length < 2) {
      return '新的一天，慢慢来'
    }
    const today = trend[trend.length - 1]
    const yest = trend[trend.length - 2]
    if (yest <= 0) {
      return '新的一天，慢慢来'
    }
    const d = Math.round((today - yest) / yest * 100)
    if (d > 0) {
      return `↑ 比昨天提升 ${d}%`
    }
    if (d < 0) {
      return '比昨天稍少一点，没关系'
    }
    return '和昨天持平，很稳'
  }

  private startFocus(): void {
    if (this.plan.length === 0) {
      router.pushUrl({ url: 'pages/TaskPlanning' })
    } else {
      router.pushUrl({ url: 'pages/Focus' })
    }
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        // 顶部问候
        Row() {
          Column() {
            Text(`${TimeUtils.greeting(Date.now())}，${this.nickname}`)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('今天也一起慢慢进入状态吧')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack() {
            Text('🧑‍🎓')
              .fontSize(26)
              .width(48)
              .height(48)
              .textAlign(TextAlign.Center)
              .backgroundColor(Colors.CARD)
              .borderRadius(24)
            Circle()
              .width(10)
              .height(10)
              .fill(Colors.CAMERA_RED)
              .position({ x: 36, y: 2 })
          }
        }
        .width('100%')

        // 今日专注数据
        Column() {
          Row() {
            CircularProgress({ percent: this.focusRate, boxSize: 132, label: '净专注率' })
            Column() {
              Text('今日已专注').fontSize(13).fontColor(Colors.TEXT_SECONDARY)
              Text(TimeUtils.formatHMin(this.todayFocus))
                .fontSize(28)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.TEXT_PRIMARY)
                .margin({ top: 6 })
              Text(this.deltaText())
                .fontSize(12)
                .fontColor(Colors.PRIMARY_DARK)
                .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 24 })
            .layoutWeight(1)
          }
          .width('100%')
          .padding(20)
        }
        .width('100%')
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)

        // 当前学习任务
        Column() {
          Text('当前学习任务')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 12 })

          if (this.plan.length === 0) {
            Text('还没有今日计划，去规划一个吧')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .width('100%')
              .padding(20)
              .backgroundColor(Colors.CARD)
              .borderRadius(Radius.MD)
          } else {
            ForEach(this.plan.slice(0, 3), (task: Task) => {
              TaskCard({
                title: task.title,
                subject: task.subject,
                minutes: task.estimatedDuration,
                done: task.done,
                showCheckbox: true,
                onToggle: () => {
                  AppStore.getInstance().togglePlanTask(task.id)
                  this.plan = AppStore.getInstance().getCurrentPlan()
                }
              })
            }, (task: Task) => task.id)
          }
        }
        .width('100%')

        // 主操作按钮
        Button('开始专注')
          .width('100%')
          .height(52)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Colors.PRIMARY)
          .borderRadius(Radius.LG)
          .onClick(() => {
            this.startFocus()
          })

        // AI 主动建议
        if (this.showProactive) {
          Column() {
            Row() {
              Text('💡 小伴发现').fontSize(13).fontColor(Colors.PRIMARY_DARK)
              Blank()
              Text('稍后')
                .fontSize(13)
                .fontColor(Colors.TEXT_TERTIARY)
                .onClick(() => {
                  this.showProactive = false
                })
            }
            .width('100%')

            Text(AIService.getInstance().proactive(AppStore.getInstance().getProfile().bestFocusTime))
              .fontSize(15)
              .fontColor(Colors.TEXT_PRIMARY)
              .lineHeight(22)
              .margin({ top: 10 })

            Row() {
              Button('开始')
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor(Colors.PRIMARY)
                .height(36)
                .borderRadius(18)
                .onClick(() => {
                  this.showProactive = false
                  router.pushUrl({ url: 'pages/TaskPlanning' })
                })
              Button('稍后')
                .fontSize(14)
                .fontColor(Colors.TEXT_SECONDARY)
                .backgroundColor(Colors.CARD)
                .height(36)
                .borderRadius(18)
                .margin({ left: 12 })
                .onClick(() => {
                  this.showProactive = false
                })
            }
            .margin({ top: 12 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Colors.PRIMARY_SOFT)
          .borderRadius(Radius.MD)
        }

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
