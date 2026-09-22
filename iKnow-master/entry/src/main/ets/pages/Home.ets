import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { PermissionService } from '../services/PermissionService'
import { FocusController } from '../services/FocusController'
import { Task } from '../models/Task'
import { TaskStatus } from '../models/Enums'
import { TimeUtils } from '../utils/TimeUtils'
import { TaskCard } from '../components/TaskCard'
import { UserAvatar } from '../components/UserAvatar'

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
  @StorageProp(StorageKey.FOCUS_ELAPSED) focusElapsed: number = 0
  /** 实时净专注 / 总学习（进行中时用于现算净专注率） */
  @StorageProp(StorageKey.FOCUS_NET) focusNet: number = 0
  @StorageProp(StorageKey.FOCUS_STUDY) focusStudy: number = 0
  /** 1 = 会话进行中（响应式；之前用普通方法读单例，导致 UI 不刷新） */
  @StorageProp(StorageKey.FOCUS_RUNNING) focusRunningFlag: number = 0
  /**
   * 唯一的刷新触发点：pushAggregates() 最后才写 DATA_VERSION，
   * 因此它一变就代表"今日聚合已整体算完"。今日数据的具体数值走 refreshPlan() 拉取。
   */
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refreshPlan') dataVersion: number = 0
  @State examType: string = ''
  @State completionRate: number = 0
  @State plan: Task[] = []
  /**
   * 今日数据一律从 store 的 dashboard **拉取**，不再依赖 @StorageProp 镜像。
   *
   * 原因：pushAggregates() 会连续写 TODAY_* / FOCUS_RATE / DATA_VERSION 多个键，
   * 而 @Watch 回调里读到的镜像值**不保证已经同步**（同一批更新里 DATA_VERSION 可能先被处理），
   * 于是由镜像派生的「任务完成率」会永久停在旧值 —— 表现就是"结束专注后首页数据没更新"。
   * dashboard 在 pushAggregates() 之前就已整体赋值，读它永远是最新的，与更新顺序无关。
   */
  @State dashTodayFocus: number = 0
  @State dashRate: number = 0
  @State dashDone: number = 0
  @State dashTotal: number = 0
  /** 顶部问候语（按当前时间） */
  @State greeting: string = ''
  /** 今日任务是否展开（可折叠） */
  @State tasksExpanded: boolean = true
  /** 目标日期文案（目标总览里展示） */
  @State targetDateText: string = ''

  aboutToAppear(): void {
    this.refreshPlan()
  }

  refreshPlan(): void {
    // 今日任务：**已完成置顶、未完成自动沉底**；同组内保持原有顺序（稳定分桶，
    // 不改变用户/AI 排好的先后）。必须新建数组：赋同一个引用不会触发 @State 重绘。
    const source = AppStore.getInstance().getCurrentPlan()
    const todo: Task[] = []
    const finished: Task[] = []
    for (const t of source) {
      if (t.done || t.status === TaskStatus.DONE) {
        finished.push(t)
      } else {
        todo.push(t)
      }
    }
    this.plan = finished.concat(todo)

    const goal = AppStore.getInstance().getGoal()
    this.examType = goal.examType

    // 今日数据：直接读 store 里已经算好的聚合结果（权威值），不看镜像
    const d = AppStore.getInstance().getDashboard()
    this.dashTodayFocus = d.todayFocusSeconds
    this.dashRate = d.focusRate
    this.dashDone = d.todayCompletedTasks
    this.dashTotal = d.todayTotalTasks
    this.completionRate = this.dashTotal > 0 ? Math.round(this.dashDone / this.dashTotal * 100) : 0
    this.greeting = TimeUtils.greeting(Date.now())
    if (goal.targetDate > 0) {
      const gd = new Date(goal.targetDate)
      this.targetDateText = `${gd.getFullYear()} 年 ${gd.getMonth() + 1} 月 ${gd.getDate()} 日`
    } else {
      this.targetDateText = ''
    }
  }

  /** 今日计划里已完成的数量（卡片右上角用） */
  private planDone(): number {
    let n = 0
    for (const t of this.plan) {
      if (t.done) {
        n += 1
      }
    }
    return n
  }

  /**
   * 勾选 / 取消勾选今日任务。
   * 走 AppStore.toggleTaskDone：落库 + 重算聚合 → 今日数据里的完成率、工作台进度都会跟着变。
   */
  private async toggleTask(id: string): Promise<void> {
    await AppStore.getInstance().toggleTaskDone(id)
    this.refreshPlan()
  }

  private displayName(): string {
    return this.nickname.length > 0 ? this.nickname : '同学'
  }

  /** 目标总览脚下那行提示：没填日期时换一种说法，填了就给倒计时 */
  private examHint(): string {
    if (this.examType.length === 0) {
      return '在「我的 → 长期计划与目标」里填写目标与日期，倒计时才会准确'
    }
    const d = this.examDaysText()
    if (d === '—') {
      return `还没填「${this.examType}」的考试日期，补上之后倒计时才准`
    }
    return `距离 ${this.examType} 还有 ${d} 天，按节奏稳步推进`
  }

  /** 倒计时主数值：未设置或已过期都显示「—」（TimeUtils.daysUntil 会把过去的时间夹到 0） */
  private examDaysText(): string {
    const g = AppStore.getInstance().getGoal()
    if (g.targetDate <= 0) {
      return '—'
    }
    return TimeUtils.daysUntil(g.targetDate, Date.now()) > 0 ? `${this.examDays}` : '—'
  }

  /** 倒计时副标签 */
  private examDaysSub(): string {
    const g = AppStore.getInstance().getGoal()
    if (g.targetDate <= 0) {
      return '未设日期'
    }
    return TimeUtils.daysUntil(g.targetDate, Date.now()) > 0 ? '天' : '已过期'
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
   * 今日专注时长（**实时**）= 已结束会话的累计（dashboard，权威值） + 进行中会话的实时增量。
   * 之前只读 @StorageProp 镜像累计值，镜像没同步时看着"今日数据不更新"。
   */
  private liveFocusSec(): number {
    return this.dashTodayFocus + (this.focusRunningFlag === 1 ? this.focusElapsed : 0)
  }

  /** 净专注率（实时）：进行中用「净专注 / 总学习」现算，结束后用落库聚合值 */
  private liveRate(): number {
    if (this.focusRunningFlag === 1 && this.focusStudy > 0) {
      return Math.round(this.focusNet / this.focusStudy * 100)
    }
    return this.dashRate
  }

  /**
   * 今日专注时长的展示文案：**不足 1 分钟按秒显示**。
   *
   * 直接走 formatHMin() 时，1 分钟以内的会话结束后显示的还是 "0min"，
   * 和没开始时一模一样 —— 用户（尤其测试时）完全看不出刷新了没有。
   */
  private focusSecondsText(): string {
    const sec = this.liveFocusSec()
    if (sec > 0 && sec < 60) {
      return `${Math.floor(sec)}秒`
    }
    return TimeUtils.formatHMin(sec)
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
        // 顶部：问候 + 头像（原工作台的顶部搬到这里）
        Row() {
          Column() {
            Text(`${this.greeting}，${this.displayName()}`)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
            Text('今天也一起稳稳推进吧')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 6 })
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack() {
            UserAvatar({ avatar: this.avatar, diameter: 48, bg: Colors.PRIMARY_SOFT })
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
        .alignItems(VerticalAlign.Center)

        // 目标总览（从工作台搬过来）
        // 注意：这里**不提供**「调整目标」入口 —— 按需求直接去掉，
        // 要改目标统一走「我的 → 长期计划与目标」。
        Column() {
          Text('目标总览')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')

          if (this.examType.length === 0) {
            Text('还没设置目标')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 8 })
              .width('100%')
            Text('在「我的 → 长期计划与目标」里填写目标与日期，倒计时才会准确')
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ top: 10 })
              .width('100%')
          } else {
            Row() {
              Column() {
                Text(this.examType)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Colors.PRIMARY_DARK)
                  .margin({ top: 8 })
                Text(this.targetDateText.length > 0 ? `目标日期 ${this.targetDateText}` : '未设置目标日期')
                  .fontSize(12)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column() {
                Text(this.examDaysText())
                  .fontSize(34)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Colors.TEXT_PRIMARY)
                Text(this.examDaysSub())
                  .fontSize(12)
                  .fontColor(Colors.TEXT_SECONDARY)
              }
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')

            Text(this.examHint())
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ top: 12 })
              .width('100%')
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .alignItems(HorizontalAlign.Start)
        .shadow({ radius: 18, color: Colors.SHADOW, offsetX: 0, offsetY: 6 })

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
              .backgroundColor(Colors.PRIMARY_STRONG)
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

        // 今日任务：与其他模块同款卡片（标题左右对齐一致），勾选即完成并同步进度
        Column() {
          Row() {
            Text('今日任务')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text(this.plan.length === 0
              ? '待规划'
              : `${this.planDone()} / ${this.plan.length} 已完成`)
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
            // 折叠开关：任务多的时候可以收起来
            Text(this.tasksExpanded ? '收起 ▴' : '展开 ▾')
              .fontSize(12)
              .fontColor(Colors.PRIMARY_DARK)
              .margin({ left: 10 })
          }
          .width('100%')
          .margin({ bottom: 12 })
          .onClick(() => {
            this.tasksExpanded = !this.tasksExpanded
          })

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
            .padding({ top: 8, bottom: 8 })
            .alignItems(HorizontalAlign.Start)
          } else if (!this.tasksExpanded) {
            Text(`已收起 ${this.plan.length} 个任务，点右上角展开`)
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .width('100%')
              .padding({ top: 4, bottom: 4 })
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
              }, (task: Task) => `${task.id}_${task.done ? 1 : 0}`)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .shadow({ radius: 18, color: Colors.SHADOW, offsetX: 0, offsetY: 6 })

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
            this.statTile(this.focusSecondsText(), '今日专注时长')
            // 口径写清：这是**今日计划**的勾选完成率，与「长期计划与目标」里的各科目标进度不是同一个数
          this.statTile(this.dashTotal > 0 ? `${this.completionRate}%` : '—', '今日任务完成率')
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .shadow({ radius: 18, color: Colors.SHADOW, offsetX: 0, offsetY: 6 })

        // 主操作按钮
        Button(this.focusRunningFlag === 1 ? '继续专注' : '开始专注')
          .width('100%')
          .height(52)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Colors.PRIMARY_STRONG)
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
