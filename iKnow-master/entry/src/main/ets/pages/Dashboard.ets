import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { TimeUtils } from '../utils/TimeUtils'
import { BarChart } from '../components/BarChart'
import { SubjectTaskProgress } from '../models/Dashboard'
import { Task } from '../models/Task'
import { TaskStatus } from '../models/Enums'
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
  /** 总体进度：全部任务（含历史） */
  @State allDone: number = 0
  @State allTotal: number = 0
  @State pending: Task[] = []
  @State showPending: boolean = false
  /** 任务进度：引导里填的每个科目一条（完成一次涨一点） */
  @State taskProgress: SubjectTaskProgress[] = []

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

    const goal = store.getGoal()
    this.examType = goal.examType
    if (goal.targetDate > 0) {
      const gd = new Date(goal.targetDate)
      this.targetDateText = `${gd.getFullYear()} 年 ${gd.getMonth() + 1} 月 ${gd.getDate()} 日`
    } else {
      this.targetDateText = ''
    }

    // 总体进度 = 「AI 规划中的任务」+「专注里实际用过的任务」，按 id 去重累加。
    // 只统计这两个来源，不把无关任务算进来，口径与用户预期一致。
    const merged: Task[] = []
    const seen: string[] = []
    const planned: Task[] = store.getCurrentPlan()
    for (const t of planned) {
      if (seen.indexOf(t.id) < 0) {
        seen.push(t.id)
        merged.push(t)
      }
    }
    const fromFocus: Task[] = store.getTasks()
    for (const t of fromFocus) {
      if (seen.indexOf(t.id) < 0) {
        seen.push(t.id)
        merged.push(t)
      }
    }
    let done = 0
    const pend: Task[] = []
    for (const t of merged) {
      if (t.done || t.status === TaskStatus.DONE) {
        done += 1
      } else {
        pend.push(t)
      }
    }
    // 未完成：最近的排在前面
    pend.sort((a: Task, b: Task) => b.createdAt - a.createdAt)
    this.allTotal = merged.length
    this.allDone = done
    this.pending = pend
    this.taskProgress = this.buildTaskProgress(merged)
  }

  /**
   * 任务进度：**引导里填的每个科目 = 一条任务进度**，完成一次涨一点。
   *
   * 增量当前写死 70%~90%（用户还没定好幅度），按科目名做确定性散列，
   * 保证同一科目每次算出来一样、不会渲染一次跳一个数；累计超过 100% 夹到 100。
   * 之后要改成真实幅度，只动 `progressStep()` 一处即可。
   */
  private buildTaskProgress(tasks: Task[]): SubjectTaskProgress[] {
    const subjects: string[] = []
    // ① 主口径：引导 / 长期计划里填的科目
    for (const s of AppStore.getInstance().getGoal().subjects) {
      const v = s.trim()
      if (v.length > 0 && subjects.indexOf(v) < 0) {
        subjects.push(v)
      }
    }
    // ② 任务里实际出现过的科目也补进来，避免科目写法对不上时整块空着
    for (const t of tasks) {
      const v = t.subject.trim()
      if (v.length > 0 && subjects.indexOf(v) < 0) {
        subjects.push(v)
      }
    }

    const out: SubjectTaskProgress[] = []
    for (const s of subjects) {
      let done = 0
      for (const t of tasks) {
        const hay = `${t.subject} ${t.title}`
        if (hay.indexOf(s) >= 0 && (t.done || t.status === TaskStatus.DONE)) {
          done += 1
        }
      }
      const item = new SubjectTaskProgress()
      item.subject = s
      item.doneCount = done
      const p = Math.round(done * progressStep(s) * 100)
      item.percent = p > 100 ? 100 : p
      out.push(item)
    }
    out.sort((a: SubjectTaskProgress, b: SubjectTaskProgress) => b.percent - a.percent)
    return out
  }

  /** 有会话在跑（含被返回键留在后台的）时，首页给出继续入口 */
  private resumeFocus(): void {
    router.pushUrl({ url: 'pages/Focus' })
  }

  /** 剩余天数（大字）：没有目标日期时如实显示「—」，不编造倒计时 */
  private examDaysText(): string {
    return this.targetDateText.length > 0 ? `${this.examDays}` : '—'
  }

  private examDaysSub(): string {
    return this.targetDateText.length > 0 ? '天后开考' : '未设日期'
  }

  /** 目标总览脚下那行提示：没填日期时给不同的话，填了就给倒计时 */
  private examHint(): string {
    if (this.examType.length === 0) {
      return '在「我的 → 长期计划与目标」里填写目标与日期，倒计时才会准确'
    }
    if (this.targetDateText.length === 0) {
      return '还没填目标日期，补上之后倒计时才准'
    }
    return `距离 ${this.examType} 还有 ${this.examDays} 天，按节奏稳步推进`
  }

  /** 长期趋势横轴标签：近 7 天的「月/日」 */
  private weekDateLabels(): string[] {
    const out: string[] = []
    const base = TimeUtils.dayStart(Date.now())
    for (let i = 6; i >= 0; i--) {
      const d = new Date(base - i * 24 * 3600 * 1000)
      out.push(`${d.getMonth() + 1}/${d.getDate()}`)
    }
    return out
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
            Text('规划 + 专注')
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

        // 任务进度：引导里填的每个科目一条，完成一次涨一点
        Column() {
          Row() {
            Text('任务进度')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            if (this.taskProgress.length > 0) {
              Text(`${this.taskProgress.length} 项`)
                .fontSize(12)
                .fontColor(Colors.TEXT_TERTIARY)
            }
          }
          .width('100%')
          .margin({ bottom: 4 })

          Text('你设置的目标科目，完成一次就往前走一点')
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .margin({ bottom: 6 })

          if (this.taskProgress.length === 0) {
            Text('还没有科目。可以在「我的 → 长期计划与目标」里添加')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .width('100%')
              .margin({ top: 6 })
          } else {
            ForEach(this.taskProgress, (it: SubjectTaskProgress) => {
              Column() {
                Row() {
                  Text(it.subject)
                    .fontSize(14)
                    .fontColor(Colors.TEXT_PRIMARY)
                  if (it.doneCount > 0) {
                    Text(`已完成 ${it.doneCount} 次`)
                      .fontSize(11)
                      .fontColor(Colors.TEXT_TERTIARY)
                      .margin({ left: 8 })
                  }
                  Blank()
                  Text(`${it.percent}%`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(it.percent >= 100 ? Colors.PRIMARY_DARK : Colors.TEXT_PRIMARY)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Progress({ value: it.percent, total: 100, type: ProgressType.Linear })
                  .color(it.percent >= 100 ? Colors.PRIMARY : Colors.PRIMARY_DARK)
                  .backgroundColor(Colors.LINE)
                  .width('100%')
                  .margin({ top: 8 })
              }
              .width('100%')
              .margin({ top: 14 })
            }, (it: SubjectTaskProgress) => `${it.subject}_${it.doneCount}_${it.percent}`)
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

/**
 * 每完成一次的进度增量：**先写死 70%~90%**（用户还没定幅度）。
 * 按科目名做确定性散列 —— 不用随机数，否则每次渲染进度都会乱跳。
 */
function progressStep(subject: string): number {
  let h = 0
  for (let i = 0; i < subject.length; i++) {
    h = (h * 31 + subject.charCodeAt(i)) % 1000
  }
  return 0.70 + (h % 21) / 100
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
