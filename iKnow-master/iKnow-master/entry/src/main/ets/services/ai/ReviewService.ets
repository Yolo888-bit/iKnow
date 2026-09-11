import { AIRequest, AIResponse } from './AIService'
import { FocusSession } from '../../models/FocusSession'
import { QuestionRecord } from '../../models/QuestionRecord'

/**
 * 复盘服务契约（PRD §13，场景 review）
 */
export interface ReviewPayload {
  session: FocusSession
  questions: QuestionRecord[]
}

export interface ReviewData {
  insight: string
  suggestions: string[]
}

export interface ReviewService {
  generate(req: AIRequest<ReviewPayload>): Promise<AIResponse<ReviewData>>
}

export const REVIEW_SCHEMA_VERSION = 'review@2026-09-11'
