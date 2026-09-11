/**
 * 任务归属时间线采样点（PRD §12）
 * 记录"第几分钟在哪个任务上、当时专注等级如何"，用于复盘时还原
 * 任务级投入分布。与 FocusSession 内的"专注曲线" FocusTimelinePoint 并存：
 *  - FocusTimelinePoint：专注等级随时间曲线
 *  - TaskTimelinePoint：任务归属随时间曲线
 * 采样间隔建议 30 s。
 */
@Observed
export class TaskTimelinePoint {
  /** 相对会话开始的分钟偏移 */
  minuteOffset: number = 0
  /** 该分钟所处任务 id（空串表示未分配任务） */
  taskId: string = ''
  /** 该分钟专注等级 0-100 */
  level: number = 100
}
