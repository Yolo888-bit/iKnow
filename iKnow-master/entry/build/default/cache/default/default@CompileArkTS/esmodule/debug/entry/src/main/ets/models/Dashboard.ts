/** 学科进度 */
@Observed
export class SubjectProgress {
    subject: string = '';
    completed: number = 0;
    total: number = 0;
    percent: number = 0;
}
/** 工作台 / 首页聚合数据（由 AppStore 计算） */
@Observed
export class Dashboard {
    todayFocusSeconds: number = 0;
    todayNetFocusSeconds: number = 0;
    todayCompletedTasks: number = 0;
    todayTotalTasks: number = 0;
    focusRate: number = 0; // 今日净专注率 0-100
    weekFocusSeconds: number = 0;
    weekTrend: number[] = []; // 近 7 天每日净专注分钟
    subjectProgress: SubjectProgress[] = [];
}
