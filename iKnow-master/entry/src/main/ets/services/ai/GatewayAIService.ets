import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { AIService, AIScene, AIRequest, AIResponse, AIError, AIPayload, AIResult } from './AIService'
import { QATextPayload, QAImagePayload, QAResp, QA_DISCLAIMER } from './QAService'
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
import { ObservationRecord } from '../../models/WatchSignal'

/** OpenAI 兼容请求体（PRD §15.2） */
interface ChatMessage {
  role: string
  content: string
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

/** 流式请求体（SSE，附加 stream:true） */
interface GatewayStreamBody {
  model: string
  messages: ChatMessage[]
  temperature: number
  max_tokens: number
  stream: boolean
}

/** SSE 分片：choices[0].delta.content */
interface StreamDelta {
  content?: string
}

interface StreamChoice {
  delta?: StreamDelta
}

interface StreamChunk {
  choices?: StreamChoice[]
}

/** 一次流式调用的结果 */
interface StreamOutcome {
  /** 目标字段（reply / answer）已收到的完整文本 */
  visible: string
  /** 拼回来的完整 JSON 原文 */
  raw: string
  /** 是否真的收到过内容 */
  ok: boolean
}

/**
 * 真实大模型网关（PRD §13 / §14 / §15.2）
 *
 *  - 用 `@kit.NetworkKit` 的 http 直接调用兼容 OpenAI 协议的 chat/completions。
 *  - 已开放网关的场景：`task_plan` / `task_dialog` / `qa_text`；另有非场景化的 `slogan`。
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

  // ===================== 五个服务接口 =====================

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

  /**
   * 真实多模态识别（触发时抓拍的帧 → 可观察状态）。
   *
   * 隐私约束（PRD §14.7）：**原始影像不上传**，因此这里不接视觉大模型，
   * 直接返回 null —— 调用方据此降级为「模拟输入源」或如实记为「无法判断」，
   * 而不是伪造一个识别结果（硬规则 §5：不伪造感知数据）。
   */
  async recognizeActivity(frames: ArrayBuffer[]): Promise<ObservationRecord | null> {
    return null
  }

  // ===================== 场景路由（PRD §14.1 / §14.2）=====================

  /**
   * 场景路由：已开放 task_plan / task_dialog / qa_text；其余保持 ok:false，
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
    const messages: ChatMessage[] = [{ role: 'system', content: Prompts.taskDialog(this.personality) }]
    const ctx: string = input.planningContext !== undefined ? input.planningContext : ''
    if (ctx.length > 0) {
      messages.push({ role: 'system', content: `【用户的备考背景】\n${ctx}` })
    }
    const history: string[] = input.history !== undefined ? input.history : []
    for (let i = 0; i < history.length; i++) {
      const role: string = i % 2 === 0 ? 'user' : 'assistant'
      messages.push({ role: role, content: history[i] })
    }
    messages.push({ role: 'user', content: input.userInput })

    const started: number = Date.now()
    const content: string = await this.chatJson(messages, BridgeConfig.MODEL_TEXT, 0.75, 1100,
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
    const messages: ChatMessage[] = [
      { role: 'system', content: Prompts.taskPlan(this.personality) },
      { role: 'user', content: input.goal }
    ]
    const started: number = Date.now()
    const content: string = await this.chatJson(messages, BridgeConfig.MODEL_TEXT, 0.6, 1100,
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

  /** 学习答疑（qa_text）：返回带免责声明的 QAResp */
  private async runQA(requestId: string, input: QATextPayload): Promise<AIResponse<QAResp>> {
    const messages: ChatMessage[] = [{ role: 'system', content: Prompts.qa(this.personality) }]
    const history = input.history
    if (history !== undefined) {
      for (const h of history) {
        messages.push({ role: h.role === 'ai' || h.role === 'assistant' ? 'assistant' : 'user', content: h.content })
      }
    }
    const subject: string = input.subject !== undefined && input.subject.length > 0
      ? `（我目前正在做：${input.subject}）` : ''
    messages.push({ role: 'user', content: `${input.question}${subject}` })

    const started: number = Date.now()
    const content: string = await this.chatJson(messages, BridgeConfig.MODEL_TEXT, 0.6, 1400,
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

  /**
   * 贴合目标的励志标语（首页顶部）。
   * 非场景化调用：纯文本输出，失败返回空串，由门面回退本地文案表。
   */
  async slogan(goalType: string, daysLeft: number): Promise<string> {
    if (!this.isReady() || goalType.length === 0) {
      return ''
    }
    const messages: ChatMessage[] = [
      { role: 'system', content: '你是中文文案助手。只输出一句标语本身，不要引号、不要解释。' },
      { role: 'user', content: Prompts.slogan(goalType, daysLeft) }
    ]
    const text: string = await this.chatText(messages, BridgeConfig.MODEL_FAST, 1.0, 40, 8000)
    const line: string = text.split('\n')[0].trim().split('"').join('').split('「').join('').split('」').join('')
    // 太短/太长都视为不合格，交由门面回退本地文案表（宁可要短句，不要长口号）
    if (line.length === 0 || line.length > 16) {
      return ''
    }
    return line
  }

  // ===================== 流式（SSE）=====================

  /**
   * 流式答疑：`onDelta` 逐段给出 answer 文本，返回完整 answer。
   * 未配置网关或流失败返回空串，由门面回退非流式。
   */
  async streamQA(input: QATextPayload, onDelta: (t: string) => void): Promise<string> {
    if (!this.isReady()) {
      return ''
    }
    const messages: ChatMessage[] = [{ role: 'system', content: Prompts.qa(this.personality) }]
    const history = input.history
    if (history !== undefined) {
      for (const h of history) {
        messages.push({ role: h.role === 'ai' || h.role === 'assistant' ? 'assistant' : 'user', content: h.content })
      }
    }
    const subject: string = input.subject !== undefined && input.subject.length > 0
      ? `（我目前正在做：${input.subject}）` : ''
    messages.push({ role: 'user', content: `${input.question}${subject}` })

    const out: StreamOutcome = await this.streamJson(messages, BridgeConfig.MODEL_TEXT, 0.6, 1400,
      BridgeConfig.timeoutForScene('qa_text'), 'answer', onDelta)
    if (!out.ok) {
      return ''
    }
    let raw: RawQA | null = null
    try {
      raw = JSON.parse(out.raw) as RawQA
    } catch (e) {
      raw = null
    }
    if (raw !== null && raw.answer !== undefined && raw.answer.length > 0) {
      return raw.answer
    }
    // JSON 没收全时，用户已经看到的文本就是答案（别让它凭空消失）
    return out.visible
  }

  /**
   * 流式规划对话：`onDelta` 逐段给出 reply 文本，返回完整结构化结果。
   * 未配置网关或流失败返回 null，由门面回退非流式。
   */
  async streamDialog(input: PlanningDialogInput, onDelta: (t: string) => void): Promise<PlanningDialogResult | null> {
    if (!this.isReady()) {
      return null
    }
    const messages: ChatMessage[] = [{ role: 'system', content: Prompts.taskDialog(this.personality) }]
    const ctx: string = input.planningContext !== undefined ? input.planningContext : ''
    if (ctx.length > 0) {
      messages.push({ role: 'system', content: `【用户的备考背景】\n${ctx}` })
    }
    const history: string[] = input.history !== undefined ? input.history : []
    for (let i = 0; i < history.length; i++) {
      messages.push({ role: i % 2 === 0 ? 'user' : 'assistant', content: history[i] })
    }
    messages.push({ role: 'user', content: input.userInput })

    const out: StreamOutcome = await this.streamJson(messages, BridgeConfig.MODEL_TEXT, 0.75, 1100,
      BridgeConfig.timeoutForScene('task_dialog'), 'reply', onDelta)
    if (!out.ok) {
      return null
    }
    let raw: RawDialog | null = null
    try {
      raw = JSON.parse(out.raw) as RawDialog
    } catch (e) {
      raw = null
    }
    if (raw === null) {
      // JSON 没收全：把已流出的文本当作对话回复，不出任务（避免半截 JSON）
      if (out.visible.length === 0) {
        return null
      }
      const partial: PlanningDialogResult = { reply: out.visible, done: false, tasks: [] }
      return partial
    }
    const reply: string = (raw.reply !== undefined && raw.reply.length > 0) ? raw.reply : out.visible
    if (reply.length === 0) {
      return null
    }
    const done: boolean = raw.done === true
    const result: PlanningDialogResult = {
      reply: reply,
      done: done,
      tasks: done ? GatewayAIService.toPlanTasks(raw.tasks) : []
    }
    return result
  }

  /**
   * SSE 流式调用。
   *
   * 模型仍按 JSON 模式输出，但 SSE 是一段段吐 JSON 文本的；
   * 直接把裸 JSON 流给用户看会很难看，所以这里**实时从半截 JSON 里抽取目标字段**
   * （reply / answer）再回调出去 —— 既保留 JSON 结构化与 Schema 校验，又能逐字上屏。
   */
  private async streamJson(
    messages: ChatMessage[],
    model: string,
    temperature: number,
    maxTokens: number,
    timeoutMs: number,
    visibleField: string,
    onDelta: (t: string) => void
  ): Promise<StreamOutcome> {
    const outcome: StreamOutcome = { visible: '', raw: '', ok: false }
    const body: GatewayStreamBody = {
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: maxTokens,
      stream: true
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
    // 字节先攒着，只解码到最后一个换行 —— 否则多字节汉字会被从中间截断成乱码
    let bytes: number[] = []
    let lineBuf = ''
    let raw = ''
    let emitted = 0

    const handleLine = (line: string): void => {
      if (!line.startsWith('data:')) {
        return
      }
      const payload = line.substring(5).trim()
      if (payload.length === 0 || payload === '[DONE]') {
        return
      }
      const delta = GatewayAIService.extractDelta(payload)
      if (delta.length === 0) {
        return
      }
      raw += delta
      const visible = GatewayAIService.partialField(raw, visibleField)
      if (visible.length > emitted) {
        onDelta(visible.substring(emitted))
        emitted = visible.length
      }
    }

    const drainLines = (): void => {
      let idx = lineBuf.indexOf('\n')
      while (idx >= 0) {
        const line = lineBuf.substring(0, idx).trim()
        lineBuf = lineBuf.substring(idx + 1)
        handleLine(line)
        idx = lineBuf.indexOf('\n')
      }
    }

    const drainBytes = (): void => {
      let lastNl = -1
      for (let i = bytes.length - 1; i >= 0; i--) {
        if (bytes[i] === 10) {
          lastNl = i
          break
        }
      }
      if (lastNl < 0) {
        return
      }
      const head = new Uint8Array(bytes.slice(0, lastNl + 1))
      bytes = bytes.slice(lastNl + 1)
      lineBuf += util.TextDecoder.create('utf-8').decodeToString(head)
      drainLines()
    }

    try {
      request.on('dataReceive', (data: ArrayBuffer) => {
        const u8 = new Uint8Array(data)
        for (let i = 0; i < u8.length; i++) {
          bytes.push(u8[i])
        }
        drainBytes()
      })
      await request.request(`${BridgeConfig.AI_API_BASE_URL}/chat/completions`, options)
      // 收尾：流已结束，剩下不足一行的字节也可以安全解码
      if (bytes.length > 0) {
        lineBuf += util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes))
        bytes = []
      }
      drainLines()
      if (lineBuf.trim().length > 0) {
        handleLine(lineBuf.trim())
        lineBuf = ''
      }
      outcome.raw = raw
      outcome.visible = GatewayAIService.partialField(raw, visibleField)
      outcome.ok = raw.length > 0
      return outcome
    } catch (e) {
      // 已经吐出去的内容仍然可用（调用方据此决定要不要回退）
      outcome.raw = raw
      outcome.visible = GatewayAIService.partialField(raw, visibleField)
      outcome.ok = raw.length > 0
      return outcome
    } finally {
      request.off('dataReceive')
      request.destroy()
    }
  }

  /** 从 SSE data 分片里取出增量文本 */
  private static extractDelta(payload: string): string {
    let obj: StreamChunk | null = null
    try {
      obj = JSON.parse(payload) as StreamChunk
    } catch (e) {
      obj = null
    }
    if (obj === null) {
      return ''
    }
    const choices = obj.choices
    if (choices === undefined || choices.length === 0) {
      return ''
    }
    const delta = choices[0].delta
    if (delta === undefined || delta.content === undefined) {
      return ''
    }
    return delta.content
  }

  /**
   * 从**还没收完**的 JSON 文本里，尽量取出某个字符串字段当前的值。
   * 用于把流式 JSON 变成可读文本；转义序列未收全时安全停下。
   */
  private static partialField(json: string, field: string): string {
    const key = `"${field}"`
    const at = json.indexOf(key)
    if (at < 0) {
      return ''
    }
    let i = at + key.length
    while (i < json.length && json.charAt(i) !== ':') {
      i++
    }
    i++
    while (i < json.length && (json.charAt(i) === ' ' || json.charAt(i) === '\t')) {
      i++
    }
    if (json.charAt(i) !== '"') {
      return ''
    }
    i++
    let out = ''
    while (i < json.length) {
      const c = json.charAt(i)
      if (c === '\\') {
        if (i + 1 >= json.length) {
          break
        }
        const n = json.charAt(i + 1)
        if (n === 'n') {
          out += '\n'
        } else if (n === 't') {
          out += '\t'
        } else if (n === 'r') {
          out += ''
        } else if (n === '"') {
          out += '"'
        } else if (n === '\\') {
          out += '\\'
        } else {
          out += n
        }
        i += 2
        continue
      }
      if (c === '"') {
        break
      }
      out += c
      i++
    }
    return out
  }

  /**
   * 原始 task → PlanTask。
   * 时长优先用模型给的；缺失时按任务性质推断（不与 30 死绑）。
   */
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
      const minutes: number = GatewayAIService.resolveMinutes(title, t.estimated_minutes)
      out.push(PlanTask.create(title, subject, minutes, order))
      order += 1
    }
    return out
  }

  /** 时长兜底：模型没给时按任务性质推断，避免所有任务都落到同一个值 */
  private static resolveMinutes(title: string, raw: number | undefined): number {
    if (raw !== undefined && raw > 0) {
      let m = Math.round(raw)
      if (m < 5) {
        m = 5
      }
      if (m > 180) {
        m = 180
      }
      return m
    }
    if (title.indexOf('题') >= 0 || title.indexOf('卷') >= 0) {
      return 35
    }
    if (title.indexOf('背') >= 0 || title.indexOf('单词') >= 0 || title.indexOf('记忆') >= 0) {
      return 25
    }
    if (title.indexOf('预习') >= 0 || title.indexOf('阅读') >= 0 || title.indexOf('看') >= 0) {
      return 25
    }
    if (title.indexOf('课') >= 0 || title.indexOf('视频') >= 0) {
      return 45
    }
    if (title.indexOf('错题') >= 0 || title.indexOf('复盘') >= 0 || title.indexOf('整理') >= 0) {
      return 20
    }
    if (title.indexOf('作文') >= 0 || title.indexOf('写') >= 0) {
      return 30
    }
    return 40
  }

  // ===================== HTTP =====================

  /** 先按 JSON 模式请求；若拿不到合法 JSON 则去掉该参数重试一次 */
  private async chatJson(
    messages: ChatMessage[],
    model: string,
    temperature: number,
    maxTokens: number,
    timeoutMs: number
  ): Promise<string> {
    const first: string = await this.callModelRaw(messages, model, temperature, maxTokens, timeoutMs, true)
    const parsed: string = GatewayAIService.extractJson(first)
    if (parsed.length > 0) {
      return parsed
    }
    const second: string = await this.callModelRaw(messages, model, temperature, maxTokens, timeoutMs, false)
    return GatewayAIService.extractJson(second)
  }

  /** 纯文本输出（不要求 JSON），用于标语这类一句话生成 */
  private async chatText(
    messages: ChatMessage[],
    model: string,
    temperature: number,
    maxTokens: number,
    timeoutMs: number
  ): Promise<string> {
    const text: string = await this.callModelRaw(messages, model, temperature, maxTokens, timeoutMs, false)
    return text.trim()
  }

  /** 真实 HTTP 调用：POST {base}/chat/completions，返回 message.content 原文 */
  private async callModelRaw(
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
      return msg.content
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
