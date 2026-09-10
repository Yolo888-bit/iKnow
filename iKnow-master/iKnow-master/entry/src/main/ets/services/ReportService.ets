import { FocusSession, FocusTimelinePoint } from '../models/FocusSession'
import { QuestionRecord } from '../models/QuestionRecord'
import { StudyReport } from '../models/StudyReport'
import { FocusState } from '../models/Enums'
import { AIService } from './AIService'
import { TimeUtils } from '../utils/TimeUtils'

/**
 * 复盘服务 —— 根据会话数据生成单次学习复盘
 */
export class ReportService {
  private static inst: ReportService | null = null

  static getInstance(): ReportService {
    if (ReportService.inst === null) {
      ReportService.inst = new ReportService()
    }
    return ReportService.inst
  }

  async buildReport(session: FocusSession, questions: QuestionRecord[]): Promise<StudyReport> {
    const r = new StudyReport()
    r.sessionId = session.id
    r.createdAt = Date.now()
    r.completionRate = this.computeCompletionRate(session)
    r.focusRate = this.computeFocusRate(session)
    r.bestFocusPeriod = this.computeBestFocus(session)
    r.fatiguePoint = this.computeFatiguePoint(session)
    r.distractionTriggers = this.collectTriggers(session)
    r.questions = questions
    r.suggestions = AIService.getInstance().reviewSuggestions(session, r)
    r.insights = await AIService.getInstance().reviewInsight(session, r)
    return r
  }

  private computeCompletionRate(session: FocusSession): number {
    if (session.taskIds.length === 0) {
      return 100
    }
    return Math.round(session.completedTaskIds.length / session.taskIds.length * 100)
  }

  private computeFocusRate(session: FocusSession): number {
    if (session.totalDuration <= 0) {
      return 0
    }
    return Math.round(session.focusDuration / session.totalDuration * 100)
  }

  /** 从曲线中找最长的高专注连续段 */
  private computeBestFocus(session: FocusSession): string {
    const tl = session.timeline
    if (tl.length === 0) {
      return ''
    }
    let bestStart = 0
    let bestLen = 0
    let curStart = 0
    let curLen = 0
    for (let i = 0; i < tl.length; i++) {
      const p = tl[i]
      if (p.level >= 70) {
        if (curLen === 0) {
          curStart = p.minute
        }
        curLen++
        if (curLen > bestLen) {
          bestLen = curLen
          bestStart = curStart
        }
      } else {
        curLen = 0
      }
    }
    if (bestLen === 0) {
      return ''
    }
    const startClock = this.minuteToClock(session.startTime, bestStart)
    const endClock = this.minuteToClock(session.startTime, bestStart + bestLen)
    return `${startClock} - ${endClock}`
  }

  private minuteToClock(startTime: number, offsetMin: number): string {
    const d = new Date(startTime + offsetMin * 60000)
    return TimeUtils.minuteToClock(d.getHours() * 60 + d.getMinutes())
  }

  private computeFatiguePoint(session: FocusSession): number {
    const tl = session.timeline
    for (let i = 0; i < tl.length; i++) {
      const p = tl[i]
      if (p.state === FocusState.DISTRACTED || p.level < 45) {
        return p.minute
      }
    }
    return 0
  }

  private collectTriggers(session: FocusSession): string[] {
    const seen: string[] = []
    for (let i = 0; i < session.events.length; i++) {
      const e = session.events[i]
      if (e.state === FocusState.DISTRACTED || e.state === FocusState.SLIGHTLY_DISTRACTED) {
        if (seen.indexOf(e.source) < 0 && seen.length < 3) {
          seen.push(e.source === 'CAMERA' ? '视线离开屏幕' : '状态波动')
        }
      }
    }
    if (seen.length === 0 && session.distractionDuration > 0) {
      seen.push('视线离开屏幕')
    }
    return seen
  }
}
