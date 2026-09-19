import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { PermissionService } from '../services/PermissionService'
import { FocusController } from '../services/FocusController'
import { Task } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { TaskCard } from '../components/TaskCard'

/**
 * 专注首页（tab 0）—— 回答 PRD 第十节的三件事：
 * 「今天学什么 / 现在状态如何 / 是否开始专注」
 *
 * 开始专注有两条路：已有今日计划 → 直接进；没有计划 → 让用户选「帮我规划」或「自由专注」，
 * 不再强制先聊完规划。
 */
@Component
export struct Home {
  @StorageProp(StorageKey.USER_NICKNAME) nickname: string = ''
  @StorageProp(StorageKey.USER_AVATAR) avatar: string = '🧑‍🎓'
  @StorageProp(StorageKey.EXAM_DAYS) examDays: number = 0
  @StorageProp(StorageKey.TODAY_FOCUS_SEC) todayFocus: number = 0
  @StorageProp(StorageKey.FOCUS_RATE) focusRate: number = 0
  @StorageProp(StorageKey.TODAY_DONE_TASKS) todayDone: number = 0
  @StorageProp(StorageKey.TODAY_TOTAL_TASKS) todayTotal: number = 0
  @StorageProp(StorageKey.FOCUS_ELAPSED) focusElapsed: number = 0
  /** 实时净专注 / 总学习（进行中时用于现算净专注率） */
  @StorageProp(StorageKey.FOCUS_NET) focusNet: number = 0
  @StorageProp(StorageKey.FOCUS_STUDY) focusStudy: number = 0
  /** 1 = 会话进行中（响应式；之前用普通方法读单例，导致 UI 不刷新） */
  @StorageProp(StorageKey.FOCUS_RUNNING) focusRunningFlag: number = 0
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refreshPlan') dataVersion: number = 0
  @State goalTitle: string = ''
  @State examType: string = ''
  @State completionRate: number = 0
  @State plan: Task[] = []

  aboutToAppear(): void {
    this.refreshPlan()
  }

  refreshPlan(): void {
    // 必须 slice 出新数组：赋同一个引用不会触发 @State 重绘，
    // 会导致结束后按钮文案与「继续专注」条不更新
    this.plan = AppStore.getInstance().getCurrentPlan().slice()
    const goal = AppStore.getInstance().getGoal()
    this.goalTitle = goal.title
    this.examType = goal.examType
    this.completionRate = this.todayTotal > 0 ? Math.round(this.todayDone / this.todayTotal * 100) : 0
  }

  private displayName(): string {
    return this.nickname.length > 0 ? this.nickname : '同学'
  }

  private cameraOn(): boolean {
    return PermissionService.getInstance().isCameraOn()
  }

  /** 开始专注：有计划直接进；没有计划先问一句（可跳过规划） */
  private startFocus(): void {
    if (AppStore.getInstance().getCurrentPlan().length > 0 || this.focusRunningFlag === 1) {
      this.beginFocus()
      return
    }
    AlertDialog.show({
      title: '今天还没有计划',
      message: '要我按你的目标帮你拆一份今日任务，还是直接开始自由专注（不设定任务）？',
      primaryButton: {
        value: '帮我规划',
        action: () => {
          this.openAIPlanning()
        }
      },
      secondaryButton: {
        value: '直接开始',
        action: () => {
          this.beginFocus()
        }
      }
    })
  }

  /** 进专注页前确认感知授权；拒绝或申请失败则降级为仅计时模式（诚实告知） */
  private beginFocus(): void {
    if (this.cameraOn()) {
      this.enterFocus()
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    AlertDialog.show({
      title: '开启摄像头感知？',
      message: '开启后，我会用前置摄像头感知你的专注状态（仅在触发时抓拍短片段）。你也可以选择仅计时模式。',
      primaryButton: {
        value: '开启感知',
        action: () => {
          // 真正申请系统相机权限（user_grant）；失败也照常进入专注，降级为仅计时模式
          PermissionService.getInstance().ensureCamera(ctx).then(() => {
            this.enterFocus()
          })
        }
      },
      secondaryButton: {
        value: '仅计时开始',
        action: () => {
          this.enterFocus()
        }
      }
    })
  }

  private enterFocus(): void {
    if (!FocusController.getInstance().isRunning()) {
      // 只有主动开始才允许 Focus 页新开会话（会话在跑则直接进去继续）
      AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 1)
    }
    router.pushUrl({ url: 'pages/Focus' })
  }

  private resumeFocus(): void {
    router.pushUrl({ url: 'pages/Focus' })
  }

  /** 切到「AI 规划」Tab（不在首页再开一个规划实例） */
  private openAIPlanning(): void {
    AppStorage.setOrCreate<number>(StorageKey.INDEX_TAB_REQUEST, 1)
  }

  /**
   * 今日专注时长（**实时**）= 已结束会话累计 + 进行中会话的实时增量。
   * 之前只读落库累计值，进行中不动，所以看着"今日数据不更新"。
   */
  private liveFocusSec(): number {
    return this.todayFocus + (this.focusRunningFlag === 1 ? this.focusElapsed : 0)
  }

  /** 净专注率（实时）：进行中用「净专注 / 总学习」现算，结束后用落库值 */
  private liveRate(): number {
    if (this.focusRunningFlag === 1 && this.focusStudy > 0) {
      return Math.round(this.focusNet / this.focusStudy * 100)
    }
    return this.focusRate
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
            Text(`${TimeUtils.greeting(Date.now())}，${this.displayName()}`)
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
            Text(this.avatar)
              .fontSize(26)
              .width(48)
              .height(48)
              .textAlign(TextAlign.Center)
              .backgroundColor(Colors.CARD)
              .borderRadius(24)
            // 摄像头指示灯只在真正开启感知时亮起
            if (this.cameraOn()) {
              Circle()
                .width(10)
                .height(10)
                .fill(Colors.CAMERA_RED)
                .position({ x: 36, y: 2 })
            }
          }
        }
        .width('100%')

        // 专注进行中：返回键留在后台的会话不丢，从这里继续
        if (this.focusRunningFlag === 1) {
          Row() {
            Text(`专注进行中 · ${TimeUtils.formatClock(this.focusElapsed)}`)
              .fontSize(14)
              .fontColor(Colors.TEXT_PRIMARY)
              .layoutWeight(1)
            Button('继续专注')
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor(Colors.PRIMARY)
              .height(34)
              .borderRadius(17)
              .onClick(() => {
                this.resumeFocus()
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Colors.PRIMARY_SOFT)
          .borderRadius(Radius.MD)
        }

        // 今日目标（未设置时给明确指引，不显示假倒计时）
        Column() {
          Text('今日目标')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')

          if (this.examType.length === 0) {
            Text('还没设置目标考试')
              .fontSize(16)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 10 })
              .width('100%')
            Text('在「我的 → 长期计划与目标」里填写')
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ top: 6 })
              .width('100%')
          } else {
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
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)

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
              Text('可以直接开始自由专注，或帮你拆一份任务')
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(20)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
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
                    // 必须 slice 出新数组：赋同一个引用不会触发 @State 重绘（勾选状态不更新）
                    this.plan = AppStore.getInstance().getCurrentPlan().slice()
                    this.refreshPlan()
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
            this.statTile(`${this.liveRate()}%`, '净专注率')
            this.statTile(TimeUtils.formatHMin(this.liveFocusSec()), '今日专注时长')
            this.statTile(this.todayTotal > 0 ? `${this.completionRate}%` : '—', '任务完成率')
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)

        // 主操作按钮
        Button(this.focusRunningFlag === 1 ? '继续专注' : '开始专注')
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

        // 次级入口：AI 规划（不抢主按钮位置）
        Row() {
          Text('🤖')
            .fontSize(18)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .backgroundColor(Colors.CARD)
            .borderRadius(18)
          Column() {
            Text('规划今天的学习')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('按目标拆一份今日任务')
              .fontSize(12)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
          Text('›')
            .fontSize(20)
            .fontColor(Colors.PRIMARY_DARK)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.MD)
        .onClick(() => {
          this.openAIPlanning()
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
