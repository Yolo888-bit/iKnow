import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { LearningGoal } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { SubjectListEditor } from '../components/SubjectList'

/** 目标类型 */
interface GoalType {
  key: string
  emoji: string
  label: string
  /** 该目标的激励标语（离线兜底，AI 可用时会覆盖） */
  slogan: string
  /** 快捷科目建议 */
  subjects: string[]
}

/** 每步的标题与说明（一问一页） */
interface StepMeta {
  title: string
  desc: string
}

/**
 * 目标引导向导（登录后 / 首次设置目标）
 *
 * 一问一页，逐步推进：
 *   ① 目标 → ② 目标日期 → ③ 任务与科目（一块一行、可自行添加）→ 完成页
 * 完成页给出提示「开启我的 iKnow 陪伴之旅」；全程也可一键跳过，之后在
 * 「我的 → 长期计划与目标」里补。
 */
@Entry
@Component
struct GoalSetup {
  /** 0 / 1 / 2 = 三个问题步；3 = 完成页 */
  @State step: number = 0
  @State typeIndex: number = -1
  @State customName: string = ''
  @State targetDate: Date = new Date(Date.now() + 180 * 24 * 3600 * 1000)
  @State subjects: string[] = []
  @State saving: boolean = false
  @State errorMsg: string = ''
  private types: GoalType[] = [
    {
      key: '公务员考试', emoji: '🏛️', label: '公务员考试', slogan: '下一站，上岸',
      subjects: ['行测', '申论', '言语理解', '数量关系', '判断推理', '资料分析']
    },
    {
      key: '研究生考试', emoji: '📚', label: '研究生考试', slogan: '一路生花',
      subjects: ['政治', '英语', '数学', '专业课']
    },
    {
      key: '高考冲刺', emoji: '✏️', label: '高考冲刺', slogan: '星光不负赶路人',
      subjects: ['语文', '数学', '英语', '物理', '化学', '生物']
    },
    {
      key: '期末复习', emoji: '📝', label: '期末复习', slogan: '稳扎稳打，门门过关',
      subjects: ['高等数学', '线性代数', '大学英语', '专业课']
    },
    {
      key: '其他', emoji: '🎯', label: '其他', slogan: '定个目标，稳步推进',
      subjects: []
    }
  ]
  private steps: StepMeta[] = [
    { title: '你的目标是什么？', desc: '选一个，我会按它的节奏帮你安排' },
    { title: '目标日期是哪天？', desc: '用来算倒计时，也会影响每天的安排密度' },
    { title: '这次要攻下哪些科目？', desc: '一块一行，没列出的可以自己添加' }
  ]

  aboutToAppear(): void {
    // 老用户（或改过目标）进来时，把已有目标回填，避免重复选一遍
    const g = AppStore.getInstance().getGoal()
    if (g.examType.length > 0) {
      for (let i = 0; i < this.types.length; i++) {
        if (this.types[i].key === g.examType) {
          this.typeIndex = i
          break
        }
      }
      if (this.typeIndex < 0) {
        // 不在预设里（自定义目标）→ 落到「其他」并带回原名
        this.typeIndex = this.types.length - 1
        this.customName = g.examType
      }
    }
    if (g.targetDate > 0) {
      this.targetDate = new Date(g.targetDate)
    }
    if (g.subjects.length > 0) {
      this.subjects = g.subjects.slice()
    }
  }

  // ---------- 数据 ----------

  private goalLabel(): string {
    if (this.typeIndex < 0) {
      return ''
    }
    const t = this.types[this.typeIndex]
    if (t.key === '其他') {
      return this.customName.trim()
    }
    return t.label
  }

  private daysLeft(): number {
    return TimeUtils.daysUntil(this.targetDate.getTime(), Date.now())
  }

  private dateText(): string {
    const d = this.targetDate
    return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日`
  }

  private suggestions(): string[] {
    return this.typeIndex >= 0 ? this.types[this.typeIndex].subjects : []
  }

  /** 去掉空白行、去重后的科目列表（保存前必须过一遍，否则会存进空字符串） */
  private cleanSubjects(): string[] {
    const out: string[] = []
    for (const raw of this.subjects) {
      const s = raw.trim()
      if (s.length === 0) {
        continue
      }
      if (out.indexOf(s) < 0) {
        out.push(s)
      }
    }
    return out
  }

  // ---------- 步骤 ----------

  private canGoNext(): boolean {
    if (this.step === 0) {
      if (this.typeIndex < 0) {
        return false
      }
      if (this.types[this.typeIndex].key === '其他' && this.customName.trim().length === 0) {
        return false
      }
      return true
    }
    if (this.step === 1) {
      return this.daysLeft() >= 0
    }
    return true
  }

  private next(): void {
    this.errorMsg = ''
    if (!this.canGoNext()) {
      if (this.step === 0) {
        this.errorMsg = this.typeIndex < 0 ? '请选择一个目标类型' : '给这个目标起个名字吧'
      } else if (this.step === 1) {
        this.errorMsg = '目标日期不能早于今天'
      }
      return
    }
    // 第二步完成 → 进入完成页（而不是直接跳走，先给一句提示）
    this.step = this.step >= 2 ? 3 : this.step + 1
  }

  private back(): void {
    this.errorMsg = ''
    if (this.step > 0) {
      this.step -= 1
    }
  }

  private async finish(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true

    const store = AppStore.getInstance()
    const goal = new LearningGoal()
    const old = store.getGoal()
    goal.id = old.id.length > 0 ? old.id : `goal_${Date.now()}`
    const label = this.goalLabel()
    goal.examType = label
    const slogan = this.typeIndex >= 0 ? this.types[this.typeIndex].slogan : ''
    goal.title = slogan.length > 0 ? slogan : label
    goal.targetDate = this.targetDate.getTime()
    goal.subjects = this.cleanSubjects()

    await store.saveGoal(goal)
    await store.markGoalConfigured()
    // 目标变了，AI 标语需要重新生成
    AppStorage.setOrCreate<string>(StorageKey.GOAL_SLOGAN, '')

    this.saving = false
    router.replaceUrl({ url: 'pages/Index' })
  }

  /** 一键跳过：把已经答的内容存下来，标记引导已完成，之后在长期计划里补 */
  private async skip(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const store = AppStore.getInstance()
    if (this.goalLabel().length > 0) {
      // 已经选了目标 → 先存下来，别让用户白填
      const goal = new LearningGoal()
      const old = store.getGoal()
      goal.id = old.id.length > 0 ? old.id : `goal_${Date.now()}`
      goal.examType = this.goalLabel()
      goal.title = goal.examType
      goal.targetDate = this.targetDate.getTime()
      goal.subjects = this.cleanSubjects()
      await store.saveGoal(goal)
      AppStorage.setOrCreate<string>(StorageKey.GOAL_SLOGAN, '')
    }
    await store.markGoalConfigured()
    this.saving = false
    router.replaceUrl({ url: 'pages/Index' })
  }

  // ---------- UI ----------

  @Builder
  progressBar() {
    Column() {
      Row() {
        Text(this.step < 3 ? `第 ${this.step + 1} / 3 步` : '准备完成')
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Text('一键跳过')
          .fontSize(13)
          .fontColor(Colors.PRIMARY_DARK)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick(() => {
            this.skip()
          })
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach([0, 1, 2], (i: number) => {
          Column()
            .layoutWeight(1)
            .height(4)
            .backgroundColor(i <= (this.step > 2 ? 2 : this.step) ? Colors.PRIMARY : Colors.LINE)
            .borderRadius(2)
        }, (i: number) => `seg_${i}`)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ top: 16, bottom: 4 })
  }

  @Builder
  typeCard(t: GoalType, index: number) {
    Row() {
      Text(t.emoji)
        .fontSize(20)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.typeIndex === index ? Colors.CARD : Colors.BG)
        .borderRadius(20)
      Column() {
        Text(t.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(t.slogan)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      if (this.typeIndex === index) {
        Text('✓')
          .fontSize(17)
          .fontColor(Colors.PRIMARY)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.typeIndex === index ? Colors.PRIMARY_SOFT : Colors.BG)
    .borderRadius(Radius.MD)
    .border({ width: this.typeIndex === index ? 1.5 : 0, color: Colors.PRIMARY })
    .onClick(() => {
      this.typeIndex = index
      this.errorMsg = ''
    })
  }

  @Builder
  stepGoal() {
    Column({ space: Spacing.SM }) {
      ForEach(this.types, (t: GoalType, i: number) => {
        this.typeCard(t, i)
      }, (t: GoalType) => t.key)

      if (this.typeIndex >= 0 && this.types[this.typeIndex].key === '其他') {
        TextInput({ placeholder: '给这个目标起个名字（如：雅思 7 分）', text: this.customName })
          .fontSize(15)
          .height(48)
          .margin({ top: 12 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.customName = v
          })
      }
    }
    .width('100%')
  }

  @Builder
  stepDate() {
    Column() {
      Row() {
        Text('目标日期')
          .fontSize(14)
          .fontColor(Colors.TEXT_SECONDARY)
        Blank()
        Text(this.daysLeft() >= 0 ? `还剩 ${this.daysLeft()} 天` : '日期无效')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.daysLeft() >= 0 ? Colors.PRIMARY_DARK : Colors.RED)
      }
      .width('100%')
      .margin({ bottom: 6 })

      Text(this.dateText())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 8 })

      DatePicker({
        start: new Date(2020, 0, 1),
        end: new Date(2035, 11, 31),
        selected: this.targetDate
      })
        .height(170)
        .onDateChange((value: Date) => {
          this.targetDate = value
          this.errorMsg = ''
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  stepSubjects() {
    Column() {
      SubjectListEditor({
        items: this.subjects,
        suggestions: this.suggestions(),
        placeholder: '输入科目 / 任务名称',
        addLabel: '添加一行（新增科目）',
        onChange: (v: string[]) => {
          this.subjects = v
        }
      })
    }
    .width('100%')
  }

  /** 完成页：把刚才答的三件事汇总给用户确认 */
  @Builder
  stepDone() {
    Column({ space: Spacing.MD }) {
      Column() {
        Text('🎉')
          .fontSize(40)
        Text('都设置好了')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .margin({ top: 10 })
        Text('我会按这个目标陪你走完这段备考')
          .fontSize(13)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 6 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Column({ space: 12 }) {
        Row() {
          Text('目标').fontSize(13).fontColor(Colors.TEXT_SECONDARY)
          Blank()
          Text(this.goalLabel().length > 0 ? this.goalLabel() : '未设置')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
        }
        .width('100%')

        Row() {
          Text('目标日期').fontSize(13).fontColor(Colors.TEXT_SECONDARY)
          Blank()
          Text(`${this.dateText()}（还剩 ${this.daysLeft()} 天）`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
        }
        .width('100%')

        Column() {
          Row() {
            Text('科目 / 任务').fontSize(13).fontColor(Colors.TEXT_SECONDARY)
            Blank()
            Text(`${this.cleanSubjects().length} 项`)
              .fontSize(13)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .width('100%')

          if (this.cleanSubjects().length === 0) {
            Text('还没添加，之后可以在「我的 → 长期计划与目标」里补')
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .width('100%')
              .margin({ top: 6 })
          } else {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.cleanSubjects(), (s: string) => {
                Text(s)
                  .fontSize(12)
                  .fontColor(Colors.PRIMARY_DARK)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(Colors.PRIMARY_SOFT)
                  .borderRadius(12)
                  .margin({ right: 8, top: 8 })
              }, (s: string) => `done_${s}`)
            }
            .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Colors.BG)
      .borderRadius(Radius.MD)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  build() {
    Column() {
      this.progressBar()

      Scroll() {
        Column({ space: Spacing.MD }) {
          // 一问一页：标题 + 说明
          Column() {
            Text(this.step < 3 ? this.steps[this.step].title : '')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
            if (this.step < 3) {
              Text(this.steps[this.step].desc)
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 8 })
                .width('100%')
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 6 })

          Column() {
            if (this.step === 0) {
              this.stepGoal()
            } else if (this.step === 1) {
              this.stepDate()
            } else if (this.step === 2) {
              this.stepSubjects()
            } else {
              this.stepDone()
            }
          }
          .width('100%')
          .padding(this.step === 3 ? 20 : 18)
          .backgroundColor(Colors.CARD)
          .borderRadius(Radius.LG)
          .alignItems(HorizontalAlign.Start)
          .shadow({ radius: 18, color: Colors.SHADOW, offsetX: 0, offsetY: 6 })

          if (this.errorMsg.length > 0) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor(Colors.RED)
              .width('100%')
              .padding({ left: 4 })
          }

          Blank().height(12)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      // 底部导航
      Row({ space: 10 }) {
        if (this.step > 0) {
          Button('上一步')
            .layoutWeight(1)
            .height(50)
            .fontSize(16)
            .fontColor(Colors.TEXT_SECONDARY)
            .backgroundColor(Colors.BG_ALT)
            .borderRadius(Radius.LG)
            .enabled(!this.saving)
            .onClick(() => {
              this.back()
            })
        }
        Button(this.step === 3
          ? (this.saving ? '正在开启…' : '开启我的 iKnow 陪伴之旅')
          : '下一步')
          .layoutWeight(this.step > 0 ? 2 : 1)
          .height(50)
          .fontSize(this.step === 3 ? 16 : 16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Colors.PRIMARY_STRONG)
          .borderRadius(Radius.LG)
          .enabled(!this.saving)
          .onClick(() => {
            if (this.step === 3) {
              this.finish()
            } else {
              this.next()
            }
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 22 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
