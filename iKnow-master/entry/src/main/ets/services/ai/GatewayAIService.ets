import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ObservationRecord } from '../../models/WatchSignal'
import { AIService, AIScene, AIRequest, AIResponse, AIError, AIPayload, AIResult } from './AIService'
import { QATextPayload, QAImagePayload, QAResp, QAMessage, QA_DISCLAIMER } from './QAService'
import { CompanionContext, CompanionDecision } from './CompanionService'
import { ReviewPayload, ReviewData } from './ReviewService'
import {
  PlanningInput,
  PlanningResult,
  PlanningDialogInput,
  PlanningDialogResult,
  PLANNING_SCHEMA_VERSION
} from './PlanningService'
import { MemoryPayload, MemoryDelta } from './MemoryService'
import { BridgeConfig } from './BridgeConfig'
import { Prompts } from './Prompts'
import { SchemaValidator } from './SchemaValidator'
import { PlanTask } from '../../models/StudyPlan'

const DOMAIN = 0x0000
const TAG = 'iKnow.Gateway'

/** OpenAI 兼容请求体（PRD §15.2） */
/** 多模态消息内容段（文本 / 图片），用于"触发时抓拍 → 云端识别在做什么" */
interface ContentPart {
  type: string
  text?: string
  image_url?: ImageUrlPart
}

interface ImageUrlPart {
  url: string
}

interface ChatMessage {
  role: string
  /** 纯文本场景传 string；多模态场景传内容段数组（OpenAI 兼容格式） */
  content: string | ContentPart[]
}

interface GatewayResponseFormat {
  type: string
}

interface GatewayRequestBody {
  model: string
  messages: ChatMessage[]
  response_format?: GatewayResponseFormat
  temperature: number
  max_tokens: number
}

interface GatewayHeaders {
  'Content-Type': string
  'Authorization': string
}

/** chat/completions 响应（字段可选，便于运行时防御） */
interface ChatRespMessage {
  content?: string
}

interface ChatRespChoice {
  message?: ChatRespMessage
}

interface ChatCompletion {
  choices?: ChatRespChoice[]
}

/** 大模型原始输出（尚未映射为领域模型） */
interface RawTask {
  title?: string
  subject?: string
  estimated_minutes?: number
}

interface RawPlan {
  summary?: string
  tasks?: RawTask[]
}

interface RawDialog {
  reply?: string
  done?: boolean
  tasks?: RawTask[]
}

interface RawQA {
  answer?: string
  references?: string[]
}

/** 多模态识别的原始返回（只允许可观察状态） */
interface RawActivity {
  activity?: string
  handheld?: boolean
  facingDesk?: boolean
  confidence?: number
  evidence?: string
}

/**
 * 真实大模型网关（PRD §13 / §14 / §15.2）
 *
 *  - 用 `@kit.NetworkKit` 的 http 直接调用兼容 OpenAI 协议的 chat/completions。
 *  - 已开放网关的场景：`task_plan` / `task_dialog`（AI 规划对话与任务拆解）。
 *    其余场景仍返回 ok:false，由门面自动回退 MockAIService（行为与之前一致）。
 *  - 严格遵循硬规则：页面不直接调 LLM（§1）、输出过 SchemaValidator（§2/§14.2）、
 *    失败时回退不阻塞核心计时（§4/§14.5）。
 *  - ⚠️ Key 来源见 BridgeConfig 顶部说明：本地联调阶段直连，上线前应换成后端网关短期 token。
 */
export class GatewayAIService implements AIService {
  private static inst: GatewayAIService | null = null
  /** 是否启用真实网关（默认 false，由 AIService 门面按 BridgeConfig 设置） */
  enabled: boolean = false
  private personality: string = 'GENTLE'

  static getInstance(): GatewayAIService {
    if (GatewayAIService.inst === null) {
      GatewayAIService.inst = new GatewayAIService()
    }
    return GatewayAIService.inst
  }

  setPersonality(p: string): void {
    this.personality = p
  }

  getPersonality(): string {
    return this.personality
  }

  // ===================== 信封构造 =====================

  private static versionFor(scene: AIScene): string {
    if (scene === 'task_plan' || scene === 'task_dialog' || scene === 'planning') {
      return PLANNING_SCHEMA_VERSION
    }
    return 'gateway@1'
  }

  private fail<T>(scene: AIScene, requestId: string, code: string, message: string): AIResponse<T> {
    const err: AIError = { code: code, message: message, retryable: code !== 'not_configured' }
    return { requestId: requestId, ok: false, schemaVersion: GatewayAIService.versionFor(scene), error: err }
  }

  private ok<T>(scene: AIScene, requestId: string, data: T, latencyMs: number): AIResponse<T> {
    return {
      requestId: requestId,
      ok: true,
      schemaVersion: GatewayAIService.versionFor(scene),
      data: data,
      usage: { promptTokens: 0, completionTokens: 0, latencyMs: latencyMs }
    }
  }

  /** 网关是否可用（已启用 + 已配置 Key） */
  private isReady(): boolean {
    return this.enabled && BridgeConfig.AI_API_KEY.length > 0
  }

  // ===================== 五个服务接口（未开放场景一律回退 Mock）=====================

  async plan(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
    if (!this.isReady()) {
      return this.fail<PlanningResult>('task_plan', req.requestId, 'not_configured', 'Gateway AI 未配置')
    }
    return await this.runPlan(req.requestId, req.payload)
  }

  async dialog(req: AIRequest<PlanningDialogInput>): Promise<AIResponse<PlanningDialogResult>> {
    if (!this.isReady()) {
      return this.fail<PlanningDialogResult>('task_dialog', req.requestId, 'not_configured', 'Gateway AI 未配置')
    }
    return await this.runDialog(req.requestId, req.payload)
  }

  async weeklyInsight(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
    return this.fail<PlanningResult>('planning', req.requestId, 'not_implemented', 'planning 场景暂未开放网关')
  }

  async decide(req: AIRequest<CompanionContext>): Promise<AIResponse<CompanionDecision>> {
    return this.fail<CompanionDecision>('companion', req.requestId, 'not_implemented', 'companion 场景暂未开放网关')
  }

  async askText(req: AIRequest<QATextPayload>): Promise<AIResponse<QAResp>> {
    if (!this.isReady()) {
      return this.fail<QAResp>('qa_text', req.requestId, 'not_configured', 'Gateway AI 未配置')
    }
    return await this.runQA(req.requestId, req.payload)
  }

  async askImage(req: AIRequest<QAImagePayload>): Promise<AIResponse<QAResp>> {
    return this.fail<QAResp>('qa_image', req.requestId, 'not_implemented', 'qa_image 场景暂未开放网关')
  }

  async generate(req: AIRequest<ReviewPayload>): Promise<AIResponse<ReviewData>> {
    return this.fail<ReviewData>('review', req.requestId, 'not_implemented', 'review 场景暂未开放网关')
  }

  async update(req: AIRequest<MemoryPayload>): Promise<AIResponse<MemoryDelta>> {
    return this.fail<MemoryDelta>('memory', req.requestId, 'not_implemented', 'memory 场景暂未开放网关')
  }

  // ===================== 场景路由（PRD §14.1 / §14.2）=====================

  /**
   * 场景路由：已开放 task_plan / task_dialog；其余保持 ok:false，
   * 由门面（services/AIService）自动回退 MockAIService，核心功能不中断。
   */
  async dispatch(req: AIRequest<AIPayload>): Promise<AIResponse<AIResult>> {
    if (!this.isReady()) {
      return this.fail<AIResult>(req.scene, req.requestId, 'not_configured', 'Gateway AI 未配置')
    }
    if (req.scene === 'task_dialog') {
      const payload: PlanningDialogInput = req.payload as Object as PlanningDialogInput
      const r = await this.runDialog(req.requestId, payload)
      return r as Object as AIResponse<AIResult>
    }
    if (req.scene === 'task_plan') {
      const payload: PlanningInput = req.payload as Object as PlanningInput
      const r = await this.runPlan(req.requestId, payload)
      return r as Object as AIResponse<AIResult>
    }
    // 学习答疑：此前漏接这一支，导致 askText/runQA 全是死代码、答疑永远回退本地模板
    if (req.scene === 'qa_text') {
      const payload: QATextPayload = req.payload as Object as QATextPayload
      const r = await this.runQA(req.requestId, payload)
      return r as Object as AIResponse<AIResult>
    }
    return this.fail<AIResult>(req.scene, req.requestId, 'not_implemented',
      `场景 ${req.scene} 暂未开放网关，已回退本地 AI`)
  }

  // ===================== 业务实现 =====================

  /**
   * 对话式规划：把历史对话按 user/assistant 交替还原后追问。
   * 模型信息足够时会直接返回 done=true + tasks（PRD §14.4 任务规划）。
   */
  private async runDialog(requestId: string, input: PlanningDialogInput): Promise<AIResponse<PlanningDialogResult>> {
    const ctx: string = input.planningContext !== undefined ? input.planningContext : ''
    const messages: ChatMessage[] = [{ role: 'system', content: Prompts.taskDialog(this.personality, ctx) }]
    const history: string[] = input.history !== undefined ? input.history : []
    for (let i = 0; i < history.length; i++) {
      const role: string = i % 2 === 0 ? 'user' : 'assistant'
      messages.push({ role: role, content: history[i] })
    }
    messages.push({ role: 'user', content: input.userInput })

    const started: number = Date.now()
    const content: string = await this.chatJson(messages, BridgeConfig.MODEL_TEXT, 0.75, 900,
      BridgeConfig.timeoutForScene('task_dialog'))
    if (content.length === 0) {
      return this.fail<PlanningDialogResult>('task_dialog', requestId, 'gateway_empty', '大模型无有效返回')
    }

    let raw: RawDialog | null = null
    try {
      raw = JSON.parse(content) as RawDialog
    } catch (e) {
      raw = null
    }
    if (raw === null) {
      return this.fail<PlanningDialogResult>('task_dialog', requestId, 'gateway_bad_json', '返回不是合法 JSON')
    }

    const reply: string = raw.reply !== undefined ? raw.reply : ''
    if (reply.length === 0) {
      return this.fail<PlanningDialogResult>('task_dialog', requestId, 'gateway_bad_json', '返回缺少 reply 字段')
    }
    const done: boolean = raw.done === true
    const result: PlanningDialogResult = {
      reply: reply,
      done: done,
      tasks: done ? GatewayAIService.toPlanTasks(raw.tasks) : []
    }
    const v = SchemaValidator.for('task_dialog').validate(result as Object)
    if (!v.ok) {
      return this.fail<PlanningDialogResult>('task_dialog', requestId, 'schema_invalid', '返回不符合 Schema')
    }
    return this.ok<PlanningDialogResult>('task_dialog', requestId, result, Date.now() - started)
  }

  /** 单轮生成结构化任务（对话兜底路径） */
  private async runPlan(requestId: string, input: PlanningInput): Promise<AIResponse<PlanningResult>> {
    const ctx: string = input.planningContext !== undefined ? input.planningContext : ''
    const messages: ChatMessage[] = [
      { role: 'system', content: Prompts.taskPlan(this.personality, ctx) },
      { role: 'user', content: input.goal }
    ]
    const started: number = Date.now()
    const content: string = await this.chatJson(messages, BridgeConfig.MODEL_TEXT, 0.6, 900,
      BridgeConfig.timeoutForScene('task_plan'))
    if (content.length === 0) {
      return this.fail<PlanningResult>('task_plan', requestId, 'gateway_empty', '大模型无有效返回')
    }

    let raw: RawPlan | null = null
    try {
      raw = JSON.parse(content) as RawPlan
    } catch (e) {
      raw = null
    }
    if (raw === null) {
      return this.fail<PlanningResult>('task_plan', requestId, 'gateway_bad_json', '返回不是合法 JSON')
    }

    const tasks: PlanTask[] = GatewayAIService.toPlanTasks(raw.tasks)
    if (tasks.length === 0) {
      return this.fail<PlanningResult>('task_plan', requestId, 'schema_invalid', '未能拆出可执行任务')
    }
    const summary: string = raw.summary !== undefined ? raw.summary : ''
    const result: PlanningResult = { tasks: tasks, summary: summary }
    const v = SchemaValidator.for('task_plan').validate(result as Object)
    if (!v.ok) {
      return this.fail<PlanningResult>('task_plan', requestId, 'schema_invalid', '返回不符合 Schema')
    }
    return this.ok<PlanningResult>('task_plan', requestId, result, Date.now() - started)
  }

  /**
   * 学习答疑（qa_text）：把会话内历史按 user/assistant 还原，
   * 并把「正在专注的任务 / 之前问过什么」作为当前情境注入系统提示词。
   */
  private async runQA(requestId: string, payload: QATextPayload): Promise<AIResponse<QAResp>> {
    const parts: string[] = []
    if (payload.subject !== undefined && payload.subject.length > 0) {
      parts.push(`- 用户正在专注的任务：${payload.subject}`)
    }
    if (payload.recentQuestions !== undefined && payload.recentQuestions.length > 0) {
      parts.push(`- 他之前问过：${payload.recentQuestions.join('；')}`)
    }
    const messages: ChatMessage[] = [{ role: 'system', content: Prompts.qa(this.personality, parts.join('\n')) }]
    const history: QAMessage[] = payload.history !== undefined ? payload.history : []
    for (const m of history) {
      messages.push({ role: m.role === 'user' ? 'user' : 'assistant', content: m.content })
    }
    messages.push({ role: 'user', content: payload.question })

    const started: number = Date.now()
    const content: string = await this.chatJson(messages, BridgeConfig.MODEL_TEXT, 0.5, 700,
      BridgeConfig.timeoutForScene('qa_text'))
    if (content.length === 0) {
      return this.fail<QAResp>('qa_text', requestId, 'gateway_empty', '大模型无有效返回')
    }

    let raw: RawQA | null = null
    try {
      raw = JSON.parse(content) as RawQA
    } catch (e) {
      raw = null
    }
    if (raw === null || raw.answer === undefined || raw.answer.length === 0) {
      return this.fail<QAResp>('qa_text', requestId, 'gateway_bad_json', '返回缺少 answer 字段')
    }
    const result: QAResp = {
      answer: raw.answer,
      references: raw.references !== undefined ? raw.references : [],
      disclaimer: QA_DISCLAIMER,
      scene: 'qa_text'
    }
    const v = SchemaValidator.for('qa_text').validate(result as Object)
    if (!v.ok) {
      return this.fail<QAResp>('qa_text', requestId, 'schema_invalid', '返回不符合 Schema')
    }
    return this.ok<QAResp>('qa_text', requestId, result, Date.now() - started)
  }

  /** 原始 task → PlanTask（补默认值并夹紧时长，保证 UI 不会拿到脏数据） */
  private static toPlanTasks(raw: RawTask[] | undefined): PlanTask[] {
    const out: PlanTask[] = []
    if (raw === undefined) {
      return out
    }
    let order: number = 0
    for (const t of raw) {
      if (order >= 6) {
        break
      }
      const title: string = (t.title !== undefined && t.title.length > 0) ? t.title : '学习任务'
      const subject: string = (t.subject !== undefined && t.subject.length > 0) ? t.subject : '综合'
      let minutes: number = t.estimated_minutes !== undefined ? t.estimated_minutes : 30
      if (minutes < 5) {
        minutes = 5
      }
      if (minutes > 240) {
        minutes = 240
      }
      out.push(PlanTask.create(title, subject, Math.round(minutes), order))
      order += 1
    }
    return out
  }

  // ===================== HTTP =====================

  /** 先按 JSON 模式请求；若网关不接受该参数则去掉后重试一次 */
  private async chatJson(
    messages: ChatMessage[],
    model: string,
    temperature: number,
    maxTokens: number,
    timeoutMs: number
  ): Promise<string> {
    const first: string = await this.callModel(messages, model, temperature, maxTokens, timeoutMs, true)
    if (first.length > 0) {
      return first
    }
    return await this.callModel(messages, model, temperature, maxTokens, timeoutMs, false)
  }

  /**
   * 真实多模态识别：把触发时抓拍的若干帧交给视觉模型，返回**可观察状态**。
   *
   * 只在这一处做"图片 → 云端"：无帧、未配置 Key、超时、解析失败一律返回 null，
   * 由 `ObservationQueue` 如实记为「无法判断」——绝不编造 activity。
   */
  async recognizeActivity(frames: ArrayBuffer[]): Promise<ObservationRecord | null> {
    if (!this.isReady() || frames.length === 0) {
      return null
    }
    try {
      const parts: ContentPart[] = [{ type: 'text', text: Prompts.activity(frames.length) }]
      for (const f of frames) {
        parts.push({
          type: 'image_url',
          image_url: { url: `data:image/jpeg;base64,${GatewayAIService.toBase64(f)}` }
        })
      }
      const messages: ChatMessage[] = [
        { role: 'system', content: '你只描述画面中可观察到的状态，不做任何心理或注意力推断。' },
        { role: 'user', content: parts }
      ]
      const content = await this.chatJson(messages, BridgeConfig.MODEL_MULTIMODAL, 0.2, 300,
        BridgeConfig.timeoutForScene('qa_text'))
      if (content.length === 0) {
        return null
      }
      let raw: RawActivity | null = null
      try {
        raw = JSON.parse(content) as RawActivity
      } catch (e) {
        raw = null
      }
      if (raw === null || raw.activity === undefined || raw.activity.length === 0) {
        return null
      }
      const o = new ObservationRecord()
      o.activity = raw.activity
      o.handheld = raw.handheld !== undefined ? raw.handheld : false
      o.facingDesk = raw.facingDesk !== undefined ? raw.facingDesk : false
      o.confidence = raw.confidence !== undefined ? raw.confidence : 0.5
      o.evidence = raw.evidence !== undefined ? raw.evidence : ''
      return o
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'recognizeActivity failed')
      return null
    }
  }

  /** ArrayBuffer → base64（多模态消息体需要） */
  private static toBase64(buf: ArrayBuffer): string {
    const bytes = new Uint8Array(buf)
    const helper = new util.Base64Helper()
    return helper.encodeToStringSync(bytes)
  }

  /** 真实 HTTP 调用：POST {base}/chat/completions */
  private async callModel(
    messages: ChatMessage[],
    model: string,
    temperature: number,
    maxTokens: number,
    timeoutMs: number,
    jsonMode: boolean
  ): Promise<string> {
    const body: GatewayRequestBody = {
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: maxTokens
    }
    if (jsonMode) {
      body.response_format = { type: 'json_object' }
    }
    const headers: GatewayHeaders = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${BridgeConfig.AI_API_KEY}`
    }
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(body),
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    }

    const request = http.createHttp()
    try {
      const res = await request.request(`${BridgeConfig.AI_API_BASE_URL}/chat/completions`, options)
      if (res.responseCode !== 200) {
        return ''
      }
      const rawResult: string | Object | ArrayBuffer = res.result
      const text: string = typeof rawResult === 'string' ? rawResult : ''
      if (text.length === 0) {
        return ''
      }
      const parsed = JSON.parse(text) as ChatCompletion
      const choices = parsed.choices
      if (choices === undefined || choices.length === 0) {
        return ''
      }
      const msg = choices[0].message
      if (msg === undefined || msg.content === undefined) {
        return ''
      }
      return GatewayAIService.extractJson(msg.content)
    } catch (err) {
      return ''
    } finally {
      request.destroy()
    }
  }

  /** 从模型输出中抠出最外层 JSON 对象（兼容 ```json 代码块与前后废话） */
  private static extractJson(s: string): string {
    let t: string = s.split('```json').join('')
    t = t.split('```JSON').join('')
    t = t.split('```').join('')
    t = t.trim()
    const start: number = t.indexOf('{')
    const end: number = t.lastIndexOf('}')
    if (start < 0 || end <= start) {
      return ''
    }
    return t.substring(start, end + 1)
  }
}
