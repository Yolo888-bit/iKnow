/**
 * 专注状态机 / 感知管线 / 干预预算 —— 单一事实源（PRD 第八、九节）
 *
 * 所有"魔法数字"集中在此，任何模块（FocusController / InterventionEngine /
 * FocusDetectionService）都不得自行定义阈值常量。修改去抖/冷却/预算参数
 * 只改这一处。
 *
 * 关键参数出处（PRD §8）：
 *  - 最小驻留 10 s
 *  - GREEN→黄 5 s / 红→黄 5 s / 黄→绿 10 s
 *  - confidence < 0.5 直接忽略（采而不信）
 *  - 黄 3 min / 红 5 min 冷却（同一升级方向在该窗口内不得重复触发）
 *  - 10 min 内最多 2 轻 + 1 重干预
 *  - 每 10 s 落一条 SessionSnapshot，支持崩溃/后台恢复（恢复窗口 30 min）
 */
export class FocusTuning {
  // ---------- 状态机去抖 ----------
  /** 任何状态进入后至少驻留多久才可被"有效计数"用于干预决策（§8 最小驻留 10 s） */
  static readonly MIN_DWELL_MS = 10_000

  /** GREEN → 黄：需黄信号持续 5 s */
  static readonly DWELL_GREEN_TO_YELLOW_MS = 5_000
  /** 红 → 黄：需黄信号持续 5 s */
  static readonly DWELL_RED_TO_YELLOW_MS = 5_000
  /** 黄 → GREEN：需绿信号持续 10 s */
  static readonly DWELL_YELLOW_TO_GREEN_MS = 10_000

  /** 置信度地板：低于此值直接忽略（采而不信，§8） */
  static readonly CONFIDENCE_FLOOR = 0.5

  // ---------- 干预冷却 ----------
  /** 黄级升级冷却窗口 3 min */
  static readonly YELLOW_COOLDOWN_MS = 3 * 60_000
  /** 红级升级冷却窗口 5 min */
  static readonly RED_COOLDOWN_MS = 5 * 60_000

  // ---------- 干预预算（§9）----------
  /** 预算滑动窗口 10 min */
  static readonly INTERVENTION_WINDOW_MS = 10 * 60_000
  /** 窗口内轻干预上限 */
  static readonly MAX_LIGHT_PER_WINDOW = 2
  /** 窗口内重干预上限 */
  static readonly MAX_HEAVY_PER_WINDOW = 1

  // ---------- 计时 / 快照 ----------
  /** 心跳 tick 间隔（仅用于驱动差值累加，不做计数） */
  static readonly TICK_MS = 1_000
  /** 每 10 s 落一条 SessionSnapshot（§4） */
  static readonly SNAPSHOT_INTERVAL_MS = 10_000
  /** 崩溃/后台恢复：超过该时长的未结束会话视为可恢复 */
  static readonly RESTORE_WINDOW_MS = 30 * 60_000
  /** 后台长睡时，单 tick 累加上限（防差值爆炸） */
  static readonly MAX_TICK_DELTA_MS = 5_000

  // ---------- 感知采样（§7）----------
  /** 视觉采样 1-5 FPS（此处取融合前最高频上限参考） */
  static readonly SAMPLE_FPS = 3
  /** 融合频率 1 Hz */
  static readonly FUSION_HZ = 1
}
