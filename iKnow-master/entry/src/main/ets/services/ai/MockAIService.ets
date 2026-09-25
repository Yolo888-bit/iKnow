import { AIService, AIScene, AIRequest, AIResponse, AIPayload, AIResult } from './AIService'
import {
  QATextPayload,
  QAImagePayload,
  QAResp,
  QAMessage,
  QA_DISCLAIMER,
  QA_SCHEMA_VERSION,
  QAService
} from './QAService'
import {
  CompanionContext,
  CompanionDecision,
  COMPANION_SCHEMA_VERSION,
  CompanionService
} from './CompanionService'
import { ReviewPayload, ReviewData, REVIEW_SCHEMA_VERSION, ReviewService } from './ReviewService'
import {
  PlanningInput,
  PlanningResult,
  PlanningDialogInput,
  PlanningDialogResult,
  PLANNING_SCHEMA_VERSION,
  PlanningService
} from './PlanningService'
import {
  MemoryPayload,
  MemoryDelta,
  ProfileFields,
  MEMORY_SCHEMA_VERSION,
  MemoryService
} from './MemoryService'
import { SchemaValidator } from './SchemaValidator'
import { FocusSession } from '../../models/FocusSession'
import { QuestionRecord } from '../../models/QuestionRecord'
import { FocusProfile } from '../../models/FocusProfile'
import { PlanTask } from '../../models/StudyPlan'
import { Task } from '../../models/Task'
import { StudyReport } from '../../models/StudyReport'
import { Metrics, DaySummary, Baseline, Trend7v7, Streaks } from '../Metrics'
import { IdUtils } from '../../utils/IdUtils'
import { TimeUtils } from '../../utils/TimeUtils'

interface RetryConfig {
  timeoutMs: number
  retries: number
}

interface WordingLevel {
  light: string
  heavy: string
}

interface WordingMap {
  GENTLE: WordingLevel
  STRICT: WordingLevel
  QUIET: WordingLevel
  ADAPTIVE: WordingLevel
}

/**
 * 本地 Mock AI 服务实现（PRD §13 / §14）
 *
 *  - 实现 5 个独立接口（QAService / CompanionService / ReviewService /
 *    PlanningService / MemoryService），与未来 GatewayAIService 同接口、同 Schema。
 *  - 内置 §14.5 超时 / 重试矩阵：超时 → 重试 1 次 → 无效则本地兜底。
 *  - 所有输出经 SchemaValidator 校验；校验失败重试 1 次，仍失败走兜底。
 *  - 人格（GENTLE/STRICT/QUIET/ADAPTIVE）通过 wording pack 影响文案，绝不假装真人。
 *  - 不持有任何 API Key；Gateway 接入时仅替换本类，UI 不变。
 */
/**
 * 通用语录池：**鼓励型 + 优美**的一句话。
 *
 * 用户明确要的是"继续努力、真棒、一路生花上岸"这种**给人打气**的语录，
 * 而不是"要用户怎么怎么做"的方法论 —— 所以这里不再写"先坐下来，再谈状态"这类指导语，
 * 改成温暖、有画面感、读完被托一把的话。
 * 长度都控制在 14 个汉字以内，首页 15vp 字号一行放得下。
 */
const GENERAL_SLOGANS: string[] = [
  '一路生花，上岸见',
  '你走的每一步都算数',
  '今天的你比昨天更近',
  '认真的人最好看',
  '你已经在发光了',
  '再坚持一下，就到了',
  '你的努力有回响',
  '保持热爱，奔赴山海',
  '明天会感谢今天的你',
  '稳住，你会赢的',
  '你在成为更好的自己',
  '所有努力都不会白费',
  '心之所向，素履以往',
  '慢慢走，别停下',
  '你的坚持终将美好',
  '越努力，越幸运',
  '你值得所有好结果',
  '披星戴月，终见星光',
  '事虽难，做则必成',
  '一切都在往好的方向走',
  '今天也很了不起',
  '你做得比自己想的好',
  '你比昨天更强了',
  '热爱可抵岁月漫长',
  '心有所期，全力以赴',
  '未来的你会庆幸现在',
  '你正在靠近想要的生活',
  '所有的辛苦都有意义',
  '你已经在正确的路上',
  '你比想象中更有力量',
  '慢慢积累，终会绽放',
  '你的付出看得见',
  '不必着急，你来得及',
  '光会照到你身上的',
  '你的努力在悄悄生长',
  '今天也向目标近了一步',
  '保持下去，你很好',
  '一点一点，就成了',
  '你已经很棒了',
  '辛苦了，你做得好',
  '这条路你走得很好',
  '你的未来正在展开',
  '愿你所愿皆成真',
  '山高路远，终将抵达',
  '一切都会好起来的',
  '踏踏实实，稳稳当当',
  '你所热爱的会给你答案',
  '你的坚持正在开花',
  '走下去，光就在前面',
  '每个清晨都值得期待',
  '慢慢来，你很好',
  '认真生活的样子真好看'
]

/** 目标专属语录池：命中不到就返回空数组，只用通用池 */
function goalSlogans(goalType: string): string[] {
  const g = goalType
  if (g.indexOf('公务员') >= 0 || g.indexOf('公考') >= 0 || g.indexOf('考公') >= 0 || g.indexOf('事业编') >= 0) {
    return ['一举成公', '上岸见', '你离上岸更近了', '稳稳上岸']
  }
  if (g.indexOf('研究生') >= 0 || g.indexOf('考研') >= 0) {
    return ['一战成硕', '一路生花', '你会上岸的', '从容赴考']
  }
  if (g.indexOf('高考') >= 0) {
    return ['星光不负赶路人', '金榜题名时', '六月会给你答案', '少年自有山海']
  }
  if (g.indexOf('期末') >= 0 || g.indexOf('期中') >= 0) {
    return ['门门过关', '稳稳拿分', '你会全过的']
  }
  if (g.indexOf('雅思') >= 0 || g.indexOf('托福') >= 0 || g.indexOf('四六级') >= 0) {
    return ['每天都算数', '你在悄悄变强', '分数会追上你']
  }
  if (g.indexOf('法考') >= 0 || g.indexOf('司考') >= 0) {
    return ['把法条读成底气', '你离通过不远了']
  }
  if (g.indexOf('教资') >= 0 || g.indexOf('教师') >= 0) {
    return ['你会站上讲台的', '温柔且有力量']
  }
  return []
}

export class MockAIService implements AIService, QAService, CompanionService, ReviewService, PlanningService, MemoryService {
  private static inst: MockAIService | null = null
  private personality: string = 'GENTLE'
  /** 仅供自测注入：让指定场景强制超时，用于验证重试/兜底链路 */
  private forceTimeoutScenes: Set<AIScene> = new Set<AIScene>()

  private static readonly TIMEOUTS: Map<AIScene, RetryConfig> = new Map<AIScene, RetryConfig>([
    ['task_plan', { timeoutMs: 20000, retries: 1 }],
    ['task_dialog', { timeoutMs: 15000, retries: 1 }],
    ['companion', { timeoutMs: 5000, retries: 0 }],
    ['qa_text', { timeoutMs: 20000, retries: 1 }],
    ['qa_image', { timeoutMs: 30000, retries: 1 }],
    ['review', { timeoutMs: 30000, retries: 1 }],
    ['planning', { timeoutMs: 60000, retries: 1 }],
    ['memory', { timeoutMs: 30000, retries: 1 }]
  ])

  private static readonly WORDING: WordingMap = {
    GENTLE: {
      light: '感觉你有点走神啦，先喝口水缓一缓？不用急，慢慢来。',
      heavy: '你已经离开屏幕有一会儿了，要不要先休息 5 分钟，回来状态会更好。'
    },
    STRICT: {
      light: '专注度下降了，把手机放远一点，回到任务上。',
      heavy: '已经明显分心，必须停下来。现在去休息，别硬撑。'
    },
    QUIET: {
      light: '走神了。回到屏幕。',
      heavy: '离开太久。先休息。'
    },
    ADAPTIVE: {
      light: '节奏有点松，调整一下？继续就好。',
      heavy: '分心较久，建议短暂休息后再战。'
    }
  }

  /** §14.7 QA 免责声明（所有 AI 输出必须携带） */
  private static readonly DISCLAIMER = QA_DISCLAIMER

  static getInstance(): MockAIService {
    if (MockAIService.inst === null) {
      MockAIService.inst = new MockAIService()
    }
    return MockAIService.inst
  }

  setPersonality(p: string): void {
    this.personality = p
  }

  getPersonality(): string {
    return this.personality
  }

  private static versionFor(scene: AIScene): string {
    switch (scene) {
      case 'qa_text':
      case 'qa_image':
        return QA_SCHEMA_VERSION
      case 'companion':
        return COMPANION_SCHEMA_VERSION
      case 'review':
        return REVIEW_SCHEMA_VERSION
      case 'task_plan':
      case 'task_dialog':
      case 'planning':
        return PLANNING_SCHEMA_VERSION
      case 'memory':
        return MEMORY_SCHEMA_VERSION
      default:
        return 'unknown@0'
    }
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, ms)
    })
  }

  private withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('timeout')), ms)
      p.then((v) => {
        clearTimeout(t)
        resolve(v)
      }).catch((e: Object) => {
        clearTimeout(t)
        reject(e)
      })
    })
  }

  private ok<T>(scene: AIScene, requestId: string, data: T): AIResponse<T> {
    return {
      requestId,
      ok: true,
      schemaVersion: MockAIService.versionFor(scene),
      data,
      usage: { promptTokens: 0, completionTokens: 0, latencyMs: 0 }
    }
  }

  private fallback<T>(scene: AIScene, requestId: string, data: T): AIResponse<T> {
    return {
      requestId,
      ok: true,
      schemaVersion: MockAIService.versionFor(scene),
      data,
      fallback: true,
      usage: { promptTokens: 0, completionTokens: 0, latencyMs: 0 }
    }
  }

  /** 本地兜底数据（同 Schema，与真实接口结构一致，替换时 UI 不变） */
  private defaultQA(sceneName: 'qa_text' | 'qa_image'): QAResp {
    return {
      answer: '这个问题我先记下了，稍后我们一起回顾。',
      references: [],
      disclaimer: MockAIService.DISCLAIMER,
      scene: sceneName
    }
  }

  private defaultCompanion(): CompanionDecision {
    return {
      shouldIntervene: false,
      level: 'NONE',
      channel: 'quiet',
      message: '',
      action: 'continue'
    }
  }

  private defaultReview(): ReviewData {
    return {
      insight: '本次学习已完成，继续加油。',
      suggestions: ['每 45 分钟左右主动休息一次，起来活动一下']
    }
  }

  private defaultPlan(): PlanningResult {
    return { tasks: [], summary: '我先帮你记着，稍后一起规划。' }
  }

  private defaultDialog(): PlanningDialogResult {
    return { reply: '我先帮你记着，稍后一起规划。', done: false }
  }

  private defaultMemory(): MemoryDelta {
    return { shouldUpdate: false, fields: {}, note: '' }
  }

  /** 统一执行：produce → SchemaValidator → 重试 1 → 兜底 */
  private async runWithRetry<T>(
    scene: AIScene,
    requestId: string,
    produce: () => Promise<T>,
    fallbackData: T
  ): Promise<AIResponse<T>> {
    const cfgOpt = MockAIService.TIMEOUTS.get(scene)
    const cfg: RetryConfig = cfgOpt !== undefined ? cfgOpt : { timeoutMs: 20000, retries: 1 }
    const tryOnce = async (): Promise<T | null> => {
      try {
        const forced = this.forceTimeoutScenes.has(scene)
        const promise: Promise<T> = forced
          ? (async (): Promise<T> => {
              await this.delay(cfg.timeoutMs + 10)
              return produce()
            })()
          : produce()
        const data = await this.withTimeout(promise, cfg.timeoutMs)
        const v = SchemaValidator.for(scene).validate(data as Object)
        if (v.ok) {
          return data
        }
        return null
      } catch (e) {
        return null
      }
    }
    const first = await tryOnce()
    if (first !== null) {
      return this.ok<T>(scene, requestId, first)
    }
    if (cfg.retries > 0) {
      const second = await tryOnce()
      if (second !== null) {
        return this.ok<T>(scene, requestId, second)
      }
    }
    return this.fallback<T>(scene, requestId, fallbackData)
  }

  // ===================== 5 个服务的生产逻辑 =====================

  private async producePlan(input: PlanningInput): Promise<PlanningResult> {
    await this.delay(550)
    const available = input.availableMinutes !== undefined ? input.availableMinutes : 0
    const tasks = this.buildTasks(input.goal, available)
    if (tasks.length === 0) {
      return { tasks: [], summary: '我还没听清你想学什么，能再说一句「今天想学什么、大概多久」吗？' }
    }
    let total = 0
    for (const t of tasks) {
      total += t.estimatedDuration
    }
    return {
      tasks: tasks,
      summary: `已为你拆出 ${tasks.length} 个任务，预计总时长约 ${total} 分钟。建议每 30~45 分钟休息 5~10 分钟。`
    }
  }

  /**
   * 本地模板的追问轮次必须和 `Prompts.taskDialog` 的口径一致：
   * 按「做什么动作 → 量或范围 → 可用时间」的顺序最多追问 3 轮（0 基 step 0/1/2），
   * 第 4 次发言直接出计划。
   *
   * ⚠️ 历史 bug：这里的分支写的是 `step === 0`，而页面之前传的是 **1 基**轮次，
   * 于是第一个分支永远命中不了 —— 本地模板实际只问了 1 轮就出计划，
   * 表现为"没配 Key 时 AI 一轮就把任务排完了"。页面已改为传 0 基（`step: turns - 1`）。
   */
  private async produceDialog(input: PlanningDialogInput): Promise<PlanningDialogResult> {
    await this.delay(420)
    if (input.step === 0) {
      return { reply: '可以，具体想做哪几种？比如看例题、做课后题、整理错题，还是背单词？', done: false }
    }
    if (input.step === 1) {
      return { reply: '大概什么量呢？比如做多少道题、看多少页。', done: false }
    }
    if (input.step === 2) {
      return { reply: '今天大概能坐下来学多久？我好安排每块的时间。', done: false }
    }
    // 本地兜底也必须基于用户说过的话来生成任务，绝不返回「优先任务块 A」这类占位符
    const text = this.composeUserText(input)
    const raw = this.buildTasks(text, TimeUtils.parseDurationMinutes(text))
    if (raw.length === 0) {
      return { reply: '我先记下了。再多说一句你想学什么（科目或章节），我就能帮你拆成任务。', done: false }
    }
    // **增量**：只保留清单里还没有的。
    // buildTasks 每轮都按"累积对话"重算整份，不过滤的话用户每加一句都会把旧任务再列一遍
    //（用户明确要求："只在已有基础上新增新的任务，不要再把已有任务加一遍"）。
    const existing: string[] = input.existingTasks !== undefined ? input.existingTasks : []
    const tasks: PlanTask[] = []
    let skipped = 0
    for (const t of raw) {
      if (this.alreadyPlanned(t.subject, t.title, existing)) {
        skipped += 1
        continue
      }
      tasks.push(t)
    }
    if (tasks.length === 0) {
      return {
        reply: skipped > 0
          ? `这几条你清单里已经有了，我就不重复加了。还想加什么？换个科目、或者加一段练习都行。`
          : '我先记下了。再多说一句你想学什么（科目或章节），我就能帮你拆成任务。',
        done: false
      }
    }
    let total = 0
    for (const t of tasks) {
      total += t.estimatedDuration
    }
    const head = skipped > 0 ? `清单里已有的 ${skipped} 条不重复加，` : ''
    return {
      reply: `${head}这次新增 ${tasks.length} 条，预计约 ${total} 分钟；建议每 30~45 分钟休息 5~10 分钟。`,
      done: true,
      tasks: tasks
    }
  }

  /** 归一化：去空白与常见标点，只用于"这条是不是已经在清单里了"的比对 */
  private normTitle(s: string): string {
    const skip = ' 　，。、；：,.;()（）【】[]·'
    let out = ''
    for (let i = 0; i < s.length; i++) {
      const c = s.charAt(i)
      if (skip.indexOf(c) < 0) {
        out += c
      }
    }
    return out
  }

  /** 这条任务是否已在当前清单里（格式 `科目·标题`；一侧包含另一侧也算） */
  private alreadyPlanned(subject: string, title: string, existing: string[]): boolean {
    const key = this.normTitle(`${subject}${title}`)
    if (key.length === 0) {
      return false
    }
    for (const e of existing) {
      const k = this.normTitle(e)
      if (k.length === 0) {
        continue
      }
      if (k === key) {
        return true
      }
      if (k.indexOf(key) >= 0 || key.indexOf(k) >= 0) {
        return true
      }
    }
    return false
  }

  /** 把历史里用户说过的话（奇数下标为 AI）拼成一段目标描述 */
  private composeUserText(input: PlanningDialogInput): string {
    const h: string[] = input.history !== undefined ? input.history : []
    const parts: string[] = []
    for (let i = 0; i < h.length; i += 2) {
      parts.push(h[i])
    }
    parts.push(input.userInput)
    return parts.join('；')
  }

  /**
   * 本地兜底任务生成：按用户原话命名（未知学科也直接用其说法），
   * 并可选地按「用户可用时间」等比缩放总时长（±15% 内，单条 5~120 分钟）。
   */
  private buildTasks(goal: string, availableMinutes: number): PlanTask[] {
    const g = goal.trim()
    if (g.length === 0) {
      return []
    }
    const tasks: PlanTask[] = []
    const add = (title: string, subject: string, min: number): void => {
      tasks.push(PlanTask.create(title, subject, min, tasks.length))
    }
    // 各科目**独立判断**（原来是 else-if 链：聊到"再加上英语"时永远只出第一科，
    // 追加的科目根本不会出现在候选里）。总量仍控制在 6 条以内，避免越聊越长。
    const hasMath = g.indexOf('高数') >= 0 || g.indexOf('数学') >= 0 || g.indexOf('极限') >= 0 || g.indexOf('导数') >= 0
    const hasEnglish = g.indexOf('英语') >= 0 || g.indexOf('单词') >= 0
    const hasPolitics = g.indexOf('政治') >= 0
    if (hasMath) {
      add('复习极限章节（定理 + 典型例题）', '高等数学', 30)
      add('完成极限练习题 10 道', '高等数学', 30)
      add('复习导数章节（求导法则）', '高等数学', 30)
      add('完成导数练习题 10 道', '高等数学', 30)
    }
    if (hasEnglish) {
      add('背诵 50 个核心单词', '英语', 25)
      add('精读 1 篇阅读理解', '英语', 35)
      add('整理今日生词与长难句', '英语', 20)
    }
    if (hasPolitics) {
      add('梳理马原第一章框架', '政治', 40)
      add('完成 20 道选择题', '政治', 30)
      add('错题复盘', '政治', 20)
    }
    if (!hasMath && !hasEnglish && !hasPolitics) {
      add(`梳理「${g}」的核心概念与框架`, '综合', 40)
      add(`完成「${g}」的专项练习`, '综合', 40)
      add('整理错题与笔记', '综合', 20)
    }
    const capped: PlanTask[] = []
    for (const t of tasks) {
      if (capped.length >= 6) {
        break
      }
      capped.push(t)
    }
    return this.scaleToAvailable(capped, availableMinutes)
  }

  private scaleToAvailable(tasks: PlanTask[], availableMinutes: number): PlanTask[] {
    if (availableMinutes <= 0 || tasks.length === 0) {
      return tasks
    }
    let sum = 0
    for (const t of tasks) {
      sum += t.estimatedDuration
    }
    if (sum <= 0) {
      return tasks
    }
    const factor = availableMinutes / sum
    const out: PlanTask[] = []
    let order = 0
    for (const t of tasks) {
      let m = Math.round(t.estimatedDuration * factor / 5) * 5
      if (m < 5) {
        m = 5
      }
      if (m > 120) {
        m = 120
      }
      out.push(PlanTask.create(t.title, t.subject, m, order))
      order += 1
    }
    return out
  }

  private async produceInsight(input: PlanningInput): Promise<PlanningResult> {
    await this.delay(500)
    const pref = input.preferredSubject !== undefined ? input.preferredSubject : '上午'
    return {
      tasks: [],
      summary: `你通常在 ${pref} 状态最好，建议把难点安排在精力高峰。`
    }
  }

  private async produceDecision(ctx: CompanionContext): Promise<CompanionDecision> {
    await this.delay(120)
    return this.buildDecisionSync(ctx)
  }

  /** 同步决策核心（供 InterventionEngine 在计时循环中同步调用） */
  buildDecisionSync(ctx: CompanionContext): CompanionDecision {
    const distracted = ctx.state === 'SLIGHTLY_DISTRACTED' || ctx.state === 'DISTRACTED'
    if (!distracted) {
      return { shouldIntervene: false, level: 'NONE', channel: 'quiet', message: '', action: 'continue' }
    }
    const sinceSec = ctx.sinceMs / 1000
    let level: 'LIGHT' | 'HEAVY' = 'LIGHT'
    if (ctx.state === 'DISTRACTED' && sinceSec >= 60) {
      level = 'HEAVY'
    }
    // §12 硬规则：无手表时 RED 用手机声音 + 屏幕选择，绝不假装震动
    const channel = level === 'HEAVY' && ctx.hasWatch ? 'watch-vibrate' : level === 'HEAVY' ? 'phone-sound' : 'screen-select'
    const message = this.wording(ctx.personality, level)
    const action = level === 'HEAVY' ? 'rest' : 'continue'
    return { shouldIntervene: true, level, channel, message, action }
  }

  /** 同步决策入口（InterventionEngine 调用，不触发网络/延迟） */
  decideSync(ctx: CompanionContext): CompanionDecision {
    return this.buildDecisionSync(ctx)
  }

  private async produceQAText(payload: QATextPayload): Promise<QAResp> {
    await this.delay(620)
    // 会话内历史 + 跨会话"之前问过什么" → 用于短追问的指代消解
    const ctx: string[] = []
    const history: QAMessage[] = payload.history !== undefined ? payload.history : []
    for (const m of history) {
      ctx.push(m.content)
    }
    if (payload.recentQuestions !== undefined) {
      for (const rq of payload.recentQuestions) {
        ctx.push(rq)
      }
    }
    return {
      answer: this.knowledgeAnswer(MockAIService.effectiveQuestion(payload.question, ctx.join(' '))),
      references: [],
      disclaimer: MockAIService.DISCLAIMER,
      scene: 'qa_text'
    }
  }

  /**
   * 指代消解：短追问（如"那它的适用条件呢"）本身没有主题词，
   * 仅在这类情况下把上文拼进来再匹配，避免正常提问被上下文串味。
   */
  private static effectiveQuestion(q: string, context: string): string {
    if (context.length === 0 || !MockAIService.isFollowUp(q)) {
      return q
    }
    return `${context} ${q}`
  }

  private static isFollowUp(q: string): boolean {
    if (q.length <= 12) {
      return true
    }
    return q.indexOf('它') >= 0 || q.indexOf('这个') >= 0 || q.indexOf('上面') >= 0 || q.indexOf('刚才') >= 0
  }

  private async produceQAImage(payload: QAImagePayload): Promise<QAResp> {
    await this.delay(720)
    const q = payload.question !== undefined ? payload.question : payload.imageRef
    return {
      answer: this.knowledgeAnswer(q),
      references: [],
      disclaimer: MockAIService.DISCLAIMER,
      scene: 'qa_image'
    }
  }

  private async produceReview(payload: ReviewPayload): Promise<ReviewData> {
    await this.delay(420)
    const s = payload.session
    const focusPct = Metrics.focusRatePercent(s)
    const completion = Metrics.completionRate(s)
    const studyMin = Math.round(Metrics.totalStudySec(s) / 60)
    let insight = `本次一共学习了 ${studyMin} 分钟，净专注率 ${focusPct}%。`
    let fatigueMin = 0
    for (const p of s.timeline) {
      if (p.state === 'DISTRACTED' || p.level < 45) {
        fatigueMin = p.minute
        break
      }
    }
    if (fatigueMin > 0) {
      insight += ` 大约第 ${fatigueMin} 分钟出现疲劳信号，下次可提前到 ${Math.max(25, fatigueMin - 5)} 分钟左右安排休息。`
    }
    const suggestions: string[] = ['每 45 分钟左右主动休息一次，起来喝口水、活动一下']
    if (completion < 90) {
      suggestions.push('下次把任务切得更小一些，完成感会更足')
    }
    if (Metrics.distractionRate(s) > 0.2) {
      suggestions.push('把手机放到视线之外，减少被动打断')
    }
    suggestions.push('练习题分两批完成，中间留出缓冲')
    return { insight, suggestions }
  }

  private async produceMemory(payload: MemoryPayload): Promise<MemoryDelta> {
    await this.delay(200)
    const finished = payload.recentSessions.filter((s) => Metrics.totalStudySec(s) > 0)
    const count = finished.length
    if (!Metrics.canShowProfile(count)) {
      // 样本不足：不更新五维，UI 显示"还在了解你"
      return { shouldUpdate: false, fields: {}, note: '样本不足，暂不更新画像' }
    }
    const d = Metrics.fiveDim(finished)
    const fields: ProfileFields = {
      efficiency: d.efficiency,
      concentration: d.concentration,
      stability: d.stability,
      execution: d.execution,
      antiDistraction: d.antiDistraction,
      averageFocusDuration: Math.round(finished.reduce((a, s) => a + s.focusDuration, 0) / finished.length / 60),
      focusThreshold: Metrics.focusThreshold(finished),
      bestFocusTime: Metrics.goldenWindow(finished),
      sampleCount: count
    }
    return { shouldUpdate: true, fields, note: '画像已根据最近会话更新' }
  }

  // ===================== 文案包（按人格 × 场景）=====================

  private wording(personality: string, level: 'LIGHT' | 'HEAVY'): string {
    const w = MockAIService.wordingFor(personality)
    if (level === 'HEAVY') {
      return w.heavy
    }
    return w.light
  }

  private static wordingFor(p: string): WordingLevel {
    switch (p) {
      case 'STRICT':
        return MockAIService.WORDING.STRICT
      case 'QUIET':
        return MockAIService.WORDING.QUIET
      case 'ADAPTIVE':
        return MockAIService.WORDING.ADAPTIVE
      default:
        return MockAIService.WORDING.GENTLE
    }
  }

  private knowledgeAnswer(q: string): string {
    if (q.indexOf('洛必达') >= 0) {
      return '洛必达法则适用于 0/0 或 ∞/∞ 型未定式：当分子分母都趋于 0（或都趋于无穷）时，可对分子、分母分别求导再取极限。使用前要确认满足可导与未定式条件，且求导后极限存在。'
    }
    if (q.indexOf('导数') >= 0 || q.indexOf('链式') >= 0) {
      return '链式法则是复合函数求导的核心：若 y = f(g(x))，则 y\' = f\'(g(x)) · g\'(x)。由外向内一层层求导再相乘。'
    }
    if (q.indexOf('极限') >= 0) {
      return '求极限先判断类型：能直接代入就先代入；出现 0/0 型，优先考虑等价无穷小替换、因式分解或洛必达法则。'
    }
    if (q.indexOf('状态不好') >= 0 || q.indexOf('累') >= 0 || q.indexOf('焦虑') >= 0) {
      return '状态有起伏很正常，不用逼自己。我们先从最小的一步开始：把今天要做的第一件事缩小到 15 分钟就能完成的量，好吗？'
    }
    if (q.indexOf('分心') >= 0 || q.indexOf('走神') >= 0) {
      return '容易分心通常不是意志力的问题，而是任务和节奏没匹配。我建议把任务切成更小的块，每 25-45 分钟安排一次短暂休息。'
    }
    return '这个问题我先记下来了。给你一个通用的切入方向：把它拆成「定义 → 适用条件 → 典型例题」三步——先确认定义，再看适用条件，最后挑一道典型例题走一遍。如果能把具体题目或卡住的那一步发给我，我可以帮你看得更准。'
  }

  // ===================== 5 服务接口实现（canonical）=====================

  async plan(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
    return this.runWithRetry<PlanningResult>('task_plan', req.requestId, () => this.producePlan(req.payload), this.defaultPlan())
  }

  async dialog(req: AIRequest<PlanningDialogInput>): Promise<AIResponse<PlanningDialogResult>> {
    return this.runWithRetry<PlanningDialogResult>('task_dialog', req.requestId, () => this.produceDialog(req.payload), this.defaultDialog())
  }

  async weeklyInsight(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
    return this.runWithRetry<PlanningResult>('planning', req.requestId, () => this.produceInsight(req.payload), this.defaultPlan())
  }

  async decide(req: AIRequest<CompanionContext>): Promise<AIResponse<CompanionDecision>> {
    return this.runWithRetry<CompanionDecision>('companion', req.requestId, () => this.produceDecision(req.payload), this.defaultCompanion())
  }

  async askText(req: AIRequest<QATextPayload>): Promise<AIResponse<QAResp>> {
    return this.runWithRetry<QAResp>('qa_text', req.requestId, () => this.produceQAText(req.payload), this.defaultQA('qa_text'))
  }

  async askImage(req: AIRequest<QAImagePayload>): Promise<AIResponse<QAResp>> {
    return this.runWithRetry<QAResp>('qa_image', req.requestId, () => this.produceQAImage(req.payload), this.defaultQA('qa_image'))
  }

  async generate(req: AIRequest<ReviewPayload>): Promise<AIResponse<ReviewData>> {
    return this.runWithRetry<ReviewData>('review', req.requestId, () => this.produceReview(req.payload), this.defaultReview())
  }

  async update(req: AIRequest<MemoryPayload>): Promise<AIResponse<MemoryDelta>> {
    return this.runWithRetry<MemoryDelta>('memory', req.requestId, () => this.produceMemory(req.payload), this.defaultMemory())
  }

  // ===================== 场景路由（PRD §14.1 / §14.2）=====================

  /** 将统一信封按 scene 转成对应 Agent 的具体请求（payload 类型随 scene 收窄） */
  private castReq<T>(req: AIRequest<AIPayload>): AIRequest<T> {
    return {
      requestId: req.requestId,
      scene: req.scene,
      userId: req.userId,
      sessionId: req.sessionId,
      payload: req.payload as T,
      context: req.context,
      options: req.options
    } as AIRequest<T>
  }

  /**
   * 统一场景路由：依据 req.scene 分发到 5 个 Agent 的具体方法。
   * 复用现有 runWithRetry（§14.5 超时/重试/兜底 + SchemaValidator），调用方零改动。
   */
  async dispatch(req: AIRequest<AIPayload>): Promise<AIResponse<AIResult>> {
    switch (req.scene) {
      case 'task_plan':
        return (await this.plan(this.castReq<PlanningInput>(req))) as Object as Promise<AIResponse<AIResult>>
      case 'task_dialog':
        return (await this.dialog(this.castReq<PlanningDialogInput>(req))) as Object as Promise<AIResponse<AIResult>>
      case 'planning':
        return (await this.weeklyInsight(this.castReq<PlanningInput>(req))) as Object as Promise<AIResponse<AIResult>>
      case 'companion':
        return (await this.decide(this.castReq<CompanionContext>(req))) as Object as Promise<AIResponse<AIResult>>
      case 'qa_text':
        return (await this.askText(this.castReq<QATextPayload>(req))) as Object as Promise<AIResponse<AIResult>>
      case 'qa_image':
        return (await this.askImage(this.castReq<QAImagePayload>(req))) as Object as Promise<AIResponse<AIResult>>
      case 'review':
        return (await this.generate(this.castReq<ReviewPayload>(req))) as Object as Promise<AIResponse<AIResult>>
      case 'memory':
        return (await this.update(this.castReq<MemoryPayload>(req))) as Object as Promise<AIResponse<AIResult>>
      default:
        // 穷尽守卫（场景为封闭联合，实际不可达）
        return this.fallback<AIResult>(req.scene, req.requestId, {} as AIResult)
    }
  }

  // ===================== 兼容垫片便捷方法（供现有 AppStore/UI 调用）=====================

  private toTask(p: PlanTask): Task {
    const t = new Task()
    t.id = p.id.length > 0 ? p.id : IdUtils.uuid()
    t.title = p.title
    t.subject = p.subject
    t.estimatedDuration = p.estimatedDuration
    t.status = p.status
    t.done = p.done
    t.sortOrder = p.sortOrder
    t.createdAt = Date.now()
    return t
  }

  /** 旧 AIService.planTasks 等价实现 */
  async planTasks(input: string): Promise<Task[]> {
    const r = await this.plan({
      requestId: IdUtils.uuid(),
      scene: 'task_plan',
      userId: 'local',
      payload: { goal: input }
    })
    const tasks = (r.data?.tasks ?? []).map((p) => this.toTask(p))
    return tasks
  }

  async chat(input: string): Promise<string> {
    return this.knowledgeAnswer(input)
  }

  async answerQuestion(q: string): Promise<string> {
    return this.knowledgeAnswer(q)
  }

  async reviewInsight(session: FocusSession, report?: StudyReport): Promise<string> {
    const r = await this.generate({
      requestId: IdUtils.uuid(),
      scene: 'review',
      userId: 'local',
      payload: { session, questions: [] }
    })
    return r.data?.insight ?? '本次学习已完成，继续加油。'
  }

  reviewSuggestions(session: FocusSession, report?: StudyReport): string[] {
    const r = Metrics.focusRatePercent(session)
    const suggestions: string[] = ['每 45 分钟左右主动休息一次，起来活动一下']
    if (r < 90) {
      suggestions.push('下次把任务切得更小一些，完成感会更足')
    }
    if (Metrics.distractionRate(session) > 0.2) {
      suggestions.push('把手机放到视线之外，减少被动打断')
    }
    return suggestions
  }

  /** 长期画像更新：统一走 Metrics（§3 指标唯一事实源） */
  updateProfile(profile: FocusProfile, sessions: FocusSession[]): FocusProfile {
    const finished = sessions.filter((s) => Metrics.totalStudySec(s) > 0)
    profile.sampleCount = finished.length
    profile.recentConcentrations = finished.map((s) => Metrics.focusRatePercent(s))
    profile.recentDistractionRates = finished.map((s) => Metrics.distractionRate(s))
    if (Metrics.canShowProfile(profile.sampleCount)) {
      const d = Metrics.fiveDim(finished)
      profile.efficiency = d.efficiency
      profile.concentration = d.concentration
      profile.stability = d.stability
      profile.execution = d.execution
      profile.antiDistraction = d.antiDistraction
      profile.averageFocusDuration = Math.round(finished.reduce((a, s) => a + s.focusDuration, 0) / finished.length / 60)
      profile.focusThreshold = Metrics.focusThreshold(finished)
      profile.bestFocusTime = Metrics.goldenWindow(finished)
      // 近 30 天每日净专注分钟（复用长期复盘的同一份聚合，§3 指标唯一事实源）。
      // 此前这个字段全项目零赋值，画像页的「专注成长趋势」恒为 0 min → 0 min
      const noTasks: Task[] = []
      profile.monthlyTrend = Metrics.last30DaysSummary(finished, noTasks, Date.now()).trend
    } else {
      profile.efficiency = 0
      profile.concentration = 0
      profile.stability = 0
      profile.execution = 0
      profile.antiDistraction = 0
    }
    profile.updatedAt = Date.now()
    return profile
  }

  companionIntro(): string {
    return '你好，我是你的 AI 考伴小伴，不是真人，但会一直陪你。'
  }

  openPlanning(): string {
    return '今天想学点什么？先告诉我一个大概的目标，我帮你拆成几个具体的小任务。'
  }

  /** 规划页开场白（AI 输出，页面不硬编码文案，硬规则 §1） */
  planningIntro(): string {
    return '你好，我是 iKnow，你的专属 AI 学习伙伴。今天准备好来学习什么了吗？'
  }

  /**
   * 答疑页开场白。
   * 用户要求：**短**，大意就是"有问题就问小伴，小伴会一直陪着你"，
   * 不要出现当前专注任务之类的信息，也不要列"可以怎么问"的清单。
   */
  qaIntro(): string {
    return '有问题就问小伴，小伴会一直陪着你。'
  }

  /**
   * 生成规划后的时间安排分析（AI 输出，硬规则 §1：动态文案不得写死在页面）。
   * 依据任务科目与预计时长给出分科安排、休息建议与建议总时长。
   */
  analyzePlan(tasks: Task[]): string {
    if (tasks.length === 0) {
      return '还没有可安排的任务，先告诉我你的学习目标吧。'
    }
    let total = 0
    const map: Map<string, number> = new Map<string, number>()
    for (const t of tasks) {
      total += t.estimatedDuration
      const cur = map.get(t.subject)
      map.set(t.subject, (cur === undefined ? 0 : cur) + t.estimatedDuration)
    }
    const parts: string[] = []
    map.forEach((min: number, subject: string) => {
      parts.push(`${subject} ${min} 分钟`)
    })
    const restMin = Math.max(10, Math.round(total / 6))
    return `我建议这样安排：${parts.join('、')}，合计 ${total} 分钟。` +
      `中途每 30-45 分钟休息 5-10 分钟，避免长时间近距离用眼导致疲劳，` +
      `所以建议总时长约 ${total + restMin} 分钟。`
  }

  /**
   * 单日复盘洞察 —— **只讲这一天**，每条结论自带数字；能与本人基线对比时带上对比基准。
   *
   * 与长期分析严格区分：不引用近 30 天趋势、不引用五维画像。
   * 结构量与基线口径都在 `Metrics`（`sessionStructure` / `baseline`），本层只把数字组织成人话 ——
   * 原实现只有 `≥80 / ≥60 / 其它` 三档，同一档里所有日子输出同一句。
   */
  dayInsight(dayLabel: string, day: DaySummary, baseline: Baseline): string {
    if (!day.hasData) {
      return `${dayLabel}没有专注记录，所以这一天没有可分析的内容。`
    }
    const st = day.structure
    const parts: string[] = []
    const main = day.sessionCount > 1 ? `当天最长的一次（当天共 ${day.sessionCount} 次）` : '这一次'

    // ① 进入状态要多久
    let first = `${dayLabel}累计学习 ${TimeUtils.formatSec(day.studySeconds)}，平均专注率 ${day.focusRate}%`
    if (st.timeToFocus >= 0) {
      first += `，${main}进入状态用了 ${st.timeToFocus} 分钟`
      if (baseline.ready && baseline.timeToFocus >= 0) {
        first += `（你的常态约 ${baseline.timeToFocus} 分钟）`
      }
    }
    parts.push(`${first}。`)

    // ② 能连续专注多久
    if (st.longestRun > 0) {
      let line = `最长一段连续专注 ${st.longestRun} 分钟`
      if (baseline.ready && baseline.longestRun > 0) {
        const d = st.longestRun - baseline.longestRun
        if (d <= -5) {
          line += `，比你的常态（${baseline.longestRun} 分钟）短了 ${Math.abs(d)} 分钟`
        } else if (d >= 5) {
          line += `，比你的常态（${baseline.longestRun} 分钟）长了 ${d} 分钟`
        } else {
          line += `，与你的常态（${baseline.longestRun} 分钟）基本持平`
        }
      }
      parts.push(`${line}。`)
    }

    // ②' 当天状态最好的一段（`Metrics.bestPeriodOfDay` 现算的真实时钟区间）
    if (day.bestPeriod.length > 0) {
      parts.push(`全天状态最好的一段在 ${day.bestPeriod}。`)
    }

    // ③ 被打断几次、回来要多久（recoveryMedian 是最可干预的一个量）
    if (st.bouts > 0) {
      let line = `被打断 ${st.bouts} 次`
      if (st.recoveryMedian >= 0) {
        line += `，平均 ${st.recoveryMedian} 分钟才回到专注`
        if (baseline.ready && baseline.recoveryMedian >= 0 && st.recoveryMedian > baseline.recoveryMedian) {
          line += `（你平时约 ${baseline.recoveryMedian} 分钟）`
        }
      }
      parts.push(`${line}。`)
    } else {
      parts.push('全程没有出现分心段。')
    }

    // ④ 疲劳拐点：后段掉得明显才说（比"第一个 level<45"稳得多）
    if (st.tailDrop <= -10) {
      parts.push(`后半段平均专注等级比前半段低了 ${Math.abs(st.tailDrop)} 分，疲劳出现得偏早。`)
    }

    // ⑤ 没法对比时如实说明还差几次，不做跨天结论
    if (!baseline.ready) {
      parts.push(`再完成 ${baseline.needMore} 次专注，我就能拿这一天的数字和你的常态做对比。`)
    }
    return parts.join('')
  }

  /**
   * 单日复盘建议 —— 由**当天结构指标与基线的差值**派生，最多 3 条，优先级（C5）：
   * 分心次数 → 恢复耗时 → 疲劳拐点 → 单段长度 → 全部达标时只给 1 条保持建议。
   * 没有任何无条件追加的模板句：不满足条件就不出这一条。
   */
  daySuggestions(day: DaySummary, baseline: Baseline): string[] {
    const out: string[] = []
    if (!day.hasData || day.studySeconds <= 0) {
      return ['这一天没有有效学习时长，先设一个 25 分钟的小目标开始']
    }
    const st = day.structure
    const ready = baseline.ready

    // ① 被打断得比平时多 → 先找分心源
    if (st.bouts >= 3 && (!ready || st.bouts > baseline.bouts)) {
      const target = ready && baseline.bouts >= 0 ? Math.round(baseline.bouts) : 2
      out.push(`被打断 ${st.bouts} 次，先把最容易打断你的东西移出视线（手机、消息提醒），明天争取压到 ${target} 次以内`)
    }
    // ② 被打断后回不来 → 缩短单段 + 主动休息
    if (out.length < 3 && st.recoveryMedian >= 3 && (!ready || st.recoveryMedian > baseline.recoveryMedian)) {
      out.push(`平均要 ${st.recoveryMedian} 分钟才能回到专注，把单段时长压到 25 分钟、每段之间主动起身一次，比硬撑更划算`)
    }
    // ③ 后半段明显掉下来 → 疲劳拐点偏早
    if (out.length < 3 && st.tailDrop <= -10) {
      out.push(`后半段专注等级掉了 ${Math.abs(st.tailDrop)} 分，疲劳来得偏早：把最长的那一段拆成两段，中间留 5~10 分钟真正的休息`)
    }
    // ④ 单段比平时短 → 先把"能连续专注多久"拉起来
    if (out.length < 3 && ready && baseline.longestRun > 0 && st.longestRun > 0
      && st.longestRun * 1.2 < baseline.longestRun) {
      out.push(`最长连续专注 ${st.longestRun} 分钟，比你的常态（${baseline.longestRun} 分钟）短，明天先保证一整段不受打扰的 25 分钟`)
    }
    // ⑤ 全部达标：只给 1 条保持建议
    if (out.length === 0) {
      out.push(ready
        ? `这一天的节奏与你的常态持平或更好（最长连续 ${st.longestRun} 分钟、被打断 ${st.bouts} 次），明天沿用同样的单段时长即可`
        : `这一天完成了 ${TimeUtils.formatSec(day.studySeconds)}、最长连续专注 ${st.longestRun} 分钟，先把这个节奏保持住`)
    }
    return out.slice(0, 3)
  }

  /** 规划对话无有效回复时的承接语（AI 文案，硬规则 §1：不写死在页面） */
  planningHold(): string {
    return '我在听，再多说一点你的安排吧，我好帮你把时间和任务都排清楚。'
  }

  /**
   * 首页语录（离线兜底池）。
   *
   * 用户要求：每次打开 App 都换一句、语录库别太小、语气是**鼓励**而不是说教。
   * 所以这里不是"一种目标一句话"，而是一个**池子**：通用池 + 目标专属池，
   * 用时间做种子轮转取句，并避开上次展示过的那句。
   * 网关可用时由 `GatewayAIService.slogan()` 生成更新的，这里保证"断网也不空、也不重"。
   *
   * @param avoid 上一次展示过的句子（空串表示不避让）
   */
  slogan(goalType: string, avoid: string): string {
    const pool: string[] = []
    for (const s of GENERAL_SLOGANS) {
      pool.push(s)
    }
    for (const s of goalSlogans(goalType)) {
      pool.push(s)
    }
    if (pool.length === 0) {
      return '定个目标，稳步推进'
    }
    // 用秒级时间做种子轮转：同一次会话内稳定，跨次启动基本必换
    const idx = Math.floor(Date.now() / 1000) % pool.length
    let pick = pool[idx]
    if (pick === avoid) {
      for (const c of pool) {
        if (c !== avoid) {
          pick = c
          break
        }
      }
    }
    return pick
  }

  nextPlanningQuestion(step: number): string {
    if (step === 0) {
      return '好的，大概有多少时间可以学习呢？'
    }
    if (step === 1) {
      return '有没有特别想优先完成的部分？'
    }
    return '好的，我帮你安排一下。'
  }

  proactive(goldenTime: string): string {
    return `你通常在 ${goldenTime} 专注效率最高。要不要现在开始一个 45 分钟的专注？`
  }

  /**
   * 长期分析：**只陈述数据里真实存在的事实**，不再无条件宣称"效率在稳步提升"。
   * 样本不足时如实说明，不编造趋势。
   */
  longTermAnalysis(profile: FocusProfile, hardestSubject: string, trend: Trend7v7, streak: Streaks): string {
    if (profile.sampleCount < Metrics.MIN_SAMPLES) {
      const need = Metrics.MIN_SAMPLES - profile.sampleCount
      return `目前只累计到 ${profile.sampleCount} 次专注，还不足以做长期分析 —— 再完成 ${need} 次，我会按你的真实数据给结论。`
    }
    const parts: string[] = []
    // 基准句：累计口径 + 近 7 天对比（窗口数据不足时如实说明，不编趋势）
    let base = `累计 ${profile.sampleCount} 次专注，平均单次净专注 ${profile.averageFocusDuration} 分钟`
    if (trend.ready) {
      base += `；近 7 天净专注率 ${trend.curRate}%（前 7 天 ${trend.prevRate}%，${trend.rateTrend}），`
        + `日均净专注 ${trend.curAvgMinutes} 分钟（前 7 天 ${trend.prevAvgMinutes} 分钟，${trend.avgTrend}）`
    } else {
      base += '；近 7 天或前 7 天的数据还不完整，暂不比较趋势'
    }
    parts.push(`${base}。`)

    // ① 主要杠杆动作：只给一条，按优先级取第一个成立的（每条都带数字）
    let lever = ''
    if (trend.ready && trend.rateTrend === '下降') {
      lever = `近 7 天净专注率比前 7 天低了 ${trend.prevRate - trend.curRate} 个百分点，`
        + `先把单段压到 ${profile.focusThreshold} 分钟、学习时把手机放到视线之外，再观察一周`
    } else if (trend.ready && trend.avgTrend === '下降') {
      lever = `近 7 天日均净专注比前 7 天少了 ${trend.prevAvgMinutes - trend.curAvgMinutes} 分钟，`
        + '先把每天的第一段 25 分钟固定下来，不追求总量'
    } else if (hardestSubject.length > 0) {
      const slot = profile.bestFocusTime.length > 0 ? profile.bestFocusTime : '你状态最好的时段'
      lever = `按完成率看「${hardestSubject}」推进得最慢，把它安排到 ${slot}`
        + `（单段不超过 ${profile.focusThreshold} 分钟）`
    } else {
      lever = `单段控制在 ${profile.focusThreshold} 分钟以内（当前平均单次 ${profile.averageFocusDuration} 分钟），到点就起身活动一次`
    }
    parts.push(`${lever}。`)

    // ② 保持动作：只给一条
    let keep = ''
    if (streak.currentStreak >= 2) {
      keep = `已经连续学习 ${streak.currentStreak} 天，保持住这个节奏`
    } else if (streak.longestGapDays >= 2) {
      keep = `近 30 天最长有连续 ${streak.longestGapDays} 天没学（${streak.studiedDays} 天有记录），先保证每天至少一段 25 分钟`
    } else {
      keep = `近 30 天有 ${streak.studiedDays} 天留下了专注记录，继续按现在的节奏走`
    }
    parts.push(`${keep}。`)
    return parts.join('')
  }
}
