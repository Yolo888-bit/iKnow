import { FocusState, FocusSource, SessionStatus } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import type { TaskTimelinePoint } from './TaskTimeline';
import type { InterventionEvent } from './InterventionEvent';
/** 一次状态记录 */
@Observed
export class FocusEvent {
    id: string = '';
    sessionId: string = '';
    timestamp: number = 0;
    state: FocusState = FocusState.FOCUSED;
    source: FocusSource = FocusSource.CAMERA;
    confidence: number = 0;
}
/** 专注曲线上的一个采样点（用于复盘图表） */
@Observed
export class FocusTimelinePoint {
    minute: number = 0;
    level: number = 100;
    state: FocusState = FocusState.FOCUSED;
}
/** 一次专注会话 */
@Observed
export class FocusSession {
    id: string = '';
    title: string = '';
    startTime: number = 0;
    endTime: number = 0;
    totalDuration: number = 0; // 墙钟总时长（秒）：running 期间全部流逝时间
    focusDuration: number = 0; // 净专注时长（秒）= GREEN 累计
    distractionDuration: number = 0; // 分心时长（秒）= YELLOW + RED 累计
    qaDuration: number = 0; // 答疑时长（秒）：计入总，不计净专注
    breakDuration: number = 0; // 休息时长（秒）
    pausedDuration: number = 0; // 暂停时长（秒）：用于 §5 总学习扣减
    plannedDuration: number = 0; // 计划时长（分钟）
    taskIds: string[] = [];
    completedTaskIds: string[] = [];
    timeline: FocusTimelinePoint[] = [];
    taskTimeline: TaskTimelinePoint[] = [];
    events: FocusEvent[] = [];
    interventions: InterventionEvent[] = [];
    snapshotsCount: number = 0; // 已落盘 SessionSnapshot 条数
    lastSnapshotAt: number = 0;
    perceptionMode: string = 'PERCEPTION_FULL'; // PerceptionMode
    status: SessionStatus = SessionStatus.PLANNING;
    updatedAt: number = 0;
}
