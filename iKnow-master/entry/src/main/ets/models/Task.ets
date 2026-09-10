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
    return c
  }
}

/** 学习目标（考试倒计时等） */
@Observed
export class LearningGoal {
  id: string = ''
  title: string = '考研上岸'
  examType: string = '考研'
  targetDate: number = 0
  subjects: string[] = []
}
