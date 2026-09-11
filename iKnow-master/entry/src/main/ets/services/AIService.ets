import { Task } from '../models/Task'
import { FocusSession } from '../models/FocusSession'
import { StudyReport } from '../models/StudyReport'
import { FocusProfile } from '../models/FocusProfile'
import { AIPersonality } from '../models/Enums'
import { MockAIService } from './ai/MockAIService'

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

  static getInstance(): AIService {
    if (AIService.inst === null) {
      AIService.inst = new AIService()
    }
    return AIService.inst
  }

  private constructor() {
    this.mock = MockAIService.getInstance()
  }

  setPersonality(p: AIPersonality): void {
    this.mock.setPersonality(p)
  }

  getPersonality(): AIPersonality {
    return this.mock.getPersonality() as AIPersonality
  }

  /** 学伴固定开场（身份透明必须保留） */
  companionIntro(): string {
    return this.mock.companionIntro()
  }

  /** 对话式规划开场白 */
  openPlanning(): string {
    return this.mock.openPlanning()
  }

  /** 对话式规划的追问 */
  nextPlanningQuestion(step: number): string {
    return this.mock.nextPlanningQuestion(step)
  }

  /** 根据目标文本生成结构化任务（委托 MockAIService） */
  async planTasks(input: string): Promise<Task[]> {
    return await this.mock.planTasks(input)
  }

  /** 通用学伴对话 */
  async chat(input: string): Promise<string> {
    return await this.mock.chat(input)
  }

  /** 答疑（委托 MockAIService，输出带免责声明） */
  async answerQuestion(q: string): Promise<string> {
    return await this.mock.answerQuestion(q)
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
  longTermAnalysis(profile: FocusProfile, hardestSubject: string): string {
    return this.mock.longTermAnalysis(profile, hardestSubject)
  }
}
