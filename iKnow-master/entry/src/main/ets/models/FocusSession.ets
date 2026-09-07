import { FocusState, FocusSource, SessionStatus } from './Enums'

/** 一次状态记录 */
@Observed
export class FocusEvent {
  id: string = ''
  sessionId: string = ''
  timestamp: number = 0
  state: FocusState = FocusState.FOCUSED
  source: FocusSource = FocusSource.CAMERA
  confidence: number = 0
}

/** 专注曲线上的一个采样点（用于复盘图表） */
@Observed
export class FocusTimelinePoint {
  minute: number = 0
  level: number = 100
  state: FocusState = FocusState.FOCUSED
}

/** 一次专注会话 */
@Observed
export class FocusSession {
  id: string = ''
  title: string = ''
  startTime: number = 0
  endTime: number = 0
  totalDuration: number = 0      // 总学习时长（秒）
  focusDuration: number = 0      // 净专注时长（秒）
  distractionDuration: number = 0
  qaDuration: number = 0
  breakDuration: number = 0
  plannedDuration: number = 0    // 计划时长（分钟）
  taskIds: string[] = []
  completedTaskIds: string[] = []
  timeline: FocusTimelinePoint[] = []
  events: FocusEvent[] = []
  status: SessionStatus = SessionStatus.PLANNING
}
