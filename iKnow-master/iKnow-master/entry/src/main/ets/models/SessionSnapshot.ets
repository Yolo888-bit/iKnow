/**
 * 会话快照（PRD §4）—— 每 10 s 落一条，支持崩溃/后台恢复。
 * 主键 = sessionId + ts（同一会话多条）。
 * 恢复时取最近一条快照继续累加，避免误以为计时归零。
 */
@Observed
export class SessionSnapshot {
  sessionId: string = ''
  /** 快照时间戳 */
  ts: number = 0
  /** 累计总学习时长（秒） */
  totalSec: number = 0
  /** 累计净专注时长（秒） */
  focusSec: number = 0
  /** 累计分心时长（秒） */
  distractionSec: number = 0
  /** 累计答疑时长（秒） */
  qaSec: number = 0
  /** 累计休息时长（秒） */
  breakSec: number = 0
  /** 当时所处任务 id */
  currentTaskId: string = ''
  /** 当时状态（FocusState 字符串，便于无枚举反序列化） */
  state: string = 'FOCUSED'
  /** 当时感知模式（PERCEPTION_FULL / PERCEPTION_TIMER_ONLY） */
  perceptionMode: string = 'PERCEPTION_FULL'
}
