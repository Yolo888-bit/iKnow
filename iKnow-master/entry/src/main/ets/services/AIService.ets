import { Task } from '../models/Task'
import { ObservationRecord } from '../models/WatchSignal'
import { FocusSession } from '../models/FocusSession'
import { StudyReport } from '../models/StudyReport'
import { FocusProfile } from '../models/FocusProfile'
import { AIPersonality } from '../models/Enums'
import { MockAIService } from './ai/MockAIService'
import { GatewayAIService } from './ai/GatewayAIService'
import { BridgeConfig } from './ai/BridgeConfig'
import { StorageKey } from '../common/Constants'
import { AIPayload, AIResult, AIRequest, AIResponse, AIScene } from './ai/AIService'
import { PlanningInput, PlanningResult, PlanningDialogInput, PlanningDialogResult } from './ai/PlanningService'
import { QATextPayload, QAResp } from './ai/QAService'
import { IdUtils } from '../utils/IdUtils'
import { DaySummary, Baseline, Trend7v7, Streaks } from './Metrics'

/**
 * AI 服务兼容垫片（PRD §13 / 硬规则 §1）
 *
 * 历史 UI / AppStore 通过 AIService.getInstance() 调用 AI 能力。本类作为薄委派层，
 * 全部逻辑下沉到 services/ai/MockAIService（实现 5 个独立接口：QA / Companion /
 * Review / Planning / Memory）。未来接入真实网关时，仅需把内部实例换成
 * GatewayAIService，UI 与调用方零改动。
 *
 * 人格：有温度、有陪伴感，但不假装真人；不指责、不说教、不制造焦虑。
 */
export class AIService {
  private static inst: AIService | null = null
  private mock: MockAIService = MockAIService.getInstance()
  private gateway: GatewayAIService = GatewayAIService.getInstance()
  /** 是否启用真实网关；默认 false 走 Mock（硬规则 §8：替换时不改 UI） */
  private useGateway: boolean = false
  /** 上一次答疑的来源（GATEWAY / MOCK），用于 UI 如实标注 */
  private lastQaSource: string = 'MOCK'

  static getInstance(): AIService {
    if (AIService.inst === null) {
      AIService.inst = new AIService()
    }
    return AIService.inst
  }

  private constructor() {
    this.mock = MockAIService.getInstance()
    this.gateway = GatewayAIService.getInstance()
    // 按 BridgeConfig 决定是否启用真实大模型（默认开启；若未配置 Key 会自动回退 Mock）
    this.setGatewayEnabled(BridgeConfig.useGateway)
  }

  setPersonality(p: AIPersonality): void {
    this.mock.setPersonality(p)
    this.gateway.setPersonality(p)
  }

  /**
   * 切换真实网关（默认 false，强制 Mock）。
   * 开启后 dispatch 会先尝试网关，失败/未配置时自动回退 Mock，核心功能不中断。
   */
  setGatewayEnabled(on: boolean): void {
    this.gateway.enabled = on
    this.useGateway = on
  }

  /**
   * 场景路由（PRD §14.1 / §14.2）：依据 req.scene 分发到对应 Agent。
   * 开启网关时先试 Gateway，失败回退 Mock（AI 失败不影响核心计时/感知，硬规则 §4 / §14.5）。
   */
  async dispatch(req: AIRequest<AIPayload>): Promise<AIResponse<AIResult>> {
    if (this.useGateway) {
      const r: AIResponse<AIResult> = await this.gateway.dispatch(req)
      if (r.ok) {
        return r
      }
      // 网关未配置/失败：回退 Mock，保证核心功能不中断。
      // 必须显式标记 fallback：Mock 同样返回 ok:true，不标就无法区分"大模型回答"与"本地模板回答"
      const fb: AIResponse<AIResult> = await this.mock.dispatch(req)
      fb.fallback = true
      return fb
    }
    const local: AIResponse<AIResult> = await this.mock.dispatch(req)
    local.fallback = true
    return local
  }

  /**
   * 便捷入口：仅传 scene + payload 即可按场景调用对应 AI。
   * 自动补全 requestId / userId，并复用 dispatch 的网关回退逻辑。
   *
   * 示例：
   *   const r = await AIService.getInstance().callScene('qa_text', { question: '洛必达怎么用？' })
   *   if (r.ok) { const ans = (r.data as QAResp).answer }
   */
  async callScene(scene: AIScene, payload: AIPayload, userId: string = 'local'): Promise<AIResponse<AIResult>> {
    const req: AIRequest<AIPayload> = {
      requestId: IdUtils.uuid(),
      scene: scene,
      userId: userId,
      payload: payload
    }
    return await this.dispatch(req)
  }

  getPersonality(): AIPersonality {
    return this.mock.getPersonality() as AIPersonality
  }

  /** 考伴固定开场（身份透明必须保留） */
  companionIntro(): string {
    return this.mock.companionIntro()
  }

  /** 对话式规划开场白 */
  openPlanning(): string {
    return this.mock.openPlanning()
  }

  /** 规划页开场白（按时长/目标生成，页面不硬编码） */
  planningIntro(): string {
    return this.mock.planningIntro()
  }

  /** 答疑页开场白（AI 文案，硬规则 §1：动态文案不写死在页面里） */
  qaIntro(): string {
    return this.mock.qaIntro()
  }

  /** 规划对话没有拿到有效回复时的承接语（AI 文案，硬规则 §1） */
  planningHold(): string {
    return this.mock.planningHold()
  }

  /**
   * 贴合目标的励志标语（首页顶部）。
   * 先用本地文案表兜底保证不为空，再异步用大模型替换；结果按目标缓存在 AppStorage，
   * 目标变更（GoalSetup 保存）时置空重新生成。
   */
  localSlogan(goalType: string): string {
    return this.mock.slogan(goalType, '')
  }

  /**
   * 首页语录。
   *
   * 缓存放在 AppStorage（**进程内**）：所以每次启动 App 都会重新生成一句，
   * 这正是用户要的"每次登录后都展示新的语录"；同一次启动内只生成一次，不会反复打网关。
   *
   * @param avoid 上次启动真实展示过的那句，尽量别重复（由调用方从 KV 读出）
   */
  async slogan(goalType: string, daysLeft: number, avoid: string): Promise<string> {
    if (goalType.length === 0) {
      return ''
    }
    const cached: string | undefined = AppStorage.get<string>(StorageKey.GOAL_SLOGAN)
    if (cached !== undefined && cached.length > 0) {
      return cached
    }
    let text = ''
    if (this.useGateway) {
      text = await this.gateway.slogan(goalType, daysLeft, avoid)
    }
    if (text.length === 0 || text === avoid) {
      text = this.mock.slogan(goalType, avoid)
    }
    AppStorage.setOrCreate<string>(StorageKey.GOAL_SLOGAN, text)
    return text
  }

  /** 规划完成后的时间安排分析（AI 输出，硬规则 §1） */
  analyzePlan(tasks: Task[]): string {
    return this.mock.analyzePlan(tasks)
  }

  /** 单日复盘 AI 洞察（AI 输出，硬规则 §1） */
  dayInsight(dayLabel: string, day: DaySummary, baseline: Baseline): string {
    return this.mock.dayInsight(dayLabel, day, baseline)
  }

  /** 单日复盘优化建议（AI 输出，硬规则 §1） */
  daySuggestions(day: DaySummary, baseline: Baseline): string[] {
    return this.mock.daySuggestions(day, baseline)
  }

  /**
   * 规划场景（task_plan）强类型封装：按目标生成结构化任务。
   * 内部走 dispatch 场景路由，此处收敛联合类型，调用方无需做类型断言。
   */
  async planByScene(input: PlanningInput): Promise<PlanningResult> {
    const r = await this.callScene('task_plan', input)
    const d: AIResult | undefined = r.data
    if (r.ok && d !== undefined) {
      return d as Object as PlanningResult
    }
    return { tasks: [], summary: '' }
  }

  /** 对话式规划追问（task_dialog）强类型封装 */
  async dialogByScene(input: PlanningDialogInput): Promise<PlanningDialogResult> {
    const r = await this.callScene('task_dialog', input)
    const d: AIResult | undefined = r.data
    if (r.ok && d !== undefined) {
      return d as Object as PlanningDialogResult
    }
    return { reply: '', done: false }
  }

  /** 对话式规划的追问 */
  nextPlanningQuestion(step: number): string {
    return this.mock.nextPlanningQuestion(step)
  }

  /** 根据目标文本生成结构化任务（委托 MockAIService） */
  async planTasks(input: string): Promise<Task[]> {
    return await this.mock.planTasks(input)
  }

  /** 通用考伴对话 */
  async chat(input: string): Promise<string> {
    return await this.mock.chat(input)
  }

  /**
   * 答疑：走场景路由（qa_text）—— 网关可用时走大模型，未配置或失败时自动回退 Mock，
   * 并携带会话内 history 与跨会话"之前问过什么"。返回纯文本答案。
   */
  async answerQuestion(payload: QATextPayload, userId: string = 'local'): Promise<string> {
    const r = await this.callScene('qa_text', payload, userId)
    if (r.ok && r.data !== undefined) {
      const resp = r.data as Object as QAResp
      if (resp.answer !== undefined && resp.answer.length > 0) {
        // 来源以 fallback 标记为准：未配 Key 或网关失败时 dispatch 返回的 Mock 结果也是 ok:true，
        // 只看 ok 会把本地模板标成「大模型回答」（第四轮加的诚实标注会自己变成假成功）
        this.lastQaSource = r.fallback === true ? 'MOCK' : 'GATEWAY'
        return resp.answer
      }
    }
    this.lastQaSource = 'MOCK'
    return await this.mock.answerQuestion(payload.question)
  }

  /** 上一次答疑的来源：'GATEWAY' = 走大模型，'MOCK' = 本地模板（UI 据此如实标注） */
  getLastQaSource(): string {
    return this.lastQaSource
  }

  /** 是否已配置真实网关 —— 决定用真实多模态识别还是模拟识别 */
  isGatewayReady(): boolean {
    return this.useGateway && BridgeConfig.AI_API_KEY.length > 0
  }

  /**
   * 流式答疑：`onDelta` 逐段把文本推给 UI。
   * 网关不可用或流失败时自动回退非流式（整段一次性回调），保证 UI 一定拿到内容。
   */
  async answerQuestionStream(
    payload: QATextPayload,
    userId: string,
    onDelta: (t: string) => void
  ): Promise<string> {
    if (this.useGateway) {
      const streamed = await this.gateway.streamQA(payload, onDelta)
      if (streamed.length > 0) {
        this.lastQaSource = 'GATEWAY'
        return streamed
      }
    }
    const full = await this.answerQuestion(payload, userId)
    if (full.length > 0) {
      onDelta(full)
    }
    return full
  }

  /**
   * 流式规划对话：reply 逐段上屏，结构化结果（done / tasks）在流结束后返回。
   * 网关不可用时回退非流式。
   */
  async dialogStream(input: PlanningDialogInput, onDelta: (t: string) => void): Promise<PlanningDialogResult> {
    if (this.useGateway) {
      const r = await this.gateway.streamDialog(input, onDelta)
      if (r !== null && r.reply.length > 0) {
        return r
      }
    }
    const fallback = await this.dialogByScene(input)
    if (fallback.reply.length > 0) {
      onDelta(fallback.reply)
    }
    return fallback
  }

  /**
   * 真实多模态识别（触发时抓拍的帧 → 可观察状态）。
   * 未配置网关时返回 null：由调用方选择模拟输入源或如实记为「无法判断」。
   */
  async recognizeActivity(frames: ArrayBuffer[]): Promise<ObservationRecord | null> {
    if (!this.isGatewayReady()) {
      return null
    }
    return await this.gateway.recognizeActivity(frames)
  }

  /** 复盘洞察文案（委托 MockAIService，指标统一走 Metrics） */
  async reviewInsight(session: FocusSession, report: StudyReport): Promise<string> {
    return await this.mock.reviewInsight(session, report)
  }

  /** 复盘优化建议（指标统一走 Metrics） */
  reviewSuggestions(session: FocusSession, report: StudyReport): string[] {
    return this.mock.reviewSuggestions(session, report)
  }

  /** 长期画像更新（委托 MockAIService，统一走 Metrics §3/§6） */
  updateProfile(profile: FocusProfile, sessions: FocusSession[]): FocusProfile {
    return this.mock.updateProfile(profile, sessions)
  }

  /** 首页主动建议文案 */
  proactive(goldenTime: string): string {
    return this.mock.proactive(goldenTime)
  }

  /** 长期分析文案 */
  longTermAnalysis(profile: FocusProfile, hardestSubject: string, trend: Trend7v7, streak: Streaks): string {
    return this.mock.longTermAnalysis(profile, hardestSubject, trend, streak)
  }
}
