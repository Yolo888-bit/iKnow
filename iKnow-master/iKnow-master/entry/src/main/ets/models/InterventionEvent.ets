import { InterventionLevel, FeedbackAction, FocusSource } from './Enums'

/**
 * 一次分层干预事件（PRD §9）
 * 记录干预的触发时刻、等级、触达渠道、文案、以及用户反馈回收。
 * 反馈回收用于写回策略参数（InterventionEngine → Metrics/Profile）。
 */
@Observed
export class InterventionEvent {
  id: string = ''
  sessionId: string = ''
  /** 触发时间戳 */
  ts: number = 0
  /** 干预等级（轻/重/无） */
  level: InterventionLevel = InterventionLevel.NONE
  /** 触达渠道：watch-vibrate / phone-sound / screen-select / quiet */
  channel: string = ''
  /** 干预文案 */
  message: string = ''
  /** 触发来源（AI 决策 / 手动兜底） */
  source: FocusSource = FocusSource.AI
  /** 用户反馈（初始为 NONE，待回收） */
  userFeedback: FeedbackAction = FeedbackAction.NONE
  /** 干预后是否恢复专注 */
  recoveredFocus: boolean = false
  /** 原始 AI 决策 JSON（审计用，仅含 schema 内字段，绝不含原始影像/生理数据） */
  payloadJson: string = ''
}
