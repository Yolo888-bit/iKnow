import { TaskStatus } from './Enums'

/** 学习任务 */
@Observed
export class Task {
  id: string = ''
  title: string = ''
  subject: string = ''
  estimatedDuration: number = 30   // 预计时长（分钟）
  actualDuration: number = 0       // 实际投入（秒）
  status: TaskStatus = TaskStatus.TODO
  done: boolean = false
  sortOrder: number = 0
  sessionId: string = ''
  createdAt: number = 0
  /**
   * 归属的长期计划 id；`''` = 自由专注 / 未归属（**不计入目标进度**）。
   * 「目标进度」的分母只认本期计划的任务 —— 全量表混着历次规划的任务，越用越接近 0%。
   */
  planId: string = ''

  copy(): Task {
    const c = new Task()
    c.id = this.id
    c.title = this.title
    c.subject = this.subject
    c.estimatedDuration = this.estimatedDuration
    c.actualDuration = this.actualDuration
    c.status = this.status
    c.done = this.done
    c.sortOrder = this.sortOrder
    c.sessionId = this.sessionId
    c.createdAt = this.createdAt
    c.planId = this.planId
    return c
  }
}

/**
 * 学习目标（考试倒计时等）—— **这四个字段的唯一来源**（D1 单一来源规则）：
 * 考试类型 / 考试日期 / 科目清单 / 标语。
 * 长期计划（`StudyPlan`）只引用这里，不再复刻 `examType`；科目目标的键也必须取自 `subjects`。
 */

@Observed
export class LearningGoal {
  id: string = ''
  title: string = '考研上岸'
  examType: string = '考研'
  targetDate: number = 0
  subjects: string[] = []
}
