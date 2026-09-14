import { AIRequest, AIResponse } from './AIService'
import { PlanTask } from '../../models/StudyPlan'

/**
 * 规划服务契约（PRD §13，场景 task_plan / task_dialog / planning）
 */
export interface PlanningInput {
  goal: string
  availableMinutes?: number
  subjects?: string[]
  preferredSubject?: string
  /** 已知用户背景（备考目标/学科/距考天数/黄金时段/平均专注时长/未完成任务/可用时间），
   *  由页面组装后注入提示词；为空则不注入，行为与之前一致。 */
  planningContext?: string
}

export interface PlanningResult {
  tasks: PlanTask[]
  summary: string
}

export interface PlanningDialogInput {
  step: number
  userInput: string
  history?: string[]
  /** 同 PlanningInput.planningContext */
  planningContext?: string
}

export interface PlanningDialogResult {
  reply: string
  done: boolean
  tasks?: PlanTask[]
}

export interface PlanningService {
  plan(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>>
  dialog(req: AIRequest<PlanningDialogInput>): Promise<AIResponse<PlanningDialogResult>>
  weeklyInsight(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>>
}

export const PLANNING_SCHEMA_VERSION = 'planning@2026-09-11'
