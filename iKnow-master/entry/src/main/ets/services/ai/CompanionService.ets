import { AIRequest, AIResponse } from './AIService'

/**
 * 考伴决策服务契约（PRD §9 / §13，场景 companion）
 * 决定是否干预、等级、触达渠道、文案、建议动作。
 */
export interface RecentIntervention {
  level: string
  ts: number
}

export interface CompanionContext {
  /** FocusState 字符串 */
  state: string
  /** 当前状态已持续毫秒 */
  sinceMs: number
  /** AIPersonality 字符串 */
  personality: string
  /** 是否佩戴手表（决定 RED 触达渠道） */
  hasWatch: boolean
  /** PerceptionMode 字符串（关闭摄像头时为 PERCEPTION_TIMER_ONLY） */
  perceptionMode: string
  /** 最近干预记录（用于预算/冷却判断） */
  recentInterventions: Array<RecentIntervention>
}

export interface CompanionDecision {
  shouldIntervene: boolean
  level: 'NONE' | 'LIGHT' | 'HEAVY'
  /** watch-vibrate / phone-sound / screen-select / quiet */
  channel: string
  message: string
  /** continue / rest / end / manual */
  action: string
}

export interface CompanionService {
  decide(req: AIRequest<CompanionContext>): Promise<AIResponse<CompanionDecision>>
}

export const COMPANION_SCHEMA_VERSION = 'companion@2026-09-11'
