/**
 * 分项授权 —— 隐私合规全局唯一事实源（PRD §17）
 *
 * 摄像头 / 麦克风 / 健康（手表）/ 通知 四项独立开关。
 * 关闭摄像头后，专注降级为"仅计时模式"，UI 明示"本次未开启感知"。
 * 该对象由 PermissionService 统一读写并持久化，其他模块不得直接写死。
 */
@Observed
export class Authorization {
  /** 摄像头（视觉感知） */
  camera: boolean = false
  /** 麦克风（语音答疑，预留） */
  microphone: boolean = false
  /** 健康数据（智能手表，预留） */
  health: boolean = false
  /** 通知（轻干预提醒，预留） */
  notification: boolean = false
  /** 最近一次变更时间戳 */
  updatedAt: number = 0
}
