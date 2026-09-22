import { router, promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { TimeUtils } from '../utils/TimeUtils'
import { BarChart } from '../components/BarChart'
import { Task } from '../models/Task'
import { TaskStatus } from '../models/Enums'
import { Metrics, PlanProgress, SubjectProgressRow } from '../services/Metrics'
import { UserAvatar } from '../components/UserAvatar'
import { AvatarPicker } from '../components/AvatarPicker'

/** 我的工作台 —— 学习全局看板 */
@Component
export struct Dashboard {
  @StorageProp(StorageKey.EXAM_DAYS) examDays: number = 0
  @StorageProp(StorageKey.USER_NICKNAME) nickname: string = ''
  @StorageProp(StorageKey.USER_AVATAR) avatar: string = '🧑‍🎓'
  @StorageProp(StorageKey.WEEK_FOCUS_SEC) weekFocus: number = 0
  @StorageProp(StorageKey.FOCUS_RATE) focusRate: number = 0
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refresh') dataVersion: number = 0
  @StorageProp(StorageKey.FOCUS_ELAPSED) focusElapsed: number = 0
  /** 1 = 会话进行中（响应式） */
  @StorageProp(StorageKey.FOCUS_RUNNING) focusRunningFlag: number = 0
  @State weekTrend: number[] = []
  @State examType: string = ''
  @State targetDateText: string = ''
  @State greeting: string = ''
  @State showAvatarSheet: boolean = false
  /**
   * 目标进度：**拉取**自 AppStore（权威结果），不在页面里自算口径。
   * 原来页面自己算"全部历史任务的勾选完成率"（merged/allDone/allTotal），
   * 分母含历次规划的全部任务 → 越用越接近 0%，而且和用户的"学习进度"不是一回事。
   */
  @State progress: PlanProgress = Metrics.planProgress([], null)
  @State pending: Task[] = []
  @State showPending: boolean = false

  aboutToAppear(): void {
    this.refresh()
  }

  /** 顶部问候语（按当前时间）+ 登录用户名 */
  private displayName(): string {
    const n = this.nickname.length > 0 ? this.nickname : AppStore.getInstance().getUser().nickname
    return n.length > 0 ? n : '同学'
  }

  refresh(): void {
    const now = Date.now()
    this.greeting = TimeUtils.greeting(now)
    const store = AppStore.getInstance()
    const d = store.getDashboard()
    this.weekTrend = d.weekTrend
    // 目标进度：拉取 store 的权威结果（分母 = 本期计划各科目标，主分子 = 实际投入）
    this.progress = store.getPlanProgress()

    const goal = store.getGoal()
    this.examType = goal.examType
    if (goal.targetDate > 0) {
      const gd = new Date(goal.targetDate)
      this.targetDateText = `${gd.getFullYear()} 年 ${gd.getMonth() + 1} 月 ${gd.getDate()} 日`
    } else {
      this.targetDateText = ''
    }

    // 未完成清单：仍列全部任务（含历史），但它只回答"还有什么要做"，
    // **不再是进度的分子分母**（那套口径已由 targetProgress 取代）
    const all: Task[] = store.getTasks()
    const pend: Task[] = []
    for (const t of all) {
      if (!t.done && t.status !== TaskStatus.DONE) {
        pend.push(t)
      }
    }
    // 未完成：最近的排在前面
    pend.sort((a: Task, b: Task) => b.createdAt - a.createdAt)
    this.pending = pend
  }

  /** 目标进度主数值：`实际投入 / 目标`（不 clamp，超额时照样显示真实数字） */
  private investedText(): string {
    return `${this.progress.actualMinutes} / ${this.progress.targetMinutes} 分钟`
  }

  /** 目标进度副信息：按勾选完成算的口径（辅口径，避免用户以为两个数矛盾） */
  private completedText(): string {
    return `按勾选完成算：${this.progress.doneEstimatedMinutes} / ${this.progress.targetMinutes} 分钟（${this.progress.completedPercent}%）`
  }

  /** 空态/异常态的一句说明（不默认显示 100%，也不显示 0% 冒充"有数据"） */
  private progressHint(): string {
    if (this.progress.state === 'NO_PLAN') {
      return '还没有长期计划。设置各科目标时长后，这里会按"实际投入 / 目标"显示进度。'
    }
    if (this.progress.state === 'NO_TARGET') {
      if (this.progress.unassignedTargetMinutes > 0) {
        return `已设总目标 ${Math.round(this.progress.unassignedTargetMinutes / 60)} 小时，但还没分到科目 —— 去「长期计划与目标」分一下，进度才能算。`
      }
      return '长期计划里还没填各科目标时长，进度没有分母，暂时无法计算。'
    }
    if (this.progress.state === 'NO_TASK') {
      return `各科目标合计 ${Math.round(this.progress.targetMinutes / 60)} 小时，本期还没有任务 —— 去「AI 规划」拆一份，进度从 0 开始。`
    }
    return ''
  }

  /**
   * 近 7 天柱状图的横轴标签：柱子是"6 天前 → 今天"的滚动窗口，
   * 原来写死 ['一'…'日']，除非今天恰好是周日，否则"星期一"下面站的是星期三的数据。
   */
  private weekDateLabels(): string[] {
    const out: string[] = []
    const base = TimeUtils.dayStart(Date.now())
    for (let day = 6; day >= 0; day--) {
      out.push(TimeUtils.formatMonthDay(base - day * 24 * 3600 * 1000))
    }
    return out
  }

  /** 倒计时主数值：未设置或已过期都显示「—」，不再恒显示 0 天 */
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
    return TimeUtils.daysUntil(g.targetDate, Date.now()) > 0 ? '天后开考' : '已过期'
  }

  /** 倒计时下方的一句说明（原来无论有没有日期都写"还有 N 天"） */
  private examHint(): string {
    const g = AppStore.getInstance().getGoal()
    if (g.targetDate <= 0) {
      return '还没有设置考试日期，去「我的 → 长期计划与目标」设置后倒计时才准确'
    }
    if (TimeUtils.daysUntil(g.targetDate, Date.now()) <= 0) {
      return '考试日期已经过去，去「我的 → 长期计划与目标」更新'
    }
    return `距离 ${this.examType} 还有 ${this.examDays} 天，按节奏稳步推进`
  }

  /** 有会话在跑（含被返回键留在后台的）时，首页给出继续入口 */  private resumeFocus(): void {
    router.pushUrl({ url: 'pages/Focus' })
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.TEXT_PRIMARY)
      .width('100%')
      .margin({ bottom: 12 })
  }

  /** 勾选 / 取消勾选：同时改写任务状态与统计口径 */
  private async toggleTask(id: string): Promise<void> {
    await AppStore.getInstance().toggleTaskDone(id)
    this.refresh()
  }

  /** 未完成任务的一行：前面带方框，打钩即完成并同步统计数据 */
  @Builder
  pendingRow(t: Task) {
    Row() {
      // 方框勾选
      Stack() {
        Column()
          .width(20)
          .height(20)
          .backgroundColor(t.done ? Colors.PRIMARY : Color.Transparent)
          .border({ width: 1.5, color: t.done ? Colors.PRIMARY : Colors.TEXT_TERTIARY })
          .borderRadius(6)
        if (t.done) {
          Text('✓')
            .fontSize(13)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
      }
      .onClick(() => {
        this.toggleTask(t.id)
      })

      Column() {
        Text(t.title)
          .fontSize(14)
          .fontColor(t.done ? Colors.TEXT_TERTIARY : Colors.TEXT_PRIMARY)
          .decoration({ type: t.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${t.subject.length > 0 ? t.subject : '未分类'} · 预计 ${t.estimatedDuration} 分钟`)
          .fontSize(11)
          .fontColor(Colors.TEXT_TERTIARY)
          .margin({ top: 3 })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
      .onClick(() => {
        this.toggleTask(t.id)
      })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: Spacing.LG }) {
        // 顶部：问候 + 动态日历 + 头像
        Row() {
          Column() {
            Text(`${this.greeting}，${this.displayName()}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
            Text('今天也一起稳稳推进吧')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 6 })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 右上角头像：点击即可更换
          Column() {
            UserAvatar({ avatar: this.avatar, diameter: 48, bg: Colors.PRIMARY_SOFT })
          }
          .margin({ left: 12 })
          .onClick(() => {
            this.showAvatarSheet = true
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 专注进行中：返回键留在后台的会话不丢，从这里继续（E4）
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

        // 目标总览（按目标类型 + 目标日期算剩余天数）
        Column() {
          Row() {
            Text('目标总览')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
            Blank()
            if (this.examType.length > 0) {
              Text('调整目标 ›')
                .fontSize(12)
                .fontColor(Colors.PRIMARY_DARK)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/LongTermPlan' })
                })
            }
          }
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
        .dashCard()

        // 目标进度（分母 = 各科目标，主分子 = 实际投入）
        Column() {
          Row() {
            Text('目标进度')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text('按实际投入')
              .fontSize(11)
              .fontColor(Colors.PRIMARY_DARK)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(Colors.PRIMARY_SOFT)
              .borderRadius(9)
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.progress.state === 'NO_PLAN' || this.progress.state === 'NO_TARGET'
            || this.progress.state === 'NO_TASK') {
            // 空态：不显示 0%、更不显示 100% —— 分母不存在时任何百分比都是假的
            Text(this.progressHint())
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .lineHeight(20)
              .width('100%')
            Button('去「长期计划与目标」设置')
              .width('100%')
              .height(42)
              .fontSize(14)
              .fontColor(Colors.TEXT_PRIMARY)
              .backgroundColor(Colors.BG)
              .borderRadius(Radius.MD)
              .margin({ top: 12 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/LongTermPlan' })
              })
          } else {
            Row() {
              Text(this.investedText())
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.TEXT_PRIMARY)
              Blank()
              Text(`${this.progress.investedPercent}%`)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.PRIMARY_DARK)
            }
            .width('100%')
            .margin({ bottom: 10 })

            Progress({ value: this.progress.investedPercent, total: 100, type: ProgressType.Linear })
              .color(Colors.PRIMARY)
              .backgroundColor(Colors.LINE)
              .width('100%')

            Text(this.completedText())
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .width('100%')
              .margin({ top: 10 })

            if (this.progress.overdueMinutes > 0) {
              Text(`已超出目标 ${this.progress.overdueMinutes} 分钟：进度条停在 100%，但真实投入照实显示`)
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
                .lineHeight(18)
                .width('100%')
                .margin({ top: 6 })
            }
            if (this.progress.unassignedTasks > 0) {
              Text(`另有 ${this.progress.unassignedTasks} 个未计入目标的任务，实际投入 ${this.progress.unassignedActualMinutes} 分钟（不计入上面的百分比）`)
                .fontSize(12)
                .fontColor(Colors.TEXT_TERTIARY)
                .lineHeight(18)
                .width('100%')
                .margin({ top: 6 })
            }
            Text('口径：主数值为实际投入（由专注计时自动累计，不需要手动打钩），分母为各科目标时长之和。')
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .lineHeight(16)
              .width('100%')
              .margin({ top: 10 })
          }

          // 点这里展开未完成任务清单（它回答"还有什么要做"，与进度口径无关）
          Row() {
            Text(this.pending.length === 0
              ? '目前没有未完成的任务'
              : (this.showPending
                ? `未完成 ${this.pending.length} 项 · 打钩即完成`
                : `未完成 ${this.pending.length} 项 · 点击查看`))
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
            Blank()
            Text(this.showPending ? '▲' : '▼')
              .fontSize(10)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .width('100%')
          .padding({ top: 10, bottom: 2 })
          .onClick(() => {
            this.showPending = !this.showPending
          })

          if (this.showPending) {
            if (this.pending.length === 0) {
              Text('太好了，目前没有未完成的任务 🎉')
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .width('100%')
                .padding({ top: 12, bottom: 4 })
            } else {
              Column() {
                Divider()
                  .color(Colors.LINE)
                  .margin({ top: 6, bottom: 2 })
                ForEach(this.pending.slice(0, 20), (t: Task) => {
                  this.pendingRow(t)
                }, (t: Task) => t.id)
                if (this.pending.length > 20) {
                  Text(`还有 ${this.pending.length - 20} 项未完成…`)
                    .fontSize(12)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .margin({ top: 8 })
                }
              }
              .width('100%')
            }
          }
        }
        .dashCard()

        // 各科目标进度（科目来自计划的 subjectTargets，不由任务反推）
        Column() {
          this.sectionTitle('各科目标进度')
          if (this.progress.subjects.length === 0) {
            Text('在「长期计划与目标」里填好各科目标时长后，这里会按科目显示进度。')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .lineHeight(20)
              .width('100%')
          } else {
            ForEach(this.progress.subjects, (row: SubjectProgressRow) => {
              Column() {
                Row() {
                  Text(row.subject)
                    .fontSize(14)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Blank()
                  Text(row.targetMinutes > 0
                    ? `${row.actualMinutes} / ${row.targetMinutes} 分钟`
                    : `${row.actualMinutes} 分钟（未设目标）`)
                    .fontSize(13)
                    .fontColor(Colors.PRIMARY_DARK)
                }
                .width('100%')

                Progress({
                  value: row.targetMinutes > 0
                    ? Math.min(100, Math.round(row.actualMinutes / row.targetMinutes * 100)) : 0,
                  total: 100,
                  type: ProgressType.Linear
                })
                  .color(Colors.PRIMARY)
                  .backgroundColor(Colors.LINE)
                  .width('100%')
                  .margin({ top: 8 })

                Text(row.targetMinutes <= 0
                  ? '这一科还没设目标时长，进度无从计算'
                  : (row.totalTasks === 0
                    ? '本期还没有这一科的任务'
                    : `任务 ${row.doneTasks}/${row.totalTasks} 已完成（勾选口径）`))
                  .fontSize(11)
                  .fontColor(Colors.TEXT_TERTIARY)
                  .width('100%')
                  .margin({ top: 6 })

                // 超额时给一句一键操作：把目标上调到真实投入（D6）
                if (row.state === 'OVER') {
                  Button(`把这个目标上调到 ${row.actualMinutes} 分钟`)
                    .height(34)
                    .fontSize(12)
                    .fontColor(Colors.TEXT_PRIMARY)
                    .backgroundColor(Colors.BG)
                    .borderRadius(Radius.MD)
                    .margin({ top: 8 })
                    .onClick(() => {
                      // 必须接住失败：落库失败时界面上的数字已经变了、库里没变，
                      // 「我的 → 长期计划与目标」会显示成"没生效"，静默失败最难排查
                      AppStore.getInstance().raiseSubjectTarget(row.subject, row.actualMinutes)
                        .catch(() => {
                          promptAction.showToast({ message: '目标上调失败，请重试' })
                        })
                    })
                }
              }
              .width('100%')
              .margin({ top: 14 })
              // key 必须带上数值：只用科目名的话，科目没变、只是目标/投入变了时，
              // ArkUI 会按相同 key 复用旧节点 → 数字不重绘（复盘日历踩过同一个坑）
            }, (row: SubjectProgressRow) =>
            `${row.subject}_${row.targetMinutes}_${row.actualMinutes}_${row.doneTasks}_${row.totalTasks}`)
          }
        }
        .dashCard()

        // 长期趋势
        Column() {
          this.sectionTitle('长期趋势')
          Text('近 7 天净专注时长（分钟）')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .margin({ bottom: 10 })
          BarChart({ values: this.weekTrend, labels: this.weekDateLabels() })
            .width('100%')
          Text(`本周累计净专注 ${TimeUtils.formatHMin(this.weekFocus)}`)
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 10 })
            .width('100%')
        }
        .dashCard()

        Blank().height(20)
        }
        .padding(20)
        .width('100%')
      }
      .backgroundColor(Colors.BG)
      .width('100%')
      .height('100%')

      // 头像选择器（右上角头像点击后弹出）
      AvatarPicker({
        show: this.showAvatarSheet,
        onClose: () => {
          this.showAvatarSheet = false
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

@Extend(Column)
function dashCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
  .shadow({ radius: 18, color: Colors.SHADOW, offsetX: 0, offsetY: 6 })
}
