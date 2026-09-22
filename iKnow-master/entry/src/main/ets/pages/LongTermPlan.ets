import { router, promptAction } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Colors, Radius, Spacing } from '../common/Theme'
import { SubjectListEditor } from '../components/SubjectList'
import { StorageService } from '../services/StorageService'
import { AppStore } from '../store/AppStore'
import { StudyPlan, SubjectTarget } from '../models/StudyPlan'

/**
 * 长期计划与目标 —— **唯一入口**。
 *
 * 单一来源规则（D1）：
 *  - 考试类型 / 考试日期 / **科目清单** 只在「目标」（`LearningGoal`）；
 *  - 长期计划（`StudyPlan`）只存"计划名 + 周期 + 各科目标分钟"，科目键必须取自上面的清单；
 *  - `totalEstimatedMinutes` 是**派生**的合计（= Σ 各科目标），只读展示，不让它成为第二个真值。
 *
 * 进度口径：各科目标进度（现在只展示在复盘页）的分母 = 各科目标之和，分子 = 任务的**实际投入**
 * （由专注计时自动累计）。所以这里填的是"每科计划投多少"，不是"完成了几个任务"。
 */
@Entry
@Component
export struct LongTermPlan {
  // —— 目标（LearningGoal）——
  @State examType: string = ''
  @State dateText: string = ''
  /** 科目清单：**一块一行**，用 `SubjectListEditor` 编辑（与引导向导同一套交互） */
  @State subjects: string[] = []
  // —— 长期计划（StudyPlan）——
  @State title: string = ''
  /** 与 subjects 一一对应的目标时长（小时，字符串便于编辑） */
  @State targetHours: string[] = []
  /** 迁移遗留的"未分配目标"（小时）；> 0 表示旧版只设过总目标、还没分到科目 */
  @State unassignedHours: number = 0
  @State saved: boolean = false
  /** 科目 → 目标分钟（非响应式：只在重建输入框时读） */
  private targetMap: Map<string, number> = new Map()
  /** 已加载的计划对象（保存时复用，保留 createdAt） */
  private loaded: StudyPlan | null = null

  aboutToAppear(): void {
    const g = AppStore.getInstance().getGoal()
    this.examType = g.examType
    this.subjects = g.subjects.slice()
    if (g.targetDate > 0) {
      const d = new Date(g.targetDate)
      this.dateText = `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}`
    }
    // 走 AppStore.loadPlan()：全局**同一个对象**。
    // 之前这里直接读库、别处读内存，两条来源不一致时就会出现
    // "那边改过了、这一页还是旧的"（实测反馈）。
    AppStore.getInstance().loadPlan().then((p: StudyPlan | null) => {
      this.applyPlan(p)
    }).catch(() => {
      // 读不到就是"还没设置过"
      this.syncTargetInputs()
    })
  }

  /** 把计划灌进页面状态；`loaded` 记下对象本身，保存时复用它（不产生第二份真值） */
  private applyPlan(p: StudyPlan | null): void {
    if (p === null) {
      this.syncTargetInputs()
      return
    }
    this.loaded = p
    this.title = p.title
    this.saved = true
    this.targetMap.clear()
    for (const st of p.subjectTargets) {
      if (st.subject.length > 0) {
        this.targetMap.set(st.subject, st.targetMinutes)
      }
    }
    this.unassignedHours = this.minutesToHoursText(StudyPlan.unassignedMinutes(p))
    this.syncTargetInputs()
  }

  private pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`
  }

  private minutesToHoursText(minutes: number): number {
    return Math.round(minutes / 60 * 10) / 10
  }

  /** 小时（字符串）→ 分钟；非法或空返回 0 */
  private hoursToMinutes(text: string): number {
    const h = Number(text.trim())
    if (Number.isNaN(h) || h <= 0) {
      return 0
    }
    return Math.round(h * 60)
  }

  /** 把当前输入框里的值收进 targetMap（改科目清单前必须先收，否则刚改的时长会丢） */
  private flushInputs(): void {
    // targetHours 还没建起来时（首次加载）不要回写：那时数组是空的，
    // 会用 0 把刚从库里读出来的各科目标覆盖掉
    if (this.targetHours.length !== this.subjects.length) {
      return
    }
    for (let i = 0; i < this.subjects.length; i++) {
      this.targetMap.set(this.subjects[i], this.hoursToMinutes(this.targetHours[i]))
    }
  }

  /** 科目清单变化后重建时长输入框：已有目标的科目回填，新科目留空 */
  private syncTargetInputs(): void {
    this.flushInputs()
    const hours: string[] = []
    for (const s of this.subjects) {
      const raw: number | undefined = this.targetMap.get(s)
      const min = raw !== undefined ? raw : 0
      hours.push(min > 0 ? `${this.minutesToHoursText(min)}` : '')
    }
    this.targetHours = hours
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

  /** 科目：去掉空行、去重（保存前必须过一遍，否则会把空行存进库） */
  private cleanSubjects(): string[] {
    const out: string[] = []
    for (const raw of this.subjects) {
      const v = raw.trim()
      if (v.length > 0 && out.indexOf(v) < 0) {
        out.push(v)
      }
    }
    return out
  }

  /** 合计（小时）= 各科目标之和 + 未分配；派生只读，不让用户再填一个总数 */
  private totalHoursText(): string {
    let minutes = 0
    for (const t of this.targetHours) {
      minutes += this.hoursToMinutes(t)
    }
    minutes += Math.round(this.unassignedHours * 60)
    if (minutes <= 0) {
      return '尚未设置'
    }
    return `${Math.round(minutes / 60 * 10) / 10} 小时`
  }

  /**
   * 把"未分配目标"按现有任务的预计时长比例摊到各科（没有任务就平均分）。
   * D4：**不静默分摊** —— 只有用户点了这个按钮才分配；分摊结果不直接保存，留给用户微调。
   */
  private distribute(): void {
    const totalMin = Math.round(this.unassignedHours * 60)
    if (totalMin <= 0 || this.subjects.length === 0) {
      promptAction.showToast({ message: '先在「科目」里填好清单，再分摊' })
      return
    }
    const weight: number[] = []
    let sum = 0
    for (const s of this.subjects) {
      let m = 0
      for (const t of AppStore.getInstance().getTasks()) {
        if (t.subject === s) {
          m += t.estimatedDuration
        }
      }
      weight.push(m)
      sum += m
    }
    const next: string[] = []
    for (let i = 0; i < this.subjects.length; i++) {
      const share = sum > 0 ? totalMin * weight[i] / sum : totalMin / this.subjects.length
      next.push(`${Math.round(share / 60 * 10) / 10}`)
    }
    this.targetHours = next
    this.unassignedHours = 0
    promptAction.showToast({ message: '已按任务比例分摊到各科，可再手动微调后保存' })
  }

  private async save(): Promise<void> {
    const exam = this.examType.trim()
    const target = this.parseDate(this.dateText.trim())
    // 注意：不再判断"目标总时长"——合计已改为由各科目标派生，页面上没有这个输入框了
    if (exam.length === 0 && target === 0 && this.subjects.length === 0
      && this.title.trim().length === 0) {
      promptAction.showToast({ message: '还没有填写内容' })
      return
    }
    this.flushInputs()

    // ① 目标：考试类型 / 日期 / 科目（科目清单是唯一来源）
    const g = AppStore.getInstance().getGoal()
    g.examType = exam
    if (g.title.length === 0 || g.title === '考研上岸') {
      g.title = exam
    }
    g.targetDate = target
    // 保存前再过一遍 cleanSubjects()：去掉空行/重复，避免把脏数据写进"科目唯一来源"
    g.subjects = this.cleanSubjects()
    try {
      await AppStore.getInstance().saveGoal(g)
    } catch (e) {
      promptAction.showToast({ message: '目标保存失败，请重试' })
      return
    }

    // ② 长期计划：名称 + 周期 + 各科目标（合计派生）
    const name = this.title.trim()
    const plan = this.loaded !== null ? this.loaded : StudyPlan.create(name)
    plan.id = StudyPlan.PLAN_SINGLETON_ID
    plan.title = name
    plan.periodEnd = target
    const targets: SubjectTarget[] = []
    for (const s of this.subjects) {
      const raw: number | undefined = this.targetMap.get(s)
      const m = raw !== undefined ? raw : 0
      if (m > 0) {
        targets.push(SubjectTarget.create(s, m))
      }
    }
    // 还没分摊掉的旧总值：如实保留为"未分配"，不丢弃也不硬塞给某个科目
    if (this.unassignedHours > 0) {
      targets.push(SubjectTarget.create('', Math.round(this.unassignedHours * 60)))
    }
    plan.subjectTargets = targets
    StudyPlan.recomputeTotal(plan)
    plan.updatedAt = Date.now()
    try {
      await StorageService.getInstance().saveStudyPlan(plan)
    } catch (e) {
      promptAction.showToast({ message: '长期计划保存失败，请重试' })
      return
    }
    // 让工作台的目标进度立刻用上新分母（不必等下次重启）。
    // 这一段必须有确定的收尾：之前 `refreshAggregates()` 没有 try/catch，
    // 一旦它抛错，后面的提示与返回都不会执行 —— 表现为"点了保存什么都没发生"，最难排查。
    AppStore.getInstance().setPlan(plan)
    try {
      await AppStore.getInstance().refreshAggregates()
      promptAction.showToast({ message: '已保存，倒计时与目标进度会按这个来' })
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Plan', '保存后刷新聚合失败：%{public}s', e.message)
      promptAction.showToast({ message: '已保存，但界面刷新失败，请退出重进' })
    }
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
        Text('目标决定倒计时与规划背景；各科目标决定工作台「目标进度」的分母。两者都只在这里设置。')
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
          // 科目：一块一行（与引导向导共用同一个编辑器组件）
          Text('科目')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
            .margin({ top: 16 })
          SubjectListEditor({
            items: this.subjects,
            placeholder: '例如：高等数学',
            addLabel: '添加一科',
            onChange: (v: string[]) => {
              this.subjects = v
              // 科目一行变化就重建时长输入框（新科目留空，已有目标回填）
              this.syncTargetInputs()
            }
          })
            .margin({ top: 8 })
        }
        .padding(18)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .alignItems(HorizontalAlign.Start)

        // 长期计划
        Column() {
          this.sectionTitle('长期计划', '计划名 + 各科计划投入时长；合计由各科相加得到，不单独填')
          this.field('计划名称', '例如：暑假强化 / 冲刺两个月', this.title, (v: string) => {
            this.title = v
          })

          if (this.subjects.length > 0) {
            Text('各科目标时长（小时）')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .width('100%')
              .margin({ top: 16 })
            ForEach(this.subjects, (s: string, i: number) => {
              Row() {
                Text(s)
                  .fontSize(14)
                  .fontColor(Colors.TEXT_PRIMARY)
                  .layoutWeight(1)
                TextInput({ placeholder: '小时，如 1.5', text: this.targetHours[i] })
                  .fontSize(15)
                  .height(42)
                  .width(110)
                  .backgroundColor(Colors.BG)
                  .borderRadius(Radius.MD)
                  .onChange((v: string) => {
                    // 必须换新数组：同引用 ArkUI 不重绘
                    const next = this.targetHours.slice()
                    next[i] = v
                    this.targetHours = next
                  })
              }
              .width('100%')
              .margin({ top: 8 })
            }, (s: string, i: number) => `${s}_${i}`)

            Row() {
              Text('合计')
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
              Blank()
              Text(this.totalHoursText())
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.TEXT_PRIMARY)
            }
            .width('100%')
            .margin({ top: 14 })
          } else {
            Text('先在上面「科目」里填好清单，这里就会出现每科的目标时长。')
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .lineHeight(18)
              .width('100%')
              .margin({ top: 12 })
          }

          // 旧数据迁移：只设过总目标、还没分到科目
          if (this.unassignedHours > 0) {
            Column() {
              Text(`旧版设置的总目标 ${this.unassignedHours} 小时还没分到科目，目标进度暂时无法计算。`)
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
                .lineHeight(18)
                .width('100%')
              Button('按现有任务比例分摊到各科')
                .width('100%')
                .height(40)
                .fontSize(14)
                .fontColor(Colors.TEXT_PRIMARY)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .margin({ top: 10 })
                .onClick(() => {
                  this.distribute()
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(Colors.PRIMARY_SOFT)
            .borderRadius(Radius.MD)
            .margin({ top: 14 })
            .alignItems(HorizontalAlign.Start)
          }
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
          .backgroundColor(Colors.PRIMARY_STRONG)
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
