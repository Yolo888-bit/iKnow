import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { PermissionService } from '../services/PermissionService'
import { Task } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { TaskCard } from '../components/TaskCard'

/** 首页 / 今日专注 */
@Component
export struct Home {
  @StorageProp(StorageKey.USER_NICKNAME) nickname: string = '刘灿'
  @StorageProp(StorageKey.EXAM_DAYS) examDays: number = 0
  @StorageProp(StorageKey.TODAY_FOCUS_SEC) todayFocus: number = 0
  @StorageProp(StorageKey.FOCUS_RATE) focusRate: number = 0
  @StorageProp(StorageKey.TODAY_DONE_TASKS) todayDone: number = 0
  @StorageProp(StorageKey.TODAY_TOTAL_TASKS) todayTotal: number = 0
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refreshPlan') dataVersion: number = 0
  @State goalTitle: string = '考研上岸'
  @State examType: string = '考研'
  @State completionRate: number = 0
  @State plan: Task[] = []

  aboutToAppear(): void {
    this.refreshPlan()
  }

  refreshPlan(): void {
    this.plan = AppStore.getInstance().getCurrentPlan()
    const goal = AppStore.getInstance().getGoal()
    this.goalTitle = goal.title
    this.examType = goal.examType
    this.completionRate = this.todayTotal > 0 ? Math.round(this.todayDone / this.todayTotal * 100) : 0
  }

  private startFocus(): void {
    if (this.plan.length === 0) {
      router.pushUrl({ url: 'pages/TaskPlanning' })
      return
    }
    // 摄像头感知授权前置：已授权直接使用；未授权弹出选择，拒绝则降级仅计时模式
    if (PermissionService.getInstance().isCameraOn()) {
      router.pushUrl({ url: 'pages/Focus' })
      return
    }
    AlertDialog.show({
      title: '开启摄像头感知？',
      message: '开启后，我会用前置摄像头在本地感知你的专注状态，全程不出端、不上传。你也可以选择仅计时模式。',
      primaryButton: {
        value: '开启感知',
        action: () => {
          PermissionService.getInstance().grant('camera')
          router.pushUrl({ url: 'pages/Focus' })
        }
      },
      secondaryButton: {
        value: '仅计时开始',
        action: () => {
          router.pushUrl({ url: 'pages/Focus' })
        }
      }
    })
  }

  @Builder
  statTile(value: string, label: string) {
    Column() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
      Text(label)
        .fontSize(12)
        .fontColor(Colors.TEXT_SECONDARY)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
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

        // 今日目标（点击进入目标编辑 / 规划）
        Column() {
          Row() {
            Text('今日目标')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text('编辑 ›')
              .fontSize(13)
              .fontColor(Colors.PRIMARY_DARK)
          }
          .width('100%')

          Row({ space: 16 }) {
            Column() {
              Text(this.examType)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Colors.PRIMARY_DARK)
              Text(this.goalTitle)
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Text(`${this.examDays}`)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(Colors.TEXT_PRIMARY)
              Text('天')
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .onClick(() => {
          router.pushUrl({ url: 'pages/TaskPlanning' })
        })

        // 今日任务
        Column() {
          Row() {
            Text('今日任务')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text(`${this.plan.length === 0 ? '待规划' : this.plan.length + ' 项'}`)
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.plan.length === 0) {
            Column() {
              Text('还没有今日计划')
                .fontSize(15)
                .fontColor(Colors.TEXT_PRIMARY)
              Text('点这里，让小伴帮你规划今天')
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(20)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
            .onClick(() => {
              router.pushUrl({ url: 'pages/TaskPlanning' })
            })
          } else {
            Column({ space: Spacing.SM }) {
              ForEach(this.plan, (task: Task) => {
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
            .width('100%')
          }
        }
        .width('100%')

        // 今日数据
        Column() {
          Text('今日数据')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 14 })

          Row({ space: 8 }) {
            this.statTile(`${this.focusRate}%`, '净专注率')
            this.statTile(TimeUtils.formatHMin(this.todayFocus), '今日专注时长')
            this.statTile(`${this.completionRate}%`, '任务完成率')
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)

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
