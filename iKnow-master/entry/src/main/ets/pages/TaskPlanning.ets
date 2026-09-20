import { router, promptAction } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Colors, Radius } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { AIService } from '../services/AIService'
import { FocusController } from '../services/FocusController'
import { PlanningInput, PlanningDialogInput } from '../services/ai/PlanningService'
import { PlanTask } from '../models/StudyPlan'
import { AIMessage } from '../models/AIMessage'
import { Task } from '../models/Task'
import { MessageRole } from '../models/Enums'
import { IdUtils } from '../utils/IdUtils'
import { Metrics } from '../services/Metrics'
import { StorageService } from '../services/StorageService'
import { StudyPlan } from '../models/StudyPlan'
import { TimeUtils } from '../utils/TimeUtils'
import { AIFirstDisclaimer } from '../components/AIFirstDisclaimer'
import { UserAvatar } from '../components/UserAvatar'

/**
 * 任务规划 —— 微信式一问一答的对话规划
 *
 *  顶部：iKnow 品牌 + 居中「任务规划 / 在线」+ 右上角用户头像
 *  消息：AI 在左（深色 AI 圆头像 + 暖米色气泡），用户在右（浅绿气泡 + 用户头像）
 *  下方：居中「待确认任务」+ 圆圈列表（可点选、点文字可编辑）
 *  底部：✓ 进入 X 分钟专注学习 + 绿色大按钮 + 提示文案
 *
 *  - 接入 AI：追问走 task_dialog 场景，出计划走 task_plan 场景，时间分析由 AI 生成
 *    （硬规则 §1：动态 AI 文案不写死在页面）。
 */
@Entry
@Component
export struct TaskPlanning {
  @State messages: AIMessage[] = []
  /** 用户已发言轮数（兜底用：聊太多轮还没出计划就直接生成） */
  @State turns: number = 0
  /** 出计划后是否仍显示输入框（用户点「继续调整」时置 true） */
  @State showComposer: boolean = false
  @State tasks: Task[] = []
  /** 已点击确认（圆圈变实心）的任务 id */
  @State confirmedIds: string[] = []
  @State thinking: boolean = false
  /** 流式输出中：AI 回复逐段写入 streamingText，流结束后再落到消息列表 */
  @State streaming: boolean = false
  @State streamingText: string = ''
  @State inputValue: string = ''
  /** 网关是否就绪（未配置 Key 时如实显示本地模板，不假装在线） */
  @State gatewayReady: boolean = false
  /** 正在编辑的任务 id（空串表示未编辑） */
  @State editId: string = ''
  @State draftTitle: string = ''
  @State draftSubject: string = ''
  @State draftMinutes: number = 30
  @StorageProp(StorageKey.USER_AVATAR) avatar: string = '🧑‍🎓'
  private scroller: Scroller = new Scroller()
  /** 传给 AI 的历史对话，按 [user, ai, user, ai, ...] 交替存放 */
  private history: string[] = []
  /** 用户说过的原话，兜底生成计划时拼成目标 */
  private userTexts: string[] = []
  /** 长期计划摘要（来自 study_plan；作为规划的背景参考，随上下文注入提示词） */
  private longPlanText: string = ''

  aboutToAppear(): void {
    // 徽标要如实反映"这次到底是走大模型还是本地模板"，不能无条件亮绿灯
    this.gatewayReady = AIService.getInstance().isGatewayReady()
    this.pushAI(AIService.getInstance().planningIntro())
    // 长期计划：在「复盘 → 长期计划」里设置，这里读出来当背景参考
    StorageService.getInstance().loadStudyPlan().then((p: StudyPlan | null) => {
      if (p === null || p.title.length === 0) {
        return
      }
      const hours = p.totalEstimatedMinutes > 0 ? ` · 目标 ${Math.round(p.totalEstimatedMinutes / 60)} 小时` : ''
      const exam = p.examType.length > 0 ? ` · ${p.examType}` : ''
      this.longPlanText = `${p.title}${exam}${hours}`
      this.pushAI(`你的长期计划是「${this.longPlanText}」，我会按这个来安排。`)
    }).catch(() => {
      // 没有长期计划就正常聊，不硬提
    })
  }

  // ---------- 消息 ----------
  private pushAI(content: string): void {
    const m = new AIMessage()
    m.id = IdUtils.uuid()
    m.role = MessageRole.AI
    m.content = content
    m.timestamp = Date.now()
    this.messages.push(m)
    this.scrollToBottom()
  }

  private pushUser(content: string): void {
    const m = new AIMessage()
    m.id = IdUtils.uuid()
    m.role = MessageRole.USER
    m.content = content
    m.timestamp = Date.now()
    this.messages.push(m)
    this.scrollToBottom()
  }

  /** 新消息后滚到底部，保持「聊天跟手」 */
  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 80)
  }

  // ---------- 对话流程（AI 驱动，不再固定轮数）----------

  /**
   * 每次发言都带完整历史调用 task_dialog：
   *  - 模型正常聊天、按需追问；
   *  - 一旦判断信息够了，直接返回 done=true + tasks → 立刻出计划；
   *  - 聊满 4 轮仍未给计划 → 兜底走 task_plan 直接拆任务。
   */
  private async send(): Promise<void> {
    const text = this.inputValue.trim()
    if (text.length === 0 || this.thinking) {
      return
    }
    this.inputValue = ''
    this.pushUser(text)
    this.userTexts.push(text)
    this.turns += 1

    this.thinking = true
    this.streaming = true
    this.streamingText = ''
    const input: PlanningDialogInput = {
      step: this.turns,
      userInput: text,
      history: this.history,
      planningContext: this.buildPlanningContext()
    }
    // 流式：reply 逐段上屏；结构化结果（done / tasks）等流结束后一起拿到
    const r = await AIService.getInstance().dialogStream(input, (delta: string) => {
      this.streamingText += delta
      this.scrollToBottom()
    })
    this.thinking = false
    this.streaming = false

    const streamed: string = this.streamingText
    this.streamingText = ''
    const reply: string = r.reply.length > 0
      ? r.reply
      : (streamed.length > 0 ? streamed : AIService.getInstance().planningHold())
    this.pushAI(reply)
    this.history.push(text)
    this.history.push(reply)

    // 模型判断信息足够：reply 里已含时间安排建议，直接落到待确认列表
    const got: PlanTask[] | undefined = r.tasks
    if (r.done && got !== undefined && got.length > 0) {
      this.applyPlan(got)
      return
    }
    // 兜底：已经追问过一轮（第 2 轮）还没出计划，就按已收集的信息直接生成。
    // 原来是 4 轮，用户要连答 4 个问题才看到计划 —— 提示词已改为「最多追问 1 轮」，这里对齐。
    if (this.turns >= 2) {
      await this.generatePlan()
    }
  }

  /** 标题归一化：去空格与常见标点后比较，避免同一任务被当成两条 */
  private titleKey(s: string): string {
    const skip: string = ' 　，。、；：,.;()（）【】[]'
    let out = ''
    for (let i = 0; i < s.length; i++) {
      const c = s.charAt(i)
      if (skip.indexOf(c) < 0) {
        out += c
      }
    }
    return out
  }

  /**
   * 把 AI 给出的任务**追加**到「待确认任务」列表，而不是整体替换。
   *  - 已有任务原样保留（含用户手动调过的时长、已勾选状态）；
   *  - 标题重复的视为同一条，跳过 —— 多轮对话不会把清单越聊越乱；
   *  - 有新增才收起输入框，方便用户接着补充需求。
   */
  private applyPlan(list: PlanTask[]): void {
    const next: Task[] = this.tasks.slice()
    const keys: string[] = []
    for (const t of next) {
      keys.push(this.titleKey(t.title))
    }
    let added = 0
    for (const p of list) {
      const k = this.titleKey(p.title)
      if (keys.indexOf(k) >= 0) {
        continue
      }
      const t = this.toTask(p)
      t.sortOrder = next.length
      keys.push(k)
      next.push(t)
      added += 1
    }
    if (next.length === 0) {
      return
    }
    this.tasks = next
    if (added > 0) {
      this.showComposer = false
    }
  }

  private composeGoal(): string {
    return this.userTexts.join('；')
  }

  /** 最近未完成的计划任务（最多 3 条），供规划参考 */
  private unfinishedTasks(): string[] {
    const out: string[] = []
    for (const t of AppStore.getInstance().getTasks()) {
      if (!t.done && out.length < 3) {
        out.push(t.title)
      }
    }
    return out
  }

  /**
   * 组装「已知用户背景」注入提示词。
   * 没数据的项一律不写（宁可少，也不给模型编造的依据）；一个都没有时返回空串。
   */
  private buildPlanningContext(): string {
    const store = AppStore.getInstance()
    const goal = store.getGoal()
    const profile = store.getProfile()
    const lines: string[] = []

    // 长期计划：让规划有"这一段时间要做成什么"的背景，而不是只看今天
    if (this.longPlanText.length > 0) {
      lines.push(`- 长期计划：${this.longPlanText}`)
    }
    if (goal.examType.length > 0) {
      const tail = goal.targetDate > 0 ? `，距考试 ${TimeUtils.daysUntil(goal.targetDate, Date.now())} 天` : ''
      lines.push(`- 备考目标：${goal.examType}${tail}`)
    }
    if (goal.subjects.length > 0) {
      lines.push(`- 学科：${goal.subjects.join('、')}`)
    }
    if (profile.sampleCount >= Metrics.MIN_SAMPLES) {
      if (profile.bestFocusTime.length > 0) {
        lines.push(`- 最近黄金时段：${profile.bestFocusTime}`)
      }
      lines.push(`- 平均单次专注：${profile.averageFocusDuration} 分钟；建议单段不超过 ${profile.focusThreshold} 分钟`)
    }
    const unfinished = this.unfinishedTasks()
    if (unfinished.length > 0) {
      lines.push(`- 最近未完成任务：${unfinished.join('、')}`)
    }
    const minutes = TimeUtils.parseDurationMinutes(this.userTexts.join(' '))
    if (minutes > 0) {
      lines.push(`- 用户可用时间：${minutes} 分钟`)
    }
    return lines.join('\n')
  }

  /** 兜底路径：直接按已收集的目标生成结构化任务（task_plan 场景） */
  private async generatePlan(): Promise<void> {
    this.thinking = true
    const minutes = TimeUtils.parseDurationMinutes(this.userTexts.join(' '))
    const input: PlanningInput = {
      goal: this.composeGoal(),
      planningContext: this.buildPlanningContext()
    }
    if (minutes > 0) {
      input.availableMinutes = minutes
    }
    const subjects = AppStore.getInstance().getGoal().subjects
    if (subjects.length > 0) {
      input.subjects = subjects
    }
    const result = await AIService.getInstance().planByScene(input)
    this.thinking = false

    if (result.tasks.length === 0) {
      this.pushAI(AIService.getInstance().planningHold())
      return
    }
    if (result.summary.length > 0) {
      this.pushAI(result.summary)
    }
    this.applyPlan(result.tasks)
  }

  private toTask(p: PlanTask): Task {
    const t = new Task()
    t.id = p.id.length > 0 ? p.id : IdUtils.uuid()
    t.title = p.title
    t.subject = p.subject
    t.estimatedDuration = p.estimatedDuration
    t.sortOrder = p.sortOrder
    t.createdAt = Date.now()
    return t
  }

  // ---------- 待确认任务：确认 / 编辑 ----------
  private isConfirmed(id: string): boolean {
    return this.confirmedIds.indexOf(id) >= 0
  }

  private toggleConfirm(id: string): void {
    const next: string[] = []
    let found = false
    for (const x of this.confirmedIds) {
      if (x === id) {
        found = true
      } else {
        next.push(x)
      }
    }
    if (!found) {
      next.push(id)
    }
    this.confirmedIds = next
  }

  private startEdit(t: Task): void {
    this.editId = t.id
    this.draftTitle = t.title
    this.draftSubject = t.subject
    this.draftMinutes = t.estimatedDuration
  }

  private saveEdit(): void {
    const title = this.draftTitle.trim()
    const subject = this.draftSubject.trim()
    const next: Task[] = []
    for (const t of this.tasks) {
      const c = t.copy()
      if (c.id === this.editId) {
        c.title = title.length > 0 ? title : c.title
        c.subject = subject.length > 0 ? subject : c.subject
        c.estimatedDuration = this.draftMinutes
      }
      next.push(c)
    }
    this.tasks = next
    this.editId = ''
  }

  private deleteTask(): void {
    const next: Task[] = []
    for (const t of this.tasks) {
      if (t.id !== this.editId) {
        next.push(t)
      }
    }
    this.tasks = next
    this.editId = ''
  }

  /**
   * 行内微调某项任务的时长（5 分钟步进，夹在 5~180）。
   * AI 给的推荐时长只是起点，用户可随时按自己的节奏改。
   */
  private bumpMinutes(id: string, delta: number): void {
    const next: Task[] = []
    for (const t of this.tasks) {
      const c = t.copy()
      if (c.id === id) {
        let m = c.estimatedDuration + delta
        if (m < 5) {
          m = 5
        }
        if (m > 180) {
          m = 180
        }
        c.estimatedDuration = m
      }
      next.push(c)
    }
    this.tasks = next
  }

  // ---------- 底部：预计时长 / 开始专注 ----------
  private selectedTasks(): Task[] {
    if (this.confirmedIds.length === 0) {
      return this.tasks
    }
    const out: Task[] = []
    for (const t of this.tasks) {
      if (this.isConfirmed(t.id)) {
        out.push(t)
      }
    }
    return out
  }

  private plannedMinutes(): number {
    let sum = 0
    for (const t of this.selectedTasks()) {
      sum += t.estimatedDuration
    }
    return sum
  }

  private async confirmStart(): Promise<void> {
    const selected = this.selectedTasks()
    if (selected.length === 0) {
      promptAction.showToast({ message: '至少保留一个任务' })
      return
    }
    // 上一段会话仍在跑：先落库再载入新计划，避免幽灵会话静默吞掉新计划（E4）
    if (FocusController.getInstance().isRunning()) {
      // 落库失败也必须继续往下走：否则下面三行全被跳过，表现为"点了开始专注没反应"
      // （Focus / FocusBreak 的退出路径已用 try/catch/finally 兜住，这里对齐）
      try {
        await AppStore.getInstance().endSession()
      } catch (e) {
        hilog.error(0x0000, 'iKnow.Planning', '结束上一段会话出错，仍继续载入新计划：%{public}s', e.message)
      }
    }
    AppStore.getInstance().setCurrentPlan(selected)
    // 规划确认即落库：否则「总体进度 / 科目进度」要等第一次专注结束才有数据（恒 0/0）
    try {
      await AppStore.getInstance().persistPlan(selected)
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Planning', '任务落库失败，仍继续开始专注：%{public}s', e.message)
    }
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 1)
    router.pushUrl({ url: 'pages/Focus' })
  }

  /** 跳过规划：不聊天、不生成任务，直接带着已有计划（没有则自由专注）开始 */
  private skipPlanning(): void {
    if (this.thinking) {
      return
    }
    if (FocusController.getInstance().isRunning()) {
      router.pushUrl({ url: 'pages/Focus' })
      return
    }
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 1)
    router.pushUrl({ url: 'pages/Focus' })
  }

  // ---------- 视图 ----------
  @Builder
  header() {
    Row() {
      // 左：品牌（固定占位，保证中间标题真正居中）
      Row() {
        Text('iKnow')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.PRIMARY_DARK)
          .fontStyle(FontStyle.Italic)
      }
      .width(58)
      .justifyContent(FlexAlign.Start)

      // 中：标题 + 在线徽标
      Column() {
        Text('任务规划')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Row() {
          Circle()
            .width(6)
            .height(6)
            .fill(this.gatewayReady ? Colors.ONLINE_DOT : Colors.TEXT_TERTIARY)
          Text(this.gatewayReady ? '在线' : '本地模板')
            .fontSize(11)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ left: 5 })
        }
        .padding({ left: 10, right: 12, top: 3, bottom: 3 })
        .backgroundColor(this.gatewayReady ? Colors.ONLINE_SOFT : Colors.BG)
        .borderRadius(10)
        .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      // 右：用户头像
      Row() {
        UserAvatar({ avatar: this.avatar, diameter: 38, radius: 10, bg: Colors.PRIMARY_SOFT })
      }
      .width(58)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 18, right: 16, top: 14, bottom: 12 })
  }

  @Builder
  aiBubble(content: string) {
    Row({ space: 10 }) {
      // AI 头像：深色圆 + "AI"
      Stack() {
        Circle()
          .width(34)
          .height(34)
          .fill(Colors.AI_AVATAR_BG)
        Text('AI')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      Text(content)
        .fontSize(15)
        .fontColor(Colors.TEXT_PRIMARY)
        .lineHeight(23)
        .backgroundColor(Colors.BUBBLE_AI)
        .padding({ left: 14, right: 14, top: 11, bottom: 11 })
        .borderRadius(14)
        .constraintSize({ maxWidth: '74%' })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  userBubble(content: string) {
    Row({ space: 10 }) {
      Text(content)
        .fontSize(15)
        .fontColor(Colors.TEXT_PRIMARY)
        .lineHeight(23)
        .backgroundColor(Colors.BUBBLE_USER)
        .padding({ left: 14, right: 14, top: 11, bottom: 11 })
        .borderRadius(14)
        .constraintSize({ maxWidth: '74%' })
      // 用户头像（emoji 或相册照片，右上角与工作台一致）
      UserAvatar({ avatar: this.avatar, diameter: 34, radius: 10, bg: Colors.PRIMARY_SOFT })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.End)
  }

  @Builder
  planRow(t: Task) {
    Row({ space: 10 }) {
      // 圆圈确认：点击后变实心
      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(this.isConfirmed(t.id) ? Colors.CHAT_ACTION : Color.Transparent)
          .stroke(this.isConfirmed(t.id) ? Colors.CHAT_ACTION : Colors.TEXT_TERTIARY)
          .strokeWidth(1.5)
        if (this.isConfirmed(t.id)) {
          Text('✓')
            .fontSize(12)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
      }
      .onClick(() => {
        this.toggleConfirm(t.id)
      })

      // 标题 + 科目/推荐时长；点文字进编辑弹窗
      Column() {
        Text(t.title)
          .fontSize(15)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => {
            this.startEdit(t)
          })
        Text(`${t.subject} · 推荐 ${t.estimatedDuration} 分钟`)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 4 })
          .width('100%')
          .onClick(() => {
            this.startEdit(t)
          })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 行内时长微调：不打开编辑弹窗也能改
      Row({ space: 4 }) {
        Text('−')
          .fontSize(16)
          .fontColor(Colors.PRIMARY_DARK)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor(Colors.PRIMARY_SOFT)
          .borderRadius(14)
          .onClick(() => {
            this.bumpMinutes(t.id, -5)
          })
        Text(`${t.estimatedDuration}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .width(34)
          .textAlign(TextAlign.Center)
        Text('＋')
          .fontSize(15)
          .fontColor(Colors.PRIMARY_DARK)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor(Colors.PRIMARY_SOFT)
          .borderRadius(14)
          .onClick(() => {
            this.bumpMinutes(t.id, 5)
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  planSection() {
    Column() {
      Text('待确认任务')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 6, bottom: 16 })

      Column({ space: 16 }) {
        // key 里带上时长与勾选态：只用 t.id 时，改了时长 ArkUI 会复用旧节点，
        // 导致行内的时长数字不刷新（± 点了没反应）
        ForEach(this.tasks, (t: Task) => {
          this.planRow(t)
        }, (t: Task) => `${t.id}_${t.estimatedDuration}_${t.done ? 1 : 0}`)
      }
      .width('100%')
      .padding({ left: 12, right: 12 })

      // 出计划后仍可回到对话，继续让 AI 调整安排
      if (!this.showComposer) {
        Text('💬 继续调整')
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 16 })
          .onClick(() => {
            this.showComposer = true
          })
      }
    }
    .width('100%')
  }

  @Builder
  editPanel() {
    Column() {
      Column() {
        Text('编辑任务')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

        TextInput({ placeholder: '任务名称', text: this.draftTitle })
          .fontSize(15)
          .height(46)
          .margin({ top: 16 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.draftTitle = v
          })

        TextInput({ placeholder: '科目', text: this.draftSubject })
          .fontSize(15)
          .height(46)
          .margin({ top: 10 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.draftSubject = v
          })

        Row() {
          Text('预计时长')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
          Blank()
          Button('−')
            .width(34)
            .height(34)
            .fontSize(16)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.BG)
            .borderRadius(17)
            .onClick(() => {
              if (this.draftMinutes > 5) {
                this.draftMinutes -= 5
              }
            })
          Text(`${this.draftMinutes} 分钟`)
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .width(76)
            .textAlign(TextAlign.Center)
          Button('＋')
            .width(34)
            .height(34)
            .fontSize(16)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.BG)
            .borderRadius(17)
            .onClick(() => {
              if (this.draftMinutes < 240) {
                this.draftMinutes += 5
              }
            })
        }
        .width('100%')
        .margin({ top: 16 })

        Row({ space: 12 }) {
          Button('删除')
            .layoutWeight(1)
            .height(46)
            .fontSize(15)
            .fontColor(Colors.CAMERA_RED)
            .backgroundColor(Colors.BG)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.deleteTask()
            })
          Button('取消')
            .layoutWeight(1)
            .height(46)
            .fontSize(15)
            .fontColor(Colors.TEXT_SECONDARY)
            .backgroundColor(Colors.BG)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.editId = ''
            })
          Button('保存')
            .layoutWeight(1)
            .height(46)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor(Colors.CHAT_ACTION)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.saveEdit()
            })
        }
        .width('100%')
        .margin({ top: 22 })
      }
      .width('86%')
      .padding(24)
      .backgroundColor(Colors.CARD)
      .borderRadius(Radius.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  inputBar() {
    Row({ space: 10 }) {
      TextInput({ placeholder: '说说你今天想学什么…', text: this.inputValue })
        .fontSize(15)
        .height(44)
        .layoutWeight(1)
        .backgroundColor(Colors.CARD)
        .borderRadius(22)
        .onChange((v: string) => {
          this.inputValue = v
        })
        .onSubmit(() => {
          this.send()
        })

      Button('发送')
        .height(44)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(Colors.CHAT_ACTION)
        .borderRadius(22)
        .padding({ left: 18, right: 18 })
        .onClick(() => {
          this.send()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 16 })
    .backgroundColor(Colors.BG)
  }

  @Builder
  startBar() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
          Circle()
            .width(18)
            .height(18)
            .fill(Colors.CHAT_ACTION)
          Text('✓')
            .fontSize(11)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
        Text(`进入 ${this.plannedMinutes()} 分钟专注学习`)
          .fontSize(14)
          .fontColor(Colors.TEXT_PRIMARY)
      }
      .margin({ bottom: 12 })

      Button('确认并开始专注学习')
        .width('100%')
        .height(52)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(Colors.CHAT_ACTION)
        .borderRadius(26)
        .onClick(() => {
          this.confirmStart()
        })

      Text('学习过程中会提醒你节奏与复盘节点')
        .fontSize(12)
        .fontColor(Colors.TEXT_TERTIARY)
        .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 12, bottom: 16 })
    .backgroundColor(Colors.BG)
  }

  build() {
    Stack() {
      Column() {
        this.header()

        // 跳过规划：还没出计划时，可直接开始（不强依赖对话）
        if (this.tasks.length === 0) {
          Row() {
            Row() {
              Text('不想聊？')
                .fontSize(12)
                .fontColor(Colors.TEXT_TERTIARY)
              Text('跳过规划，直接开始专注 ›')
                .fontSize(12)
                .fontColor(Colors.PRIMARY_DARK)
                .margin({ left: 4 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(Colors.CARD)
            .borderRadius(14)
            .onClick(() => {
              this.skipPlanning()
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ left: 18, right: 18, bottom: 6 })
        }

        // 对话 + 待确认任务
        Scroll(this.scroller) {
          Column({ space: 18 }) {
            ForEach(this.messages, (m: AIMessage) => {
              if (m.role === MessageRole.AI) {
                this.aiBubble(m.content)
              } else {
                this.userBubble(m.content)
              }
            }, (m: AIMessage) => m.id)

            // 流式输出：reply 实时逐段上屏（不放进 messages，避免 ForEach key 不变导致不刷新）
            if (this.streaming) {
              this.aiBubble(this.streamingText.length > 0 ? this.streamingText : '正在思考…')
            } else if (this.thinking) {
              this.aiBubble('正在思考…')
            }

            if (this.tasks.length > 0) {
              this.planSection()
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 18 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        // 底部：出计划后固定「开始专注」，否则为输入栏
        if (this.tasks.length > 0 && !this.showComposer) {
          this.startBar()
        } else {
          this.inputBar()
        }
      }
      .width('100%')
      .height('100%')

      if (this.editId.length > 0) {
        this.editPanel()
      }

      AIFirstDisclaimer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
