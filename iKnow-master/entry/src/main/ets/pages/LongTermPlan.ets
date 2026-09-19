import { router, promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageService } from '../services/StorageService'
import { AppStore } from '../store/AppStore'
import { StudyPlan } from '../models/StudyPlan'

/**
 * 长期计划与目标 —— **合并后的唯一入口**。
 *
 * 为什么合并：原先"目标"（考试类型 / 日期 / 科目）只能在首次引导页里改，
 * 入口藏在「我的 → 重新设置称呼与目标」，而"长期计划"（计划名称 / 目标总时长）
 * 是另一个页面、只有 3 个字段 —— 两者语义高度重叠却各写各的，
 * 用户既找不到，也分不清该改哪个。
 *
 * 现在一个页面同时配置：
 *  - 目标（LearningGoal）：目标考试 / 目标日期 / 科目 —— 用于倒计时与规划背景；
 *  - 长期计划（StudyPlan）  ：计划名称 / 目标总时长 —— 用于长期进度参照。
 * 存储沿用既有 `learning_goal` 与 `study_plan` 两张表，不新增表、不做迁移。
 */
@Entry
@Component
export struct LongTermPlan {
  // —— 目标（LearningGoal）——
  @State examType: string = ''
  @State dateText: string = ''
  @State subjectsText: string = ''
  // —— 长期计划（StudyPlan）——
  @State title: string = ''
  @State totalHours: string = ''
  @State saved: boolean = false

  aboutToAppear(): void {
    const g = AppStore.getInstance().getGoal()
    this.examType = g.examType
    this.subjectsText = g.subjects.join('、')
    if (g.targetDate > 0) {
      const d = new Date(g.targetDate)
      this.dateText = `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}`
    }
    StorageService.getInstance().loadStudyPlan().then((p: StudyPlan | null) => {
      if (p !== null) {
        this.title = p.title
        this.totalHours = p.totalEstimatedMinutes > 0 ? `${Math.round(p.totalEstimatedMinutes / 60)}` : ''
        this.saved = true
      }
    }).catch(() => {
      // 读不到就是"还没设置过"
    })
  }

  private pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`
  }

  /** 解析 YYYY-MM-DD；不合法或留空返回 0（= 不设置） */
  private parseDate(text: string): number {
    const parts = text.split('-')
    if (parts.length !== 3) {
      return 0
    }
    const y = Number(parts[0])
    const m = Number(parts[1])
    const d = Number(parts[2])
    if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d) || y < 2000 || m < 1 || m > 12 || d < 1 || d > 31) {
      return 0
    }
    return new Date(y, m - 1, d, 0, 0, 0, 0).getTime()
  }

  /** 科目：顿号 / 逗号 / 分号 / 空格 都当分隔符，去空去重 */
  private parseSubjects(text: string): string[] {
    const normalized = text
      .split('，').join('、')
      .split(',').join('、')
      .split('；').join('、')
      .split(';').join('、')
    const parts = normalized.split('、')
    const out: string[] = []
    for (const raw of parts) {
      const item = raw.trim()
      if (item.length === 0) {
        continue
      }
      // 空格也当分隔符（"高数 英语"）
      for (const s of item.split(' ')) {
        const v = s.trim()
        if (v.length > 0 && !out.includes(v)) {
          out.push(v)
        }
      }
    }
    return out
  }

  private async save(): Promise<void> {
    const exam = this.examType.trim()
    const target = this.parseDate(this.dateText.trim())
    if (exam.length === 0 && target === 0 && this.subjectsText.trim().length === 0
      && this.title.trim().length === 0 && this.totalHours.trim().length === 0) {
      promptAction.showToast({ message: '还没有填写内容' })
      return
    }

    // ① 目标：考试类型 / 日期 / 科目
    const g = AppStore.getInstance().getGoal()
    g.examType = exam
    if (g.title.length === 0 || g.title === '考研上岸') {
      g.title = exam
    }
    g.targetDate = target
    g.subjects = this.parseSubjects(this.subjectsText)
    try {
      await AppStore.getInstance().saveGoal(g)
    } catch (e) {
      promptAction.showToast({ message: '目标保存失败，请重试' })
      return
    }

    // ② 长期计划：名称 / 目标总时长
    const name = this.title.trim()
    if (name.length > 0) {
      const hours = Number(this.totalHours.trim())
      const minutes = Number.isNaN(hours) || hours <= 0 ? 0 : Math.round(hours * 60)
      const plan = StudyPlan.create(name, exam)
      plan.totalEstimatedMinutes = minutes
      try {
        await StorageService.getInstance().saveStudyPlan(plan)
      } catch (e) {
        promptAction.showToast({ message: '长期计划保存失败，请重试' })
        return
      }
    }
    promptAction.showToast({ message: '已保存，倒计时与规划会按这个来' })
    router.back()
  }

  @Builder
  field(label: string, placeholder: string, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor(Colors.TEXT_SECONDARY)
        .width('100%')
      TextInput({ placeholder: placeholder, text: value })
        .fontSize(15)
        .height(46)
        .backgroundColor(Colors.BG)
        .borderRadius(Radius.MD)
        .margin({ top: 6 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 16 })
  }

  @Builder
  sectionTitle(text: string, desc: string) {
    Column() {
      Text(text)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')
      Text(desc)
        .fontSize(11)
        .fontColor(Colors.TEXT_TERTIARY)
        .lineHeight(16)
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        Text('长期计划与目标')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
        Text('目标决定倒计时与规划背景；长期计划描述"这一段时间要做成什么"。两者都只在这里设置。')
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .lineHeight(18)
          .width('100%')

        // 目标
        Column() {
          this.sectionTitle('目标', '用于首页/工作台的考试倒计时，以及 AI 规划时的背景信息')
          this.field('目标考试', '例如：考研 / 期末 / 六级', this.examType, (v: string) => {
            this.examType = v
          })
          this.field('考试日期', '例如：2026-12-20（可留空）', this.dateText, (v: string) => {
            this.dateText = v
          })
          this.field('科目', '例如：高等数学、英语、政治（顿号分隔，可留空）', this.subjectsText, (v: string) => {
            this.subjectsText = v
          })
        }
        .padding(18)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .alignItems(HorizontalAlign.Start)

        // 长期计划
        Column() {
          this.sectionTitle('长期计划', '这一段时间的总目标，用于长期进度参照；和每天的今日计划分开')
          this.field('计划名称', '例如：暑假强化 / 冲刺两个月', this.title, (v: string) => {
            this.title = v
          })
          this.field('目标总时长（小时）', '例如：120（可留空）', this.totalHours, (v: string) => {
            this.totalHours = v
          })
        }
        .padding(18)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .alignItems(HorizontalAlign.Start)

        Button(this.saved ? '更新' : '保存')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor(Colors.PRIMARY)
          .borderRadius(Radius.LG)
          .margin({ top: 8 })
          .onClick(() => {
            this.save()
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
