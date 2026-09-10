/**
 * 全局枚举定义（对齐 PRD 第五/七节）
 */

/** 专注状态机 */
export enum FocusState {
  FOCUSED = 'FOCUSED',
  SLIGHTLY_DISTRACTED = 'SLIGHTLY_DISTRACTED',
  DISTRACTED = 'DISTRACTED',
  RESTING = 'RESTING',
  PAUSED = 'PAUSED',
  QA_MODE = 'QA_MODE'
}

/** 状态判断来源 */
export enum FocusSource {
  CAMERA = 'CAMERA',
  WATCH = 'WATCH',
  MANUAL = 'MANUAL',
  AI = 'AI'
}

/** 任务状态 */
export enum TaskStatus {
  TODO = 'TODO',
  DOING = 'DOING',
  DONE = 'DONE'
}

/** 专注会话状态 */
export enum SessionStatus {
  PLANNING = 'PLANNING',
  RUNNING = 'RUNNING',
  PAUSED = 'PAUSED',
  BREAK = 'BREAK',
  QA = 'QA',
  FINISHED = 'FINISHED'
}

/** AI 学伴人格 */
export enum AIPersonality {
  STRICT = 'STRICT',
  GENTLE = 'GENTLE',
  QUIET = 'QUIET',
  ADAPTIVE = 'ADAPTIVE'
}

/** 设备类型 */
export enum DeviceType {
  PHONE = 'PHONE',
  CAMERA = 'CAMERA',
  WATCH = 'WATCH'
}

/** 消息角色 */
export enum MessageRole {
  USER = 'user',
  AI = 'ai'
}
