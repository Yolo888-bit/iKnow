/** 学科进度 */
@Observed
export class SubjectProgress {
  subject: string = ''
  completed: number = 0
  total: number = 0
  percent: number = 0
}

/**
 * 任务进度的一项：引导里填的每个科目 = 一条任务进度。
 * 完成一次就涨一点（增量先写死 70%~90%，按科目名确定性取值，见 Dashboard）。
 * 例：{ subject: '行测', doneCount: 2, percent: 100 }
 */
@Observed
export class SubjectTaskProgress {
  subject: string = ''
  /** 该科目下已完成的任务次数 */
  doneCount: number = 0
  /** 进度百分比 0~100 */
  percent: number = 0
}

/** 工作台 / 首页聚合数据（由 AppStore 计算） */
@Observed
export class Dashboard {
  todayFocusSeconds: number = 0
  todayNetFocusSeconds: number = 0
  todayCompletedTasks: number = 0
  todayTotalTasks: number = 0
  focusRate: number = 0            // 今日净专注率 0-100
  weekFocusSeconds: number = 0
  weekTrend: number[] = []         // 近 7 天每日净专注分钟
  subjectProgress: SubjectProgress[] = []
}
