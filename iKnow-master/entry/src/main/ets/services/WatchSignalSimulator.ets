import { hilog } from '@kit.PerformanceAnalysisKit'
import { AccelSample, RrSample } from '../models/WatchSignal'

const DOMAIN = 0x0000
const TAG = 'iKnow.SimWatch'

/**
 * 合成信号阶段 ↔ 云端可识别状态 —— **单一事实源**。
 *
 * 为什么必须有这个映射：模拟工作台让用户选的"状态"必须与云端视觉模型
 * 实际能输出的取值**完全一致**（见 `Prompts.activity()`），否则会出现
 * "工作台能选、云端永远给不出来"的假状态。
 *
 * 云端 activity 取值（7 个，含"无法判断"）：
 *   做题 / 看书 / 看手机 / 趴桌 / 离开 / 多人 / 无法判断
 * 对应阶段：STUDY / READ / PHONE / REST / ABSENT / CROWD / UNKNOWN
 * PREPARE（静坐准备）是基线段的过渡阶段，语义上等同于"做题"（面向桌面、有纸笔）。
 */
export class SimActivity {
  /** 工作台可选状态（顺序即展示顺序，与云端取值一一对应） */
  static readonly ALL: string[] = ['做题', '看书', '看手机', '趴桌', '离开', '多人', '无法判断']
  /** 会被规则组合判为"确认分心"的状态（与 FocusController.onObservation 一致） */
  static readonly DISTRACTING: string[] = ['看手机', '离开']
  /** 会被规则组合判为"轻提示"的状态 */
  static readonly LIGHT_ONLY: string[] = ['趴桌']
  /** 会被规则组合判为"学习中"的状态 */
  static readonly LEARNING: string[] = ['做题', '看书']

  /** 状态 → 合成信号阶段 */
  static phaseOf(activity: string): string {
    if (activity === '看书') {
      return 'READ'
    }
    if (activity === '看手机') {
      return 'PHONE'
    }
    if (activity === '趴桌') {
      return 'REST'
    }
    if (activity === '离开') {
      return 'ABSENT'
    }
    if (activity === '多人') {
      return 'CROWD'
    }
    if (activity === '无法判断') {
      return 'UNKNOWN'
    }
    return 'STUDY'
  }

  /** 阶段 → 云端可识别状态（模拟识别器与设备页共用） */
  static activityOf(phase: string): string {
    if (phase === 'READ') {
      return '看书'
    }
    if (phase === 'PHONE') {
      return '看手机'
    }
    if (phase === 'REST') {
      return '趴桌'
    }
    if (phase === 'ABSENT') {
      return '离开'
    }
    if (phase === 'CROWD') {
      return '多人'
    }
    if (phase === 'UNKNOWN') {
      return '无法判断'
    }
    return '做题'
  }

  /** 状态在当前规则组合下会产生什么结论（给工作台如实提示，避免"点了没反应"的误解） */
  static effectOf(activity: string): string {
    if (SimActivity.DISTRACTING.includes(activity)) {
      return '判定分心 → 触发干预'
    }
    if (SimActivity.LIGHT_ONLY.includes(activity)) {
      return '判定轻度分心 → 轻提示'
    }
    if (SimActivity.LEARNING.includes(activity)) {
      return '确认学习中 → 回到专注'
    }
    return '不产生结论（宁可不提示，也不猜）'
  }
}

/**
 * 手表信号模拟器 —— ⚠️ **生成的是合成信号，不是真实测量**
 *
 * 复赛环境没有真实手表，本文件是唯一的信号源。它必须被三处如实标注：
 * 代码注释、运行日志（TAG=SimWatch）、演示材料。
 *
 * 生成的信号特性（按生理常识设定，用于让管线与展示合理）：
 *  - RR 间期：以 60/bpm 为中心，叠加
 *      · 呼吸性窦性心律不齐（RSA，约 0.25Hz 正弦）——真实 HRV 的主要来源
 *      · 缓慢随机游走（近似 1/f 成分）
 *    RSA 幅度随"负荷"变化：静息大、专注中中等、看手机时小 → RMSSD 自然下降
 *  - 加速度（25Hz，单位 g）：按阶段给定不同方差
 *      · 静坐：极低；写字：小幅周期性；看手机：中等；离开：高
 *
 * 采样：`step()` 由外部以 25Hz 调用（40ms），内部按心跳节拍产出 RR。
 */
export class WatchSignalSimulator {
  /** 演示阶段：把"用户状态"脚本化，便于跑通管线与演示 */
  private phase: string = 'PREPARE'
  private startMs: number = 0
  private lastStepMs: number = 0
  /** 距下一次心跳的累计时间（ms） */
  private rrDebtMs: number = 0
  /** 随机游走分量 */
  private drift: number = 0
  /** 写字/手部动作的相位 */
  private limbPhase: number = 0

  /** 基线建立段时长（ms）：默认 4 分钟，落在用户要求的 3~8 分钟内 */
  static readonly BASELINE_MS = 4 * 60 * 1000

  /**
   * 演示时基倍率：模拟样本的时间戳按此倍率推进，因此"4 分钟基线"约 8 秒真实时间。
   *
   * 注意：**只影响合成信号源的时间戳推进**，不改任何阈值语义；接入真实手表时
   * 时间戳就是真实时间（倍率自动为 1），算法不受影响。
   */
  static readonly SIM_TIME_SCALE = 30

  reset(nowMs: number): void {
    this.startMs = nowMs
    this.lastStepMs = nowMs
    this.rrDebtMs = 0
    this.drift = 0
    this.limbPhase = 0
    this.phase = 'PREPARE'
  }

  /** 演示控制：切换阶段（取值见 SimActivity.phaseOf：STUDY/READ/PHONE/REST/ABSENT/CROWD/UNKNOWN） */
  setPhase(phase: string, nowMs: number): void {
    this.phase = phase
    hilog.info(DOMAIN, TAG, '[合成信号] 切换到阶段 %{public}s（对应可观察状态：%{public}s）',
      phase, SimActivity.activityOf(phase))
  }

  // ============ 逐项控制（专注页「信号控制台」用）============
  // 说明：这些改的是**输入信号本身**，判定仍然由真实的基线/SQI/触发/节流逻辑做，
  // 控制台不会绕过算法直接改状态。

  private hrOverride: number = 0
  private lowHrv: boolean = false
  private motionOverride: string = ''
  private spo2Value: number = 98

  /** 指定心率（bpm）；0 = 跟随阶段默认 */
  setHeartRate(bpm: number): void {
    this.hrOverride = bpm
    hilog.info(DOMAIN, TAG, '[合成信号] 心率设为 %{public}d', bpm)
  }

  /** 压低 HRV（模拟负荷升高 → RMSSD 下降） */
  setLowHrv(on: boolean): void {
    this.lowHrv = on
    hilog.info(DOMAIN, TAG, '[合成信号] HRV 偏低 = %{public}s', on ? '是' : '否')
  }

  /** 动作模式：STILL / WRITE / MOVE；空串 = 跟随阶段 */
  setMotion(mode: string): void {
    this.motionOverride = mode
    hilog.info(DOMAIN, TAG, '[合成信号] 动作模式 = %{public}s', mode)
  }

  /** 血氧（仅展示，不参与判定） */
  setSpo2(v: number): void {
    this.spo2Value = v
  }

  getSpo2(): number {
    return this.spo2Value
  }

  /** 当前有效心率（供控制台显示） */
  currentBpm(): number {
    return this.baseBpm()
  }

  getPhase(): string {
    return this.phase
  }

  /** 真实时间 → 模拟时基（演示用；倍率见 SIM_TIME_SCALE） */
  simNow(realNowMs: number): number {
    if (this.startMs === 0) {
      return realNowMs
    }
    return this.startMs + (realNowMs - this.startMs) * WatchSignalSimulator.SIM_TIME_SCALE
  }

  isBaselineDone(realNowMs: number): boolean {
    return this.simNow(realNowMs) - this.startMs >= WatchSignalSimulator.BASELINE_MS
  }

  /**
   * 推进一次（外部每 40ms 调用一次）。
   * 产出的样本通过回调交出，避免内部持有容器。
   */
  step(realNowMs: number, onAccel: (s: AccelSample) => void, onRr: (s: RrSample) => void): void {
    if (this.startMs === 0) {
      this.reset(realNowMs)
    }
    // 关键：内部全部使用**模拟时基**（演示时基 ×N），因此 4 分钟基线约 8 秒真实时间。
    // 接入真实手表时不走本类，时间戳即真实时间，阈值语义不受影响。
    const nowMs = this.simNow(realNowMs)
    const dtMs = Math.max(0, nowMs - this.lastStepMs)
    this.lastStepMs = nowMs

    // 基线段结束后自动进入学习段（脚本化时间线）
    if (this.phase === 'PREPARE' && this.isBaselineDone(realNowMs)) {
      this.phase = 'STUDY'
      hilog.info(DOMAIN, TAG, '[合成信号] 基线段结束，自动进入 STUDY')
    }

    // —— 加速度（25Hz 一帧）——
    const a = new AccelSample()
    a.tMs = nowMs
    const profile = this.motionProfile()
    this.limbPhase += 0.6
    a.x = this.jitter(profile.amp) + Math.sin(this.limbPhase) * profile.periodic
    a.y = this.jitter(profile.amp)
    a.z = 1.0 + this.jitter(profile.amp * 0.5)
    onAccel(a)

    // —— RR 间期（按心跳节拍产出，可能一帧内 0 或 1 个）——
    this.rrDebtMs -= dtMs
    if (this.rrDebtMs > 0) {
      return
    }
    const rr = this.nextRrMs(nowMs)
    const s = new RrSample()
    s.tMs = nowMs
    s.rrMs = rr
    s.quality = 1
    onRr(s)
    this.rrDebtMs += rr
  }

  /** 各阶段的运动特征（g）；控制台的动作模式优先 */
  private motionProfile(): MotionAmp {
    if (this.motionOverride === 'STILL') {
      return { amp: 0.003, periodic: 0.0 }
    }
    if (this.motionOverride === 'WRITE') {
      return { amp: 0.006, periodic: 0.01 }
    }
    if (this.motionOverride === 'MOVE') {
      return { amp: 0.08, periodic: 0.12 }
    }
    if (this.phase === 'ABSENT') {
      return { amp: 0.08, periodic: 0.12 }
    }
    if (this.phase === 'CROWD') {
      // 多人：旁边有人活动，设备本身小幅晃动
      return { amp: 0.02, periodic: 0.03 }
    }
    if (this.phase === 'PHONE') {
      // 拿起手机**本身就是大幅腕部动作**，这里必须让方差越过 `MOTION_HIGH_VAR(0.002)`：
      // 原来的 0.012 档算出来约 3.1e-4，正好卡在"静止 2e-4"与"大幅移动 2e-3"之间 ——
      // 于是"看手机"在信号层**永远撞不到触发点**，整条"手表粗筛 → 抓拍 → 云端细判"
      // 在无真表的演示里根本走不通（第八批 A1 已记录该测量值）。
      // 注意：触发只说明"有大幅动作"，究竟是看手机还是离开，由云端看照片判定 —— 这正是本架构的分工。
      return { amp: 0.05, periodic: 0.08 }
    }
    if (this.phase === 'REST') {
      return { amp: 0.003, periodic: 0.0 }
    }
    if (this.phase === 'READ') {
      // 看书：翻页是间歇动作，平均方差低于写字
      return { amp: 0.004, periodic: 0.004 }
    }
    if (this.phase === 'STUDY') {
      // 写字：小幅周期性
      return { amp: 0.006, periodic: 0.01 }
    }
    // PREPARE / UNKNOWN：静坐准备
    return { amp: 0.004, periodic: 0.0 }
  }

  private jitter(amp: number): number {
    return (Math.random() * 2 - 1) * amp
  }

  /** 生成一个 RR 间期 */
  private nextRrMs(nowMs: number): number {
    const bpm = this.baseBpm()
    const mean = 60000 / bpm
    // 呼吸性窦性心律不齐：约 0.25Hz（15 次/分）
    const tSec = (nowMs - this.startMs) / 1000
    const rsaAmp = this.rsaAmplitudeMs()
    const rsa = Math.sin(2 * Math.PI * 0.25 * tSec) * rsaAmp
    // 缓慢漂移（近似 1/f）：限制在 ±15ms
    this.drift += (Math.random() * 2 - 1) * 1.5
    if (this.drift > 15) {
      this.drift = 15
    }
    if (this.drift < -15) {
      this.drift = -15
    }
    const rr = mean + rsa + this.drift + this.jitter(6)
    return Math.round(Math.max(300, Math.min(2000, rr)))
  }

  /**
   * 各阶段心率与 RSA 幅度（幅度越小 → RMSSD 越低 → HRV 越低）
   * 注意：这是为了让演示数据自洽，不代表"HRV 能判别注意力"（文献不支持）。
   */
  private baseBpm(): number {
    if (this.hrOverride > 0) {
      return this.hrOverride
    }
    if (this.phase === 'ABSENT') {
      return 92
    }
    if (this.phase === 'CROWD') {
      return 78
    }
    if (this.phase === 'PHONE') {
      return 82
    }
    if (this.phase === 'STUDY') {
      return 74
    }
    if (this.phase === 'READ') {
      return 72
    }
    if (this.phase === 'REST') {
      return 62
    }
    return 68
  }

  private rsaAmplitudeMs(): number {
    if (this.lowHrv) {
      // 压低 RSA 幅度 → RMSSD 下降（模拟负荷升高）
      return 6
    }
    if (this.phase === 'ABSENT') {
      return 6
    }
    if (this.phase === 'CROWD') {
      return 12
    }
    if (this.phase === 'PHONE') {
      return 8
    }
    if (this.phase === 'STUDY') {
      return 14
    }
    if (this.phase === 'READ') {
      return 16
    }
    if (this.phase === 'REST') {
      return 28
    }
    return 24
  }
}

interface MotionAmp {
  amp: number
  periodic: number
}
