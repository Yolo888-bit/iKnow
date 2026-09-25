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

/**
 * 今日实时统计 —— **现算，不读快照**。
 *
 * 为什么单独要有这么一个东西：`Dashboard` 是"上一次重算的结果"。
 * 只要有任意一条路径改了内存里的计划 / 会话却没触发重算，
 * 读快照的界面就会一直显示旧值 —— 实测反馈的就是
 * 「今日任务 3/5 已完成，但今日数据里完成率还是 —」。
 * 首页「今日数据」改为直接调 `AppStore.todayStats()` 现算，与「今日任务」卡片
 * 看的是同一份数据；`refreshAggregates()` 也用它组装 dashboard，口径只有一处。
 */
@Observed
export class TodayStats {
  /** 今日累计学习时长（墙钟 − 休息 − 暂停，含答疑），秒 */
  focusSeconds: number = 0
  /** 今日净专注（秒） */
  netFocusSeconds: number = 0
  /** 今日分心（秒） */
  distractionSeconds: number = 0
  /** 今日专注率 0~100 = 净专注 /（净专注 + 分心），**不含答疑** */
  focusRate: number = 0
  /** 今日已完成任务数（与「今日任务」卡片同一份口径） */
  doneTasks: number = 0
  /** 今日任务总数 */
  totalTasks: number = 0
}
