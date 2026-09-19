/**
 * 手表信号的数据契约
 *
 * ⚠️ 复赛阶段本项目的信号**全部为合成信号（模拟器生成），不是真实测量**。
 *    RR 间期由模拟器直接生成，不从 PPG 波形反推 —— 因为用 25Hz 采样反推 RR 的
 *    时间分辨率（约 40ms）与 RMSSD 本身的量级（20~60ms）同数量级，精度不可用。
 *    25Hz 仅用于加速度计（人体活动频率 < 20Hz，足够）。
 */

/** RR 间期样本（毫秒）：相邻两次心跳的间隔，HRV 计算的最小单位 */
@Observed
export class RrSample {
  tMs: number = 0
  rrMs: number = 0
  /** 信号质量 0~1（模拟器给的是理想值；真实设备需由伪影/贴合度评估） */
  quality: number = 1
}

/** 25Hz 三轴加速度样本（单位 g） */
@Observed
export class AccelSample {
  tMs: number = 0
  x: number = 0
  y: number = 0
  z: number = 0
}

/** 手表侧事件类型 —— 注意语义：这些是"状态变化待确认"，不是"检测到分心" */
export enum WatchEventKind {
  /** 基线建成（前 3~8 分钟静坐段结束） */
  BASELINE_READY = 'BASELINE_READY',
  /** 状态变化，需要视觉确认（触发摄像头） */
  SUSPECT = 'SUSPECT',
  /** 长时间静坐不动 */
  STILL_LONG = 'STILL_LONG',
  /** 疑似离开/大幅移动 */
  MOTION_HIGH = 'MOTION_HIGH',
  /** 生理唤醒相对基线明显变化（负荷线索，**不是分心结论**） */
  AROUSAL_SHIFT = 'AROUSAL_SHIFT',
  /** 信号质量不足，本窗口已丢弃 */
  QUALITY_LOW = 'QUALITY_LOW',
  /**
   * 本窗口一切平稳（没有任何可疑条件命中）。
   * 必须有这一条：否则状态只能"变可疑"，永远回不到平静——用户点了
   * 「静息/正常/静止」也不会回绿，看起来就是"点了没反应"。
   */
  CALM = 'CALM'
}

/** 手表事件 */
@Observed
export class WatchEvent {
  id: string = ''
  sessionId: string = ''
  tMs: number = 0
  kind: WatchEventKind = WatchEventKind.SUSPECT
  /** 该窗口的 RMSSD（毫秒） */
  rmssd: number = 0
  /** 该窗口的平均心率 */
  hr: number = 0
  /** 该窗口的加速度方差 */
  accelVar: number = 0
  /** 人可读的原因（用于复盘与排查） */
  reason: string = ''
  /** 是否真的触发了摄像头（被节流拦下的只记录不触发） */
  triggered: boolean = false
}

/** 云端视觉识别输出的**可观察状态**（不让云端判"走神"） */
@Observed
export class ObservationRecord {
  id: string = ''
  sessionId: string = ''
  /** 关联的手表事件 id（可空：也可能是手动/其它来源触发） */
  eventId: string = ''
  tMs: number = 0
  /** 做题 / 看书 / 看手机 / 趴桌 / 离开 / 多人 / 无法判断 */
  activity: string = '无法判断'
  /** 是否手持手机 */
  handheld: boolean = false
  /** 是否面向桌面/书本 */
  facingDesk: boolean = false
  /** 模型自评置信度 0~1 */
  confidence: number = 0
  /** 一句话可核对的依据 */
  evidence: string = ''
  /** 采集到的画面文件路径（决策：上传并保存供复盘） */
  imagePaths: string[] = []
}
