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
import { MessageRole, TaskStatus } from '../models/Enums'
import { IdUtils } from '../utils/IdUtils'
import { Metrics } from '../services/Metrics'
import { StudyPlan } from '../models/StudyPlan'
import { TimeUtils } from '../utils/TimeUtils'
import { AIFirstDisclaimer } from '../components/AIFirstDisclaimer'
import { UserAvatar } from '../components/UserAvatar'
import { VoiceInputButton } from '../components/VoiceInputButton'

/**
 * 手动新增的哨兵 id：`editId` 等于它时，`editPanel` 走"新增"而不是"编辑"分支，
 * 从而复用同一个表单弹窗，不必再写一份几乎一样的 UI。
 * （ArkUI 的 struct 里不能声明 static 成员，所以放在模块作用域。）
 */
const NEW_TASK_ID = '__new__'

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
  /** 用户已发言轮数（兜底用：追问到第 3 轮还没出计划就直接生成） */
  @State turns: number = 0
  /** 出计划后是否仍显示输入框（用户点「继续调整」时置 true） */
  @State showComposer: boolean = false
  @State tasks: Task[] = []
  /** 已点击确认（圆圈变实心）的任务 id */
  @State confirmedIds: string[] = []
  /**
   * 是否进入「显式勾选」模式。
   * false：confirmedIds 为空 = 全都选上（AI 刚排完的默认态）；
   * true ：以 confirmedIds 为准，空数组就是"一条都没选" ——
   *        跨天带进来的旧任务要靠它表达"候选但未选"。
   */
  @State selectInitialized: boolean = false
  /** 待确认列表里是否有"跨天带进来的旧任务"（有就提示用户勾选） */
  @State hasLeftover: boolean = false
  /** 上次模型返回后"新增几条 / 跳过几条"的如实说明 */
  @State addedNotice: string = ''
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
  /**
   * 数据版本：别的页面（首页 / 复盘）勾完任务后会自增。
   *
   * 规划页是 Tabs 常驻子页，`aboutToAppear` 只跑一次 —— 没有这个 @Watch 的话，
   * 别处勾掉的任务会一直挂在「待确认任务」里显示成未完成，用户就会觉得"没有同步"。
   */
  @StorageProp(StorageKey.DATA_VERSION) @Watch('onDataChanged') dataVersion: number = 0
  private scroller: Scroller = new Scroller()
  /** 传给 AI 的历史对话，按 [user, ai, user, ai, ...] 交替存放 */
  private history: string[] = []
  /** 用户说过的原话，兜底生成计划时拼成目标 */
  private userTexts: string[] = []
  /** 长期计划摘要（来自 study_plan；作为规划的背景参考，随上下文注入提示词） */
  private longPlanText: string = ''
  /**
   * 上次"刷新成新一轮"时的会话条数。
   * 用来识别"这期间又跑完了一次专注" —— 会话只在 endSession 时新增，
   * 所以条数变大就说明这一轮计划已经执行完，页面该刷新了。
   * -1 = 还没建立基线（首次），只记录不刷新。
   */
  private sessionCountAtInit: number = -1

  aboutToAppear(): void {
    // 徽标要如实反映"这次到底是走大模型还是本地模板"，不能无条件亮绿灯
    this.gatewayReady = AIService.getInstance().isGatewayReady()
    // 已有的今日计划先载入「待确认任务」——**但只在这轮计划还没被用过时**。
    // 规则见 AppStore.isPlanRoundUsed()：
    //  · 刚排完、还没开始做 → 增量（"先排高数、再加英语"时，高数那几条不会被冲掉）；
    //  · 已经跑过至少一次专注 → 那一轮已经执行完，这次是**新一轮规划**，
    //    不再把旧清单当作"请勿重复输出"的基准，否则模型会一直以为在上一轮基础上改。
    this.seedRound()
    // 记下当前的会话条数当基线：之后条数变大就说明"又跑完了一次专注"，页面该刷新
    this.sessionCountAtInit = AppStore.getInstance().getSessions().length
    // 开场只保留这一条问候（原来后面还会追一句"上一轮已经执行过…"，
    // 用户要求删掉；那些信息改成界面上的提示条，不再占用对话）
    this.pushAI(AIService.getInstance().planningIntro())
    this.loadLongPlan()
  }

  /**
   * 起一轮规划：按"这一轮是否已经跑过专注"决定「待确认任务」怎么来。
   *  - 未跑过 → 原样沿用现有计划（"先排高数、再加英语"时，高数那几条不会被冲掉）；
   *  - 跑过   → 之前**还没做完的**作为候选列出来，且一条都不预勾选
   *            （`selectInitialized = true` 表达"候选但未选"），勾选了才会加入今天的专注。
   */
  private seedRound(): void {
    const store = AppStore.getInstance()
    const used = store.isPlanRoundUsed()
    const existing = store.getCurrentPlan()
    if (!used && existing.length > 0) {
      const loaded: Task[] = []
      for (const t of existing) {
        loaded.push(t.copy())
      }
      this.tasks = loaded
    } else if (used) {
      const leftover = store.unfinishedTasks(6, false)
      if (leftover.length > 0) {
        this.tasks = leftover
        this.selectInitialized = true
        this.confirmedIds = []
        this.hasLeftover = true
      }
    }
  }

  /**
   * **开一轮全新的规划**（一轮专注结束后调用）。
   *
   * 用户要求："每次 AI 规划后专注后，聊天记录不再保留，应该直接刷新成一个新页面"。
   * 规划页是 Tabs 常驻子页，不清的话上次的对话与清单会一直挂在那儿。
   * 清成"刚进页面"的样子：只有一句问候 + 重新算出来的候选任务。
   */
  private startNewRound(): void {
    this.messages = []
    this.turns = 0
    this.history = []
    this.userTexts = []
    this.confirmedIds = []
    this.selectInitialized = false
    this.hasLeftover = false
    this.addedNotice = ''
    this.tasks = []
    this.thinking = false
    this.streaming = false
    this.streamingText = ''
    this.showComposer = false
    this.editId = ''
    this.inputValue = ''
    this.seedRound()
    // 刷新基线：下一轮再比较时要拿"这一刻"的条数
    this.sessionCountAtInit = AppStore.getInstance().getSessions().length
    this.pushAI(AIService.getInstance().planningIntro())
  }

  /** 长期计划：在「复盘 → 长期计划」里设置，这里读出来当背景参考（不单独占一条对话） */
  private loadLongPlan(): void {
    // 走 AppStore.loadPlan()：与设置页同一个对象（避免读到旧值）
    AppStore.getInstance().loadPlan().then((p: StudyPlan | null) => {
      if (p === null || p.title.length === 0) {
        return
      }
      const hours = p.totalEstimatedMinutes > 0 ? ` · 目标 ${Math.round(p.totalEstimatedMinutes / 60)} 小时` : ''
      // 考试类型不再从计划里取（StudyPlan 已不复制 examType，备考目标在 buildPlanningContext 里由 goal 统一注入）；
      // 但要把**各科目标**带上：它决定"目标进度"的分母，规划要看到同一份口径
      const parts: string[] = []
      for (const st of p.subjectTargets) {
        if (st.subject.length > 0 && st.targetMinutes > 0) {
          parts.push(`${st.subject} ${Math.round(st.targetMinutes / 60)} 小时`)
        }
      }
      const subsText = parts.length > 0 ? ` · 各科目标 ${parts.join('、')}` : ''
      // 只作为规划背景注入提示词，不再单独发一条对话（开场对话只留问候那一条）
      this.longPlanText = `${p.title}${hours}${subsText}`
    }).catch(() => {
      // 没有长期计划就正常聊，不硬提
    })
  }

  /**
   * 数据版本变化：把已经在别处勾选完成的任务从「待确认任务」里摘掉。
   *
   * 只做"移除已完成"，**不动**其余任务 —— 用户可能正在编辑时长、已经勾了几条，
   * 整份重取会把这些操作冲掉。
   */
  private onDataChanged(): void {
    const store = AppStore.getInstance()
    // ① 会话条数变多 = 这期间又跑完了一次专注 → 上一轮已经执行完，
    //    聊天记录与待确认清单都不再保留，直接刷新成新一轮（用户明确要求）。
    const sessionCount = store.getSessions().length
    if (this.sessionCountAtInit < 0) {
      this.sessionCountAtInit = sessionCount
      return
    }
    if (sessionCount > this.sessionCountAtInit) {
      this.sessionCountAtInit = sessionCount
      this.startNewRound()
      return
    }

    // ② 其余数据变化（别处勾选任务等）：只把已完成的从「待确认任务」里摘掉
    if (this.tasks.length === 0) {
      return
    }
    const doneIds: string[] = []
    for (const t of store.getTasks()) {
      if (t.done || t.status === TaskStatus.DONE) {
        doneIds.push(t.id)
      }
    }
    if (doneIds.length === 0) {
      return
    }
    const next: Task[] = []
    let removed = false
    for (const t of this.tasks) {
      if (doneIds.indexOf(t.id) >= 0) {
        removed = true
      } else {
        next.push(t)
      }
    }
    if (!removed) {
      return
    }
    this.tasks = next
    // 勾选集合同步收窄，避免"确认并开始"里残留已经不在列表里的 id
    const kept: string[] = []
    for (const id of this.confirmedIds) {
      for (const t of next) {
        if (t.id === id) {
          kept.push(id)
          break
        }
      }
    }
    this.confirmedIds = kept
    if (next.length === 0) {
      this.hasLeftover = false
    }
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
   *  - 模型正常聊天、按需追问（一次只问一个最关键的缺口）；
   *  - 一旦判断信息够了，直接返回 done=true + tasks → 立刻出计划；
   *  - 追问满 3 轮仍未给计划 → 兜底走 task_plan 直接拆任务。
   *
   * `step` 传 0 基轮次（第一条用户消息 = 0），本地模板按它分支提几个问题。
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
    // 上一轮的"新增 N 条"提示已经过期，先清掉
    this.addedNotice = ''

    this.thinking = true
    this.streaming = true
    this.streamingText = ''
    const existing: string[] = []
    for (const t of this.tasks) {
      existing.push(t.subject.length > 0 ? `${t.subject}·${t.title}` : t.title)
    }
    const input: PlanningDialogInput = {
      step: this.turns - 1,
      userInput: text,
      history: this.history,
      planningContext: this.buildPlanningContext(),
      // 结构化地把"已有清单"给到 AI 层：本地兜底据此只补新增项，不再把旧任务列一遍
      existingTasks: existing
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
    // 兜底：追问满 3 轮还没出计划，就按已收集的信息直接生成。
    // turns = 用户发言次数。模型在第 1~3 次发言后各可追问 1 个问题；
    // 到第 4 次发言仍未给计划时，说明它在原地打转，这里强制出计划（提示词口径同为「最多追问 3 轮」）。
    if (this.turns >= 4) {
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

  /** 标题里出现的数字串（"做10道题" -> "10"）；量不同就是不同的任务，不能算重复 */
  private numbersIn(t: string): string {
    let out = ''
    let cur = ''
    for (let i = 0; i < t.length; i++) {
      const c = t.charAt(i)
      if (c >= '0' && c <= '9') {
        cur += c
      } else if (cur.length > 0) {
        out += cur + ','
        cur = ''
      }
    }
    if (cur.length > 0) {
      out += cur
    }
    return out
  }

  /**
   * 两条任务是不是"同一件事"。
   *
   * 只用 (科目|标题) 精确相等，是拦不住模型**换个说法重排**的
   * （"做 10 道级数题" -> "做 10 道级数习题"）：这时旧任务会被再加一遍，
   * 用户在「待确认任务」里就看到重复项。所以补一层**保守**的模糊判定：
   *   1. 科目 + 标题归一化后都相等 -> 同一条；
   *   2. 标题归一化后相等，且科目相同或有一边为空 -> 同一条；
   *   3. **数字不同就直接判为不同**（"背 50 个单词" != "背 30 个单词"）——
   *      这是最容易误伤的一类，先挡掉；
   *   4. 长度接近（>=0.7）且字符重合度 >=0.8 -> 同一条。
   * 阈值刻意取高：宁可漏判重复，也不要把"级数题"和"微分题"这种真的不同的任务吞掉。
   */
  private isSameTask(subjectA: string, titleA: string, subjectB: string, titleB: string): boolean {
    const sa = this.titleKey(subjectA)
    const sb = this.titleKey(subjectB)
    const ta = this.titleKey(titleA)
    const tb = this.titleKey(titleB)
    if (sa === sb && ta === tb) {
      return true
    }
    if (ta.length === 0 || tb.length === 0) {
      return false
    }
    if (ta === tb && (sa === sb || sa.length === 0 || sb.length === 0)) {
      return true
    }
    // 量不同 = 不同任务，避免把"50 个单词"和"30 个单词"合并成一条
    if (this.numbersIn(ta) !== this.numbersIn(tb)) {
      return false
    }
    const maxLen = Math.max(ta.length, tb.length)
    const minLen = Math.min(ta.length, tb.length)
    if (maxLen === 0 || minLen / maxLen < 0.7) {
      return false
    }
    let hit = 0
    for (let i = 0; i < ta.length; i++) {
      if (tb.indexOf(ta.charAt(i)) >= 0) {
        hit += 1
      }
    }
    return hit / maxLen >= 0.8
  }

  /**
   * 把 AI 给出的任务**追加**到「待确认任务」列表，而不是整体替换。
   *  - 已有任务原样保留（含用户手动调过的时长、已勾选状态）；
   *  - 科目 + 标题都相同的视为同一条，跳过 —— 多轮对话不会把清单越聊越乱；
   *  - 新加进来的任务在"已经点过圆圈"的情况下自动并入勾选集合，
   *    否则「确认并开始」会把刚加的科目静默排除掉（选了 1 个之后其余全被剔除）。
   */
  private applyPlan(list: PlanTask[]): void {
    const next: Task[] = this.tasks.slice()
    const addedIds: string[] = []
    let dupCount = 0
    for (const p of list) {
      let dup = false
      for (const t of next) {
        if (this.isSameTask(t.subject, t.title, p.subject, p.title)) {
          dup = true
          break
        }
      }
      if (dup) {
        dupCount += 1
        continue
      }
      const t = this.toTask(p)
      t.sortOrder = next.length
      next.push(t)
      addedIds.push(t.id)
    }
    if (addedIds.length === 0) {
      // 模型把整份清单又输出了一遍：如实说明"没有新增"，而不是静默无反应
      if (dupCount > 0) {
        this.addedNotice = `这 ${dupCount} 条清单里已经有了，没有重复加进「待确认任务」。`
      }
      return
    }
    this.tasks = next
    // 新增项一律并入勾选集合；同时进入「显式勾选」模式，
    // 这样跨天带进来的旧候选（未勾选）不会被"空数组 = 全选"的旧语义误选中
    this.selectInitialized = true
    const merged: string[] = this.confirmedIds.slice()
    for (const id of addedIds) {
      merged.push(id)
    }
    this.confirmedIds = merged
    this.addedNotice = dupCount > 0
      ? `新增 ${addedIds.length} 条；另外 ${dupCount} 条清单里已经有了，已跳过。`
      : `新增 ${addedIds.length} 条任务。`
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
    // 当前清单：让模型知道"已经排了什么"，只补差量、不重复输出。
    // 不注入这一项时，模型只能靠历史对话猜，用户说"再加上英语"很容易得到整份重排。
    if (this.tasks.length > 0) {
      const names: string[] = []
      for (const t of this.tasks) {
        const sub = t.subject.length > 0 ? `${t.subject}·` : ''
        const done = t.done ? '（已完成）' : ''
        names.push(`${sub}${t.title} ${t.estimatedDuration}分钟${done}`)
      }
      lines.push(`- 当前今日清单（已存在，请勿重复输出）：${names.join('；')}`)
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
    // 本页产生的任务一律归属当前长期计划 —— 「目标进度」只统计这一批，
    // 不把历次规划的散任务也算进分母（那会让进度越用越接近 0%）
    t.planId = StudyPlan.PLAN_SINGLETON_ID
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

  /**
   * 手动新建任务。**不调 `AppStore.addPlanTask()`** —— 那个方法直接写 `currentPlan` 并落库，
   * 会绕过「待确认任务 → 确认并开始」这条链路，用户还没确认就先出现在今天的清单里。
   * 这里只往 `this.tasks` 推一条，与 AI 给出的任务走同一套勾选/编辑/开始流程。
   */
  private startAdd(): void {
    this.editId = NEW_TASK_ID
    this.draftTitle = ''
    this.draftSubject = ''
    this.draftMinutes = 30
  }

  private saveEdit(): void {
    const title = this.draftTitle.trim()
    const subject = this.draftSubject.trim()
    if (this.editId === NEW_TASK_ID) {
      if (title.length === 0) {
        promptAction.showToast({ message: '给这条任务起个名字吧' })
        return
      }
      const t = new Task()
      t.id = IdUtils.uuid()
      t.title = title
      t.subject = subject
      t.estimatedDuration = this.draftMinutes
      t.sortOrder = this.tasks.length
      t.createdAt = Date.now()
      // 手动任务与 AI 任务一样归属当前长期计划（与 AppStore.addPlanTask 的口径一致）
      t.planId = StudyPlan.PLAN_SINGLETON_ID
      const next: Task[] = this.tasks.slice()
      next.push(t)
      this.tasks = next
      // 新增项默认选中（否则「确认并开始」会把它静默丢掉）
      this.selectInitialized = true
      const merged: string[] = this.confirmedIds.slice()
      merged.push(t.id)
      this.confirmedIds = merged
      this.editId = ''
      return
    }
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
    // 只有"还没进入显式勾选模式"时，空集合才代表全选；
    // 跨天带进来的候选是"显式勾选模式 + 空集合" = 一条都没选，必须等用户自己勾。
    if (!this.selectInitialized) {
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
    // 一条都没选（清单里全都取消勾选）= 用户想直接开始，**不该被拦住**。
    // 原来的实现会弹「至少保留一个任务」，于是"我今天的任务都做完了，想随便学一会儿"
    // 这种再正常不过的场景直接走不下去。改为走「自由专注」通道：
    //   本次会话不挂任何任务，且**不动已保存的今日计划**（否则会把清单清空）。
    if (selected.length === 0) {
      await this.startFreeFocus()
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

  /**
   * 以「自由专注」开始：本次会话**不挂任何任务**。
   *
   * 与「跳过规划」同一条通道（`FOCUS_FREE_REQUEST`），区别只是入口不同：
   * 一个是没有清单时直接开始，一个是清单里一条都没勾（比如今天都做完了）。
   * ⚠️ 刻意**不调用 `setCurrentPlan([])` / `persistPlan([])`** ——
   * 用户只是"这次不想挂任务"，不该把已保存的计划清空。
   */
  private async startFreeFocus(): Promise<void> {
    if (FocusController.getInstance().isRunning()) {
      try {
        await AppStore.getInstance().endSession()
      } catch (e) {
        hilog.error(0x0000, 'iKnow.Planning', '结束上一段会话出错，仍继续自由专注：%{public}s', e.message)
      }
    }
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_FREE_REQUEST, 1)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 1)
    router.pushUrl({ url: 'pages/Focus' })
  }

  /**
   * 跳过规划：不聊天、不生成任务，**这次以自由专注开始**（不挂任何任务）。
   *
   * 之前这里是"带着已有计划开始"，于是今日计划里那些（可能已全部完成的）任务
   * 会跟着进会话，专注页照样出现「今日任务」一块 —— 用户的原话是
   * "跳过规划直接专注的时候，专注页不应该有今日任务模块"。
   * 注意：**只影响这一次会话**，今日计划本身不动，首页照旧显示。
   */
  private skipPlanning(): void {
    if (this.thinking) {
      return
    }
    if (FocusController.getInstance().isRunning()) {
      // 已有会话在跑：直接进去继续，不改变它的任务
      router.pushUrl({ url: 'pages/Focus' })
      return
    }
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_FREE_REQUEST, 1)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 1)
    router.pushUrl({ url: 'pages/Focus' })
  }

  // ---------- 视图 ----------
  @Builder
  header() {
    Row() {
      // 左：等宽占位（不显示文字，仅用来让中间标题真正居中，与右侧头像同宽）
      Row() {
      }
      .width(74)
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

      // 右：用户头像（与左侧同宽，标题才是真居中）
      Row() {
        UserAvatar({ avatar: this.avatar, diameter: 38, radius: 10, bg: Colors.PRIMARY_SOFT })
      }
      .width(74)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 18, right: 16, top: 14, bottom: 12 })
  }

  @Builder
  aiBubble(content: string) {
    Row({ space: 10 }) {
      // 考伴头像：深色圆角块 + 品牌字「iKnow」
      // 用户要求：不要写「AI」，直接用 iKnow —— 小伴本来就叫 iKnow，标 AI 反而像外挂。
      // 做成圆角方块（不是圆）：圆的可用宽度只有直径的 ~0.7 倍，5 个字母会被挤到换行。
      Stack() {
        Text('iKnow')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontStyle(FontStyle.Italic)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
      }
      .width(38)
      .height(38)
      .backgroundColor(Colors.AI_AVATAR_BG)
      .borderRadius(11)
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
        .margin({ top: 6, bottom: this.tasks.length === 0 ? 6 : 16 })

      // 说明条：这些内容原本是对话里的第二、三条消息，用户要求开场只留一句问候，
      // 所以挪到这里当提示，既不占对话、又不会让用户对空清单摸不着头脑。
      // 只在**确实列出了未完成任务**时才显示 —— 没有旧任务就什么都不说
      // （用户明确要求：没有未完成任务时不要出现这行绿字）。
      if (this.hasLeftover) {
        Text('下面是你还没做完的任务，请选择是否加入当前专注')
          .fontSize(11)
          .fontColor(Colors.PRIMARY_DARK)
          .lineHeight(16)
          .width('100%')
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .backgroundColor(Colors.PRIMARY_SOFT)
          .borderRadius(Radius.SM)
          .margin({ bottom: 12 })
      }

      if (this.addedNotice.length > 0) {
        Text(this.addedNotice)
          .fontSize(11)
          .fontColor(Colors.TEXT_TERTIARY)
          .lineHeight(16)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 10 })
      }

      // 还没有任务时把 AI 摆在前头：这一页的主路径本来就是"聊两句就排好"，
      // 手动新建是给"我心里已经很清楚要做什么"的人留的次要出路。
      if (this.tasks.length === 0) {
        Text('跟小伴说一句"今晚想复习高数"，就能拆成能直接动手的任务')
          .fontSize(12)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .margin({ bottom: 16 })
      }

      Column({ space: 16 }) {
        // key 里带上时长与勾选态：只用 t.id 时，改了时长 ArkUI 会复用旧节点，
        // 导致行内的时长数字不刷新（± 点了没反应）
        ForEach(this.tasks, (t: Task) => {
          this.planRow(t)
        }, (t: Task) => `${t.id}_${t.estimatedDuration}_${t.done ? 1 : 0}`)
      }
      .width('100%')
      .padding({ left: 12, right: 12 })

      // 有计划后仍可回到对话继续追加需求（如"再加上英语"）。
      // 做成开关而不是一次性按钮：否则点开就没法收起，输入栏会一直占着底部。
      // 清单为空时不出现 —— 那时"继续补充"没有对象，底部本来就是常驻输入栏。
      if (this.tasks.length > 0) {
        Text(this.showComposer ? '收起对话' : '💬 继续补充 / 调整')
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 16 })
          .onClick(() => {
            this.showComposer = !this.showComposer
          })
      }

      // 次要出路：已经想清楚要做什么的人不必走对话。样式刻意弱化，避免和上面那条抢注意力。
      Text('✍️ 手动添加任务')
        .fontSize(12)
        .fontColor(Colors.TEXT_TERTIARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 10, bottom: 4 })
        .onClick(() => {
          this.startAdd()
        })
    }
    .width('100%')
  }

  @Builder
  editPanel() {
    Column() {
      Column() {
        Text(this.editId === NEW_TASK_ID ? '新增任务' : '编辑任务')
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
          // 新增模式没有可删的条目，这个按钮不渲染
          if (this.editId !== NEW_TASK_ID) {
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
          }
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

      // 按住说话：识别结果写回输入框，用户确认后再发（不自动发送，留出纠错余地）
      VoiceInputButton({
        onFinal: (text: string) => {
          if (text.length > 0) {
            this.inputValue = text
          }
        }
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
        Text(this.selectedTasks().length === 0
          ? '直接进入自由专注'
          : `进入 ${this.plannedMinutes()} 分钟专注学习`)
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

      Text(this.selectedTasks().length === 0
        ? '本次不挂任务，清单会留在「今日任务」里，之后随时可以接着做'
        : '学习过程中会提醒你节奏与复盘节点')
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

            // 无条件渲染：清单为空时这一块要承担"引导用 AI 建任务 + 手动新建入口"的职责
            this.planSection()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 18 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        // 底部：一旦有了计划就**始终**保留「开始专注」（用户随时可以走），
        // 需要继续聊时输入栏叠加在它上方。
        // 原来是二选一（有输入栏就没有开始按钮），于是"加了英语却找不到开始按钮"，
        // 把本来顺畅的追加流程卡死在聊天里。
        if (this.tasks.length > 0) {
          Column() {
            if (this.showComposer) {
              this.inputBar()
            }
            this.startBar()
          }
          .width('100%')
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
