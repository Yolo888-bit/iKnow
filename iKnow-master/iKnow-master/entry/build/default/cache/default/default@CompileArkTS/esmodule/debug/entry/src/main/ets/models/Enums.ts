/**
 * 全局枚举定义（对齐 PRD 第五/七节）
 */
/** 专注状态机 */
export enum FocusState {
    FOCUSED = "FOCUSED",
    SLIGHTLY_DISTRACTED = "SLIGHTLY_DISTRACTED",
    DISTRACTED = "DISTRACTED",
    RESTING = "RESTING",
    PAUSED = "PAUSED",
    QA_MODE = "QA_MODE"
}
/** 状态判断来源 */
export enum FocusSource {
    CAMERA = "CAMERA",
    WATCH = "WATCH",
    MANUAL = "MANUAL",
    AI = "AI"
}
/** 任务状态 */
export enum TaskStatus {
    TODO = "TODO",
    DOING = "DOING",
    DONE = "DONE"
}
/** 专注会话状态（PRD 会话状态机：IDLE → PLANNING → READY → FOCUSING → ... → REVIEW → ARCHIVED） */
export enum SessionStatus {
    IDLE = "IDLE",
    PLANNING = "PLANNING",
    READY = "READY",
    RUNNING = "RUNNING",
    PAUSED = "PAUSED",
    BREAK = "BREAK",
    QA = "QA",
    FINISHED = "FINISHED",
    REVIEW = "REVIEW",
    ARCHIVED = "ARCHIVED"
}
/** 感知模式（PRD §7 / 硬规则 §4） */
export enum PerceptionMode {
    /** 摄像头视觉感知开启 */
    PERCEPTION_FULL = "PERCEPTION_FULL",
    /** 关闭摄像头后降级：仅计时模式，UI 明示"本次未开启感知" */
    PERCEPTION_TIMER_ONLY = "PERCEPTION_TIMER_ONLY"
}
/** 干预等级（PRD §9） */
export enum InterventionLevel {
    NONE = "NONE",
    /** 轻干预：温和提醒 */
    LIGHT = "LIGHT",
    /** 重干预：主动打断/引导休息 */
    HEAVY = "HEAVY"
}
/** 用户对干预的反馈动作（用于回收写回策略） */
export enum FeedbackAction {
    NONE = "NONE",
    ACCEPT = "ACCEPT",
    IGNORE = "IGNORE",
    CONTINUE = "CONTINUE",
    REST = "REST",
    END = "END",
    MANUAL = "MANUAL"
}
/** 摄像头原始检测状态（PRD §7，5 值）；由 FocusController 映射为 FocusState */
export enum CameraState {
    LOOKING_SCREEN = "LOOKING_SCREEN",
    LOOKING_AWAY = "LOOKING_AWAY",
    AWAY = "AWAY",
    SLEEPY = "SLEEPY",
    UNAVAILABLE = "UNAVAILABLE"
}
/** AI 学伴人格 */
export enum AIPersonality {
    STRICT = "STRICT",
    GENTLE = "GENTLE",
    QUIET = "QUIET",
    ADAPTIVE = "ADAPTIVE"
}
/** 设备类型 */
export enum DeviceType {
    PHONE = "PHONE",
    CAMERA = "CAMERA",
    WATCH = "WATCH"
}
/** 消息角色 */
export enum MessageRole {
    USER = "user",
    AI = "ai"
}
