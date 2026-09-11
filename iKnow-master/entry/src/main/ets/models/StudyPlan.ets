import { TaskStatus } from './Enums'
import { IdUtils } from '../utils/IdUtils'

/**
 * 学习计划中的一个具体任务单元（PRD §12）
 * 与历史 Task 区分：PlanTask 归属某次 StudyPlan，可被拆解/勾选，
 * 实际投入由 FocusController 在 finalize() 时反算写回 Task.actualDuration。
 */
@Observed
export class PlanTask {
  id: string = ''
  title: string = ''
  subject: string = ''
  estimatedDuration: number = 30   // 预计时长（分钟）
  status: TaskStatus = TaskStatus.TODO
  done: boolean = false
  sortOrder: number = 0

  static create(title: string, subject: string, minutes: number, order: number): PlanTask {
    const t = new PlanTask()
    t.id = IdUtils.uuid()
    t.title = title
    t.subject = subject
    t.estimatedDuration = minutes
    t.sortOrder = order
    return t
  }
}

/**
 * 学习计划（PRD §12）—— 用户的"今日计划"，可挂多个 PlanTask。
 * 与 FocusSession 的关系：一次专注会话引用某计划（或自由任务）。
 */
@Observed
export class StudyPlan {
  id: string = ''
  title: string = ''
  examType: string = ''
  totalEstimatedMinutes: number = 0
  tasks: PlanTask[] = []
  createdAt: number = 0

  static create(title: string, examType: string): StudyPlan {
    const p = new StudyPlan()
    p.id = IdUtils.uuid()
    p.title = title
    p.examType = examType
    p.createdAt = Date.now()
    return p
  }
}
