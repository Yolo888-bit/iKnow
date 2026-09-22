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

  /** 置信度地板：低于此值直接忽略（采而不信，§8）。单位与检测结果一致，为 0~100 */
  static readonly CONFIDENCE_FLOOR = 50

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

  // ---------- 休息（§8）----------
  /** 一次休息时长 5 min */
  static readonly BREAK_TOTAL_SEC = 300
  /** 「再休息 5 分钟」的延长时长 */
  static readonly BREAK_EXTEND_SEC = 300

  // ---------- 计时 / 快照 ----------
  /** 心跳 tick 间隔（仅用于驱动差值累加，不做计数） */
  static readonly TICK_MS = 1_000
  /** 每 10 s 落一条 SessionSnapshot（§4） */
  static readonly SNAPSHOT_INTERVAL_MS = 10_000
  /** 专注曲线采样间隔：每累计该时长采一个点（状态切换时也会补采） */
  static readonly TIMELINE_SAMPLE_MS = 30_000
  /** 崩溃/后台恢复：超过该时长的未结束会话视为可恢复 */
  static readonly RESTORE_WINDOW_MS = 30 * 60_000
  // 注：原先这里有一个 MAX_TICK_DELTA_MS = 5s 的"单 tick 累加上限"（防差值爆炸）。
  // 已删除：它把息屏/后台的空档统统截成 5 秒，而"手机扣在桌上学习"正是本产品的核心场景，
  // 结果是 30 分钟专注只涨 5 秒、专注率失真。改为按段用墙钟结清（见 FocusController.settleSegment）。

  // ---------- 感知采样（§7）----------
  /** 视觉采样 1-5 FPS（此处取融合前最高频上限参考） */
  static readonly SAMPLE_FPS = 3
  /** 融合频率 1 Hz */
  static readonly FUSION_HZ = 1

  // ===================== 手表事件驱动（本轮新增）=====================
  //
  // ⚠️ 阈值说明（务必如实告知评审）：
  //  1. 复赛使用的是**合成信号**，以下阈值用于让管线与演示自洽；
  //  2. RMSSD 的窗口长度默认取 60 s。文献里 Bourdillon et al. 2017 指出短窗会显著劣化、
  //     RMSSD 至少需要 2 min（且仰卧）；Charles & Nixon 2019 的 58 篇综述结论是
  //     "没有单一指标能清晰判别心理负荷"。
  //     因此 **RMSSD 只作为"状态变化待确认"的线索，绝不作为"分心/认知负荷"的结论**，
  //     且必须与基线比较（个体内相对变化），不用绝对阈值。
  //  3. 所有阈值都应由真实数据标定后再定稿；当前值仅为可按的起步值。

  /** HRV 分析窗口：默认 60 s（下限 30 s，见上文说明） */
  static readonly HRV_WINDOW_MS = 60_000
  /** 基线建立段的目标时长（仅用于展示与说明，不再作为"只在此区间内接受窗口"的硬边界） */
  static readonly BASELINE_WINDOW_MS = 4 * 60_000
  /**
   * 基线硬超时：超过此时长仍未收够合格窗口，就用已有窗口先建基线（日志标注样本偏少）。
   * 必须有这一条兜底 —— 否则信号质量差时基线永远建不成。
   */
  static readonly BASELINE_HARD_TIMEOUT_MS = 8 * 60_000
  /** 建立基线所需的最少合格窗口数 */
  static readonly BASELINE_MIN_WINDOWS = 4
  /** 单窗口内参与计算的最少有效 RR 数（不足则丢弃该窗，不做任何判定） */
  static readonly RR_MIN_COUNT = 25
  /** RR 生理可能区间（毫秒）：超出即视为伪影 */
  static readonly RR_MIN_MS = 300
  static readonly RR_MAX_MS = 2000
  /** RR 离群判据：偏离窗口中位数超过该比例即剔除 */
  static readonly RR_OUTLIER_RATIO = 0.3

  /** 加速度方差门限（g²）：高于此值视为"大幅移动/离开" */
  static readonly MOTION_HIGH_VAR = 0.0020
  /** 加速度方差门限：低于此值视为"几乎静止" */
  static readonly MOTION_STILL_VAR = 0.00020
  /** 持续静止超过该时长才认为"久坐不动" */
  static readonly STILL_LIMIT_MS = 8 * 60_000

  /** RMSSD 相对基线下降比例（唤醒/负荷线索，非结论） */
  static readonly RMSSD_DROP_RATIO = 0.35
  /** 心率相对基线上升（bpm），与 RMSSD 下降同时满足才作为线索 */
  static readonly HR_RISE_BPM = 8

  /** 触发节流：两次触发的最小间隔 */
  static readonly MIN_TRIGGER_GAP_MS = 60_000
  /** 单会话最多触发次数（超限只记录不触发） */
  static readonly MAX_TRIGGER_PER_SESSION = 20
  /** 同一原因在冷却期内不重复触发 */
  static readonly TRIGGER_COOLDOWN_MS = 3 * 60_000

  /** 触发式画面采集：帧数与总超时（保证端到端时延可预测） */
  static readonly BURST_FRAME_COUNT = 6
  static readonly BURST_TIMEOUT_MS = 3_500
  /** 固定采集参数（锁画质：分辨率 / JPEG 质量 / 单帧体积上限） */
  static readonly BURST_WIDTH = 640
  static readonly BURST_HEIGHT = 480
  static readonly BURST_JPEG_QUALITY = 70
  static readonly BURST_MAX_FRAME_BYTES = 80 * 1024
  /** 上传单次超时 */
  static readonly UPLOAD_TIMEOUT_MS = 8_000
  /** 画面保留期（默认 7 天，到期清理） */
  static readonly IMAGE_RETENTION_MS = 7 * 24 * 3600 * 1000
  /** 单会话队列上限（防止异常情况下堆积） */
  static readonly MAX_QUEUE_PER_SESSION = 20

  // ===================== 模拟状态（演示注入）=====================
  //
  // 无摄像头 / 无真表时，模拟状态面板必须"点了立刻有反应"。做法分两条，各自诚实：
  //  ① 状态注入：直接注入一条"云端识别结果"，走真实的规则组合 → 干预 → UI；
  //  ② 信号注入：改合成信号后强制结算当前窗口，让真实的基线/SQI/触发逻辑立刻出结果。
  /** 演示注入的置信度（与真实云端识别结果同量纲 0~1） */
  static readonly SIM_INJECT_CONFIDENCE = 0.9
  /** 切换合成信号阶段后，等新阶段样本填满窗口再强制结算（真实毫秒） */
  static readonly SIM_INJECT_SETTLE_MS = 1_200
  /** 注入标记的宽限期：结论是异步回来的（采集→识别→规则），留足时间再过期 */
  static readonly SIM_INJECT_GRACE_MS = 6_000

  // ===================== 手机侧信号：专注中切后台 =====================
  //
  // 零外设、零权限可用（`power.isActive()`，since 9）。
  // 判据不是"App 进后台"本身，而是"进后台 **且屏幕是亮的**" —— 后者才等于"人在别的应用上"，
  // 即手机使用。熄屏/锁屏（手机扣在桌上、放兜里）是学习场景的常态，绝不能判成分心。
  /** 亮屏离开超过这个时长才算一次"手机使用"分心（滤掉误触返回造成的秒级抖动） */
  static readonly BG_PHONE_MIN_SEC = 30
  /** 该判定的置信度（与其它来源同量纲 0~1；这是可观察事实，取值偏高） */
  static readonly BG_PHONE_CONFIDENCE = 0.9
}
