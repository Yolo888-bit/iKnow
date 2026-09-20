import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { TimeUtils } from '../utils/TimeUtils'
import { BarChart } from '../components/BarChart'
import { SubjectProgress } from '../models/Dashboard'
import { Task } from '../models/Task'
import { TaskStatus } from '../models/Enums'
import { UserAvatar } from '../components/UserAvatar'
import { AvatarPicker } from '../components/AvatarPicker'
import { SimWorkbench } from '../components/SimWorkbench'

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
  @State subjects: SubjectProgress[] = []
  @State examType: string = ''
  @State targetDateText: string = ''
  @State greeting: string = ''
  @State showAvatarSheet: boolean = false
  /** 总体进度：全部任务（含历史） */
  @State allDone: number = 0
  @State allTotal: number = 0
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
    this.subjects = d.subjectProgress

    const goal = store.getGoal()
    this.examType = goal.examType
    if (goal.targetDate > 0) {
      const gd = new Date(goal.targetDate)
      this.targetDateText = `${gd.getFullYear()} 年 ${gd.getMonth() + 1} 月 ${gd.getDate()} 日`
    } else {
      this.targetDateText = ''
    }

    // 总体进度 = 全部任务（含历史），不只看今日
    const all: Task[] = store.getTasks()
    let done = 0
    const pend: Task[] = []
    for (const t of all) {
      if (t.done || t.status === TaskStatus.DONE) {
        done += 1
      } else {
        pend.push(t)
      }
    }
    // 未完成：最近的排在前面
    pend.sort((a: Task, b: Task) => b.createdAt - a.createdAt)
    this.allTotal = all.length
    this.allDone = done
    this.pending = pend
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

  private percent(): string {
    if (this.allTotal === 0) {
      return '—'
    }
    return `${Math.round(this.allDone / this.allTotal * 100)}%`
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

        // 总体进度（全部任务，含历史）
        Column() {
          Row() {
            Text('总体进度')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text('全部任务')
              .fontSize(11)
              .fontColor(Colors.PRIMARY_DARK)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(Colors.PRIMARY_SOFT)
              .borderRadius(9)
          }
          .width('100%')
          .margin({ bottom: 12 })

          Row() {
            Text(`${this.allDone} / ${this.allTotal}`)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text(this.percent())
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.PRIMARY_DARK)
          }
          .width('100%')
          .margin({ bottom: 10 })

          Progress({
            value: this.allDone,
            total: Math.max(1, this.allTotal),
            type: ProgressType.Linear
          })
            .color(Colors.PRIMARY)
            .backgroundColor(Colors.LINE)
            .width('100%')

          // 点这里展开未完成任务清单
          Row() {
            Text(this.allTotal === 0
              ? '还没有任何任务，去「AI 规划」拆一份吧'
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

        // 科目进度
        Column() {
          this.sectionTitle('科目进度（近 30 天）')
          if (this.subjects.length === 0) {
            Text('开始学习后，这里会显示各学科的完成进度')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .width('100%')
          } else {
            ForEach(this.subjects, (sp: SubjectProgress) => {
              Column() {
                Row() {
                  Text(sp.subject)
                    .fontSize(14)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Blank()
                  Text(`${sp.percent}%`)
                    .fontSize(14)
                    .fontColor(Colors.PRIMARY_DARK)
                }
                .width('100%')
                Progress({ value: sp.percent, total: 100, type: ProgressType.Linear })
                  .color(Colors.PRIMARY)
                  .backgroundColor(Colors.LINE)
                  .width('100%')
                  .margin({ top: 8 })
              }
              .width('100%')
              .margin({ top: 14 })
            }, (sp: SubjectProgress) => sp.subject)
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

        // 模拟状态（原在「设备连接」页的模拟工作台，统一移到这里）
        SimWorkbench()

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
