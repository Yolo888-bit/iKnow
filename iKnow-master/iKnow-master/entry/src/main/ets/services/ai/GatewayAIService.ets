import { AIService, AIScene, AIRequest, AIResponse, AIError } from './AIService'
import { QATextPayload, QAImagePayload, QAResp } from './QAService'
import { CompanionContext, CompanionDecision } from './CompanionService'
import { ReviewPayload, ReviewData } from './ReviewService'
import { PlanningInput, PlanningResult, PlanningDialogInput, PlanningDialogResult } from './PlanningService'
import { MemoryPayload, MemoryDelta } from './MemoryService'

/**
 * 真实大模型网关占位（PRD §13 / §14）
 *
 * 当前未配置：所有方法返回 ok:false 的 not_configured 错误，由上层回退到
 * MockAIService。未来接入时：
 *  - 仅替换本类内部 HTTP 调用（指向后端网关，API Key 在网关侧，绝不下发客户端）；
 *  - 保持相同 AIRequest / AIResponse 信封与 JSON Schema；
 *  - UI 与调用方零改动（硬规则 §8 / §10）。
 */
export class GatewayAIService implements AIService {
  private static inst: GatewayAIService | null = null
  /** 是否启用真实网关（默认 false，强制走 Mock） */
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

  private notConfigured<T>(scene: AIScene, requestId: string): AIResponse<T> {
    const err: AIError = {
      code: 'not_configured',
      message: 'Gateway AI 未配置，请使用 MockAIService 或配置后端网关',
      retryable: false
    }
    return { requestId, ok: false, schemaVersion: 'gateway@0', error: err }
  }

  async plan(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
    return this.notConfigured<PlanningResult>('task_plan', req.requestId)
  }

  async dialog(req: AIRequest<PlanningDialogInput>): Promise<AIResponse<PlanningDialogResult>> {
    return this.notConfigured<PlanningDialogResult>('task_dialog', req.requestId)
  }

  async weeklyInsight(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
    return this.notConfigured<PlanningResult>('planning', req.requestId)
  }

  async decide(req: AIRequest<CompanionContext>): Promise<AIResponse<CompanionDecision>> {
    return this.notConfigured<CompanionDecision>('companion', req.requestId)
  }

  async askText(req: AIRequest<QATextPayload>): Promise<AIResponse<QAResp>> {
    return this.notConfigured<QAResp>('qa_text', req.requestId)
  }

  async askImage(req: AIRequest<QAImagePayload>): Promise<AIResponse<QAResp>> {
    return this.notConfigured<QAResp>('qa_image', req.requestId)
  }

  async generate(req: AIRequest<ReviewPayload>): Promise<AIResponse<ReviewData>> {
    return this.notConfigured<ReviewData>('review', req.requestId)
  }

  async update(req: AIRequest<MemoryPayload>): Promise<AIResponse<MemoryDelta>> {
    return this.notConfigured<MemoryDelta>('memory', req.requestId)
  }
}
