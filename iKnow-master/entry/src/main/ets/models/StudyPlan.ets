import { TaskStatus } from './Enums'
import { IdUtils } from '../utils/IdUtils'

/**
 * AI 输出的任务单元 —— **仅传输结构，不入库**。
 *
 * 规划对话/规划接口（`PlanningService`）返回的是它；真正落库的是经 `toTask()` 转换后的
 * `Task`（`task` 表）。它此前叫 PlanTask 并被描述为"归属某次 StudyPlan"，
 * 但 `StudyPlan.tasks` 从未被赋过值、序列化出去恒为空数组 —— 那层归属关系并不存在。
 *
 * `id` 保留：`toTask()` 会优先用它当 `Task.id`，保证同一个计划任务在多条路径上转换出同一个 id。
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
 * 长期计划的单科目标。
 * `subject` 必须取自 `LearningGoal.subjects`（科目唯一来源）；
 * `subject === ''` 是**迁移遗留的"未分配目标"**（旧版只有总目标、还没分到科目），
 * 它不参与分科百分比，只作为"还没分科"的展示位（见 D4）。
 */
@Observed
export class SubjectTarget {
  subject: string = ''
  targetMinutes: number = 0

  static create(subject: string, targetMinutes: number): SubjectTarget {
    const t = new SubjectTarget()
    t.subject = subject
    t.targetMinutes = targetMinutes
    return t
  }
}

/**
 * 长期计划（PRD §12）。
 *
 * **单一来源规则（D1）**：
 *  - 科目清单只在 `LearningGoal.subjects` —— 这里只存"科目 → 目标分钟"的映射，键必须取自它；
 *  - 考试类型 / 考试日期只在 `LearningGoal` —— 本类**不再**复刻 `examType`（那是纯双写）；
 *  - 计划名与周期属于本类（`title` / `periodStart` / `periodEnd`，`periodEnd` 默认取考试日期）。
 *
 * **单记录**：`study_plan` 表恒为 1 行，id 固定为 `PLAN_SINGLETON_ID`。
 * 原先每次保存都 `new uuid` + 无排序读回，导致表里累积多行、读回哪行不确定。
 *
 * `totalEstimatedMinutes` 是**派生值**（= Σ subjectTargets.targetMinutes），不在 UI 上单独编辑，
 * 保存前调用 `recomputeTotal()`。
 */
@Observed
export class StudyPlan {
  /** 固定单记录 id —— 保证 study_plan 表永远只有 1 行 */
  static readonly PLAN_SINGLETON_ID = 'plan:current'
  id: string = ''
  /** 计划名（用户可编辑） */
  title: string = ''
  periodStart: number = 0
  /** 周期结束，默认取 `LearningGoal.targetDate`（派生，用户可覆盖） */
  periodEnd: number = 0
  subjectTargets: SubjectTarget[] = []
  /** 派生、只读 = Σ subjectTargets.targetMinutes（D3） */
  totalEstimatedMinutes: number = 0
  createdAt: number = 0
  updatedAt: number = 0

  /** 新建：统一固定 id，这是"单记录"的前提 */
  static create(title: string): StudyPlan {
    const p = new StudyPlan()
    p.id = StudyPlan.PLAN_SINGLETON_ID
    p.title = title
    const now = Date.now()
    p.periodStart = now
    p.createdAt = now
    p.updatedAt = now
    return p
  }

  /** 保存前重算派生总值（D3：没有两个可编辑的真值，就不会不一致） */
  static recomputeTotal(p: StudyPlan): void {
    let sum = 0
    for (const t of p.subjectTargets) {
      if (t.targetMinutes > 0) {
        sum += t.targetMinutes
      }
    }
    p.totalEstimatedMinutes = sum
  }

  /** 真正有效的目标分钟（排除迁移遗留的未分配行）—— 进度分母用这个 */
  static assignedMinutes(p: StudyPlan): number {
    let sum = 0
    for (const t of p.subjectTargets) {
      if (t.subject.length > 0 && t.targetMinutes > 0) {
        sum += t.targetMinutes
      }
    }
    return sum
  }

  /** 迁移遗留的未分配目标（分钟）；> 0 表示"设了总目标但还没分到科目" */
  static unassignedMinutes(p: StudyPlan): number {
    let sum = 0
    for (const t of p.subjectTargets) {
      if (t.subject.length === 0 && t.targetMinutes > 0) {
        sum += t.targetMinutes
      }
    }
    return sum
  }
}
