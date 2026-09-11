import { FocusState, InterventionLevel, FeedbackAction, FocusSource } from '../models/Enums'
import { InterventionEvent } from '../models/InterventionEvent'
import { CompanionContext, CompanionDecision, RecentIntervention } from './ai/CompanionService'
import { MockAIService } from './ai/MockAIService'
import { FocusTuning } from '../common/FocusTuning'
import { StorageService } from './StorageService'
import { IdUtils } from '../utils/IdUtils'

/**
 * 干预引擎（PRD §9）
 *
 *  - 接收专注状态变化，调用 CompanionService.decide 获取干预决策；
 *  - 执行 §9 预算：10 min 内最多 2 轻 + 1 重；
 *  - 无手表时 RED 干预 channel = phone-sound（绝不 watch-vibrate，不假装震动）；
 *  - 记录 InterventionEvent 并持久化，支持用户反馈回收（recordUserFeedback）。
 *
 * Phase 0：引擎可运行并产出决策/事件；触达 UI 的呈现（弹窗/横幅）在第 1 步接入。
 */
export interface InterventionEvalContext {
  sessionId: string
  state: FocusState
  sinceMs: number
  hasWatch: boolean
  personality: string
  perceptionMode: string
  recent: InterventionEvent[]
}

export interface InterventionEvalResult {
  decision: CompanionDecision
  event: InterventionEvent | null
}

export class InterventionEngine {
  private static inst: InterventionEngine | null = null
  private currentSessionId: string = ''
  private recent: InterventionEvent[] = []

  static getInstance(): InterventionEngine {
    if (InterventionEngine.inst === null) {
      InterventionEngine.inst = new InterventionEngine()
    }
    return InterventionEngine.inst
  }

  setSessionId(id: string): void {
    this.currentSessionId = id
    this.recent = []
  }

  reset(): void {
    this.recent = []
  }

  getRecent(): InterventionEvent[] {
    return this.recent
  }

  evaluate(ctx: InterventionEvalContext): InterventionEvalResult {
    const now = Date.now()
    const window = ctx.recent.filter((e: InterventionEvent): boolean => now - e.ts <= FocusTuning.INTERVENTION_WINDOW_MS)
    const light = window.filter((e: InterventionEvent): boolean => e.level === InterventionLevel.LIGHT).length
    const heavy = window.filter((e: InterventionEvent): boolean => e.level === InterventionLevel.HEAVY).length

    const decision: CompanionDecision = MockAIService.getInstance().decideSync({
      state: ctx.state,
      sinceMs: ctx.sinceMs,
      personality: ctx.personality,
      hasWatch: ctx.hasWatch,
      perceptionMode: ctx.perceptionMode,
      recentInterventions: ctx.recent.map((e: InterventionEvent): RecentIntervention => ({ level: e.level as string, ts: e.ts }))
    })

    let event: InterventionEvent | null = null
    if (decision.shouldIntervene) {
      // 预算压制（§9）
      if (decision.level === 'LIGHT' && light >= FocusTuning.MAX_LIGHT_PER_WINDOW) {
        decision.shouldIntervene = false
      } else if (decision.level === 'HEAVY' && heavy >= FocusTuning.MAX_HEAVY_PER_WINDOW) {
        decision.shouldIntervene = false
      }
    }
    if (decision.shouldIntervene) {
      const e = new InterventionEvent()
      e.id = IdUtils.uuid()
      e.sessionId = ctx.sessionId
      e.ts = now
      e.level = decision.level === 'HEAVY'
        ? InterventionLevel.HEAVY
        : decision.level === 'LIGHT'
          ? InterventionLevel.LIGHT
          : InterventionLevel.NONE
      e.channel = decision.channel
      e.message = decision.message
      e.source = FocusSource.AI
      e.userFeedback = FeedbackAction.NONE
      e.payloadJson = JSON.stringify(decision)
      this.recent.push(e)
      event = e
      StorageService.getInstance().saveIntervention(e).catch(() => {})
    }
    return { decision, event }
  }

  /** 回收用户反馈，写回策略参数（Phase 0 仅持久化反馈） */
  recordUserFeedback(e: InterventionEvent, action: FeedbackAction, recoveredFocus: boolean): void {
    e.userFeedback = action
    e.recoveredFocus = recoveredFocus
    StorageService.getInstance().saveIntervention(e).catch(() => {})
  }
}
