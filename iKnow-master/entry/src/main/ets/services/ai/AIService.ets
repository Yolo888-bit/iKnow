import { QAService } from './QAService'
import { CompanionService } from './CompanionService'
import { ReviewService } from './ReviewService'
import { PlanningService } from './PlanningService'
import { MemoryService } from './MemoryService'
import { QATextPayload, QAImagePayload, QAResp } from './QAService'
import { CompanionContext, CompanionDecision } from './CompanionService'
import { ReviewPayload, ReviewData } from './ReviewService'
import { PlanningInput, PlanningResult, PlanningDialogInput, PlanningDialogResult } from './PlanningService'
import { MemoryPayload, MemoryDelta } from './MemoryService'

/**
 * AI 服务统一信封与聚合接口（PRD §14）
 *
 * 五个独立服务（QA / Companion / Review / Planning / Memory）各自定义接口与
 * JSON Schema；本文件仅定义通用信封 AIRequest / AIResponse 与聚合 AIService。
 * Mock 与 Real 实现同一接口、同一 JSON Schema，替换时不改 UI（硬规则 §8）。
 *
 * 注意：本文件被 5 个服务契约文件反向引用（类型级循环依赖），仅类型引用，
 * ArkTS / TS 可安全解析。
 */

export type AIScene =
  | 'task_plan'
  | 'task_dialog'
  | 'companion'
  | 'qa_text'
  | 'qa_image'
  | 'review'
  | 'planning'
  | 'memory'

/**
 * 场景 → 输入载荷 联合类型（PRD §14.2 / §14.3）。
 * 调用方只需传 scene + payload，dispatch 据此分发到对应 Agent。
 */
export type AIPayload =
  | QATextPayload
  | QAImagePayload
  | CompanionContext
  | ReviewPayload
  | PlanningInput
  | PlanningDialogInput
  | MemoryPayload

/**
 * 场景 → 输出数据 联合类型。返回后调用方按 scene 区分具体结构。
 */
export type AIResult =
  | QAResp
  | CompanionDecision
  | ReviewData
  | PlanningResult
  | PlanningDialogResult
  | MemoryDelta

/** AI Context Assembly（PRD §13 L1/L2/L3 三层记忆） */
export interface AIContext {
  l1?: object
  l2?: object
  l3?: object
}

export interface AIRequestOptions {
  stream?: boolean
  temperature?: number
  maxTokens?: number
  timeoutMs?: number
  /** 是否允许超时后重试一次（默认 true，companion 场景为 false） */
  retry?: boolean
}

export interface AIRequest<TPayload> {
  requestId: string
  scene: AIScene
  userId: string
  sessionId?: string
  payload: TPayload
  context?: AIContext
  options?: AIRequestOptions
}

export interface AIUsage {
  promptTokens: number
  completionTokens: number
  latencyMs: number
}

export interface AIError {
  code: string
  message: string
  retryable: boolean
}

export interface AIResponse<TData> {
  requestId: string
  ok: boolean
  /** 形如 "qa_text@2026-09-11" */
  schemaVersion: string
  data?: TData
  error?: AIError
  usage?: AIUsage
  /** 是否走了本地兜底 */
  fallback?: boolean
}

/** 五个独立 AI 服务聚合为统一入口（硬规则 §1 / §13） */
export interface AIService extends QAService, CompanionService, ReviewService, PlanningService, MemoryService {
  setPersonality(p: string): void
  getPersonality(): string
  /**
   * 场景路由（PRD §14.1 / §14.2）：依据 req.scene 将请求分发到对应 Agent。
   * 调用方只需传 scene + payload，无需知道背后是 QA / Companion / Review /
   * Planning / Memory 哪一个。Mock 与 Gateway 实现同一方法，替换时不改 UI（硬规则 §8）。
   */
  dispatch(req: AIRequest<AIPayload>): Promise<AIResponse<AIResult>>
}
