import { hilog } from '@kit.PerformanceAnalysisKit'
import { AccelSample, RrSample, WatchEvent, WatchEventKind } from '../models/WatchSignal'
import { FocusTuning } from '../common/FocusTuning'
import { IdUtils } from '../utils/IdUtils'
import { WatchSignalSink } from './WatchSignalSource'

const DOMAIN = 0x0000
const TAG = 'iKnow.WatchEngine'

/**
 * 手表事件引擎 —— 基线 / 触发 / 节流
 *
 * ⚠️ 输入是**合成信号**（复赛环境没有真实手表）。
 *
 * 语义边界（关键）：
 *  - 本引擎**只产出"状态变化待确认"的事件**，交给摄像头去确认"在做什么"；
 *  - **不产出"分心"结论**。HRV 反映的是唤醒/负荷，分不出"做难题"与"走神"；
 *    走神时人往往完全静止，加速度计也测不到；而短窗口 RMSSD 做个体在线判断
 *    在文献里被多篇反对（Bourdillon 2017 / Charles & Nixon 2019 / Mund & Schulte）。
 *    因此这里的一切都只是**线索**，必须与个人基线比较，不用绝对阈值。
 */
export class WatchEventEngine implements WatchSignalSink {
  private static inst: WatchEventEngine | null = null

  private sessionId: string = ''
  private sessionStartMs: number = 0
  private onEvent: ((e: WatchEvent) => void) | null = null
  private running: boolean = false

  // ---- 当前窗口累积 ----
  private winStartMs: number = 0
  /** 最近一个样本的时间戳（模拟时基）—— 演示注入的强制结算以它为"现在" */
  private lastSampleMs: number = 0
  private rrRaw: number[] = []
  private accelSum: number = 0
  private accelSqSum: number = 0
  private accelN: number = 0
  private hrSum: number = 0
  private hrN: number = 0

  // ---- 基线（个人基线，指数滑动缓慢更新）----
  private baseRmssd: number = 0
  private baseAccelVar: number = 0
  private baseHr: number = 0
  private baselineDone: boolean = false
  private baseCandidateRmssd: number[] = []
  private baseCandidateAccel: number[] = []
  private baseCandidateHr: number[] = []
  /** 仅当云端确认为"在做题/看书"时才允许更新基线，避免基线漂移 */
  private learningConfirmed: boolean = false

  // ---- 静止检测 ----
  private stillSinceMs: number = 0

  // ---- 触发节流 ----
  private triggerCount: number = 0
  private lastTriggerMs: number = 0
  private lastKindMs: Map<string, number> = new Map<string, number>()
  /** 最近一次事件（设备页反馈用） */
  private recentEvent: WatchEvent | null = null

  static getInstance(): WatchEventEngine {
    if (WatchEventEngine.inst === null) {
      WatchEventEngine.inst = new WatchEventEngine()
    }
    return WatchEventEngine.inst
  }

  isBaselineDone(): boolean {
    return this.baselineDone
  }

  getBaseRmssd(): number {
    return this.baseRmssd
  }

  getBaseAccelVar(): number {
    return this.baseAccelVar
  }

  getBaseHr(): number {
    return this.baseHr
  }

  getTriggerCount(): number {
    return this.triggerCount
  }

  /** 由云端识别结果驱动：确认用户正在做题/看书 → 允许用新窗口缓慢更新基线 */
  setLearningConfirmed(on: boolean): void {
    this.learningConfirmed = on
  }

  start(sessionId: string, sessionStartMs: number, onEvent: (e: WatchEvent) => void): void {
    this.sessionId = sessionId
    this.sessionStartMs = sessionStartMs
    this.onEvent = onEvent
    this.running = true
    const now = Date.now()
    this.winStartMs = now
    this.lastSampleMs = 0
    this.rrRaw = []
    this.accelSum = 0
    this.accelSqSum = 0
    this.accelN = 0
    this.hrSum = 0
    this.hrN = 0
    this.baseRmssd = 0
    this.baseAccelVar = 0
    this.baseHr = 0
    this.baselineDone = false
    this.baseCandidateRmssd = []
    this.baseCandidateAccel = []
    this.baseCandidateHr = []
    this.learningConfirmed = false
    this.stillSinceMs = now
    this.triggerCount = 0
    this.lastTriggerMs = 0
    this.lastKindMs = new Map<string, number>()
    hilog.info(DOMAIN, TAG, '[合成信号] 事件引擎启动，开始建立个人基线')
  }

  stop(): void {
    this.running = false
    this.onEvent = null
    hilog.info(DOMAIN, TAG, '事件引擎停止，本次共触发 %{public}d 次', this.triggerCount)
  }

  // ===================== 信号接入 =====================

  onAccel(s: AccelSample): void {
    if (!this.running) {
      return
    }
    this.lastSampleMs = s.tMs
    this.accelSum += s.x * s.x + s.y * s.y + s.z * s.z
    this.accelSqSum += s.x * s.x * s.x * s.x + s.y * s.y * s.y * s.y + s.z * s.z * s.z * s.z
    this.accelN += 3
    this.maybeCloseWindow(s.tMs)
  }

  onRr(s: RrSample): void {
    if (!this.running) {
      return
    }
    this.lastSampleMs = s.tMs
    this.rrRaw.push(s.rrMs)
    const bpm = s.rrMs > 0 ? 60000 / s.rrMs : 0
    if (bpm > 30 && bpm < 200) {
      this.hrSum += bpm
      this.hrN += 1
    }
    this.maybeCloseWindow(s.tMs)
  }

  // ===================== 窗口结算 =====================

  private maybeCloseWindow(nowMs: number): void {
    if (nowMs - this.winStartMs < FocusTuning.HRV_WINDOW_MS) {
      return
    }
    this.settleWindow(nowMs, false)
  }

  /**
   * 演示注入：**不等 60s 模拟窗口到期，立刻用当前已累积的样本结算一次**。
   *
   * 为什么需要：合成信号的时间戳按倍率推进，正常结算要等一个完整窗口，
   * 演示时表现为"点了半天没反应"。这里只改**结算时机**，不改任何阈值语义：
   * SQI 门禁、基线比较、触发判定、节流全部照常走。
   */
  evaluateNow(): void {
    if (!this.running) {
      return
    }
    const nowMs = this.lastSampleMs > this.winStartMs ? this.lastSampleMs : this.winStartMs + 1
    this.settleWindow(nowMs, true)
  }

  /**
   * 清空触发节流（演示注入用）。
   * 只清"最小间隔 / 同因冷却"这两个与演示节奏冲突的闸门，
   * **保留单会话配额**（配额是产品约束，不该被演示绕过）。
   */
  clearTriggerThrottle(): void {
    this.lastTriggerMs = 0
    this.lastKindMs = new Map<string, number>()
  }

  /**
   * 结算一个窗口：SQI 门禁 → 基线 → 判定。
   * @param forced true = 演示注入的强制结算。此时窗口可能不完整、基线可能样本偏少，
   *   因此不因"样本不足"直接丢弃，并在必要时用当前窗口先把基线建起来再继续判定。
   *   阈值语义一处未改，只放宽"结算时机"。
   */
  private settleWindow(nowMs: number, forced: boolean): void {
    this.winStartMs = nowMs

    // —— SQI 门禁：无效数据既不进基线也不参与判定 ——
    const rr = this.filterRr(this.rrRaw)
    const accelVar = this.accelVariance()
    const hr = this.hrN > 0 ? this.hrSum / this.hrN : 0
    const rrCount = this.rrRaw.length
    this.rrRaw = []
    this.accelSum = 0
    this.accelSqSum = 0
    this.accelN = 0
    this.hrSum = 0
    this.hrN = 0

    // 强制结算时把门槛降到能算 RMSSD 即可（≥2 个有效 RR）；非强制仍要求完整窗口
    const minRr = forced ? 2 : FocusTuning.RR_MIN_COUNT
    if (rr.length < minRr) {
      // 信号质量不足：丢弃该窗（RMSSD 对单个坏 RR 极敏感，宁可不算）
      hilog.warn(DOMAIN, TAG, '窗口丢弃：有效 RR %{public}d/%{public}d', rr.length, rrCount)
      this.emit(WatchEventKind.QUALITY_LOW, nowMs, 0, hr, accelVar, `有效 RR 不足（${rr.length}）`, false)
      return
    }
    const rmssd = this.rmssd(rr)

    // —— 基线段 ——
    // 只按"合格窗口数"收够即建基线；不再设"只在前 N 秒内接受"的时间上限
    //（原先那个上限要求 4 个 60s 窗口在 240s 内完成，而第 4 个窗口恰好在 240s 边界外关闭
    //  → 永远只有 3 个候选 → BASELINE_READY 数学上不可达）
    if (!this.baselineDone) {
      this.baseCandidateRmssd.push(rmssd)
      this.baseCandidateAccel.push(accelVar)
      this.baseCandidateHr.push(hr)
      const enough = this.baseCandidateRmssd.length >= FocusTuning.BASELINE_MIN_WINDOWS
      const timeout = nowMs - this.sessionStartMs >= FocusTuning.BASELINE_HARD_TIMEOUT_MS
      if (enough) {
        this.buildBaseline(false, nowMs, rmssd, hr, accelVar)
      } else if (timeout || forced) {
        // 超时兜底 / 演示注入：用已有合格窗先建基线（日志标注样本偏少）
        this.buildBaseline(true, nowMs, rmssd, hr, accelVar)
      } else {
        hilog.info(DOMAIN, TAG, '基线窗口 %{public}d/%{public}d',
          this.baseCandidateRmssd.length, FocusTuning.BASELINE_MIN_WINDOWS)
      }
      // 非强制：基线刚建成时不在同一窗口判定（保持原语义，交给下一次窗口）
      if (!forced) {
        return
      }
    }

    // —— 基线之后：缓慢自适应更新（只在确认学习中）——
    if (this.learningConfirmed) {
      const a = 0.05
      this.baseRmssd = this.baseRmssd * (1 - a) + rmssd * a
      this.baseAccelVar = this.baseAccelVar * (1 - a) + accelVar * a
      if (hr > 0) {
        this.baseHr = this.baseHr * (1 - a) + hr * a
      }
    }

    this.judge(nowMs, rmssd, hr, accelVar)
  }

  /** 建基线：partial=true 表示样本偏少（超时兜底），日志会写明 */
  private buildBaseline(partial: boolean, nowMs: number, rmssd: number,
                        hr: number, accelVar: number): void {
    const n = this.baseCandidateRmssd.length
    if (n === 0) {
      return
    }
    this.baseRmssd = this.mean(this.baseCandidateRmssd)
    this.baseAccelVar = this.mean(this.baseCandidateAccel)
    this.baseHr = this.mean(this.baseCandidateHr)
    this.baselineDone = true
    hilog.info(DOMAIN, TAG,
      '基线建成%s：RMSSD %{public}d ms · 加速度方差 %{public}s · 心率 %{public}d bpm（合成信号）',
      partial ? '（样本偏少，超时兜底）' : '',
      Math.round(this.baseRmssd), this.baseAccelVar.toFixed(6), Math.round(this.baseHr))
    this.emit(WatchEventKind.BASELINE_READY, nowMs, rmssd, hr, accelVar,
      partial ? `基线建成（仅 ${n} 个窗口，样本偏少）` : `基线建成（${n} 个窗口）`, false)
  }

  /** 引擎是否在运行（未开始专注时为 false） */
  isRunning(): boolean {
    return this.running
  }

  /** 基线进度：已收合格窗口数 / 需要数 */
  getBaselineProgress(): number {
    return this.baseCandidateRmssd.length
  }

  /** 最近一次事件（供设备页显示反馈） */
  getRecentEvent(): WatchEvent | null {
    return this.recentEvent
  }

  /** 过滤 RR：生理可能区间 + 中位数离群剔除 */
  private filterRr(raw: number[]): number[] {
    const inRange: number[] = []
    for (const rr of raw) {
      if (rr >= FocusTuning.RR_MIN_MS && rr <= FocusTuning.RR_MAX_MS) {
        inRange.push(rr)
      }
    }
    if (inRange.length === 0) {
      return inRange
    }
    const med = this.median(inRange)
    const out: number[] = []
    for (const rr of inRange) {
      if (Math.abs(rr - med) <= med * FocusTuning.RR_OUTLIER_RATIO) {
        out.push(rr)
      }
    }
    return out
  }

  /** RMSSD = sqrt(mean(ΔRR²))：短时 HRV 标准指标（Task Force ESC/NASPE 1996） */
  private rmssd(rr: number[]): number {
    if (rr.length < 2) {
      return 0
    }
    let sum = 0
    let n = 0
    for (let i = 1; i < rr.length; i++) {
      const d = rr[i] - rr[i - 1]
      sum += d * d
      n += 1
    }
    return n > 0 ? Math.sqrt(sum / n) : 0
  }

  private accelVariance(): number {
    if (this.accelN <= 0) {
      return 0
    }
    const mean = this.accelSum / this.accelN
    return Math.max(0, this.accelSqSum / this.accelN - mean * mean)
  }

  private median(arr: number[]): number {
    const s = arr.slice()
    s.sort((a: number, b: number): number => a - b)
    const mid = Math.floor(s.length / 2)
    return s.length % 2 === 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
  }

  private mean(arr: number[]): number {
    if (arr.length === 0) {
      return 0
    }
    let sum = 0
    for (const v of arr) {
      sum += v
    }
    return sum / arr.length
  }

  // ===================== 触发判定 =====================

  private judge(nowMs: number, rmssd: number, hr: number, accelVar: number): void {
    // ① 大幅移动 / 离开
    if (accelVar > FocusTuning.MOTION_HIGH_VAR) {
      this.stillSinceMs = nowMs
      this.emit(WatchEventKind.MOTION_HIGH, nowMs, rmssd, hr, accelVar,
        `设备移动明显（方差 ${accelVar.toFixed(6)} > ${FocusTuning.MOTION_HIGH_VAR}）`, true)
      return
    }

    // ② 久坐不动（注意：这只说明"人没动"，不说明在专注，也不说明走神）
    if (accelVar < FocusTuning.MOTION_STILL_VAR) {
      if (this.stillSinceMs === 0) {
        this.stillSinceMs = nowMs
      }
      if (nowMs - this.stillSinceMs >= FocusTuning.STILL_LIMIT_MS) {
        this.emit(WatchEventKind.STILL_LONG, nowMs, rmssd, hr, accelVar,
          `持续静止 ${Math.round((nowMs - this.stillSinceMs) / 60000)} 分钟`, true)
        return
      }
    } else {
      this.stillSinceMs = nowMs
    }

    // ③ 生理唤醒相对基线的变化（线索，不是结论）
    if (this.baseRmssd > 0 && rmssd > 0 && hr > 0) {
      const dropped = rmssd < this.baseRmssd * (1 - FocusTuning.RMSSD_DROP_RATIO)
      const hrUp = hr > this.baseHr + FocusTuning.HR_RISE_BPM
      if (dropped && hrUp) {
        this.emit(WatchEventKind.AROUSAL_SHIFT, nowMs, rmssd, hr, accelVar,
          `RMSSD ${Math.round(rmssd)} vs 基线 ${Math.round(this.baseRmssd)}，心率 ${Math.round(hr)} vs ${Math.round(this.baseHr)}`, true)
        return
      }
    }

    // ④ 三条都没命中 → 本窗口平稳。必须上报，状态才能回到专注。
    this.emit(WatchEventKind.CALM, nowMs, rmssd, hr, accelVar, '信号平稳', false)
  }

  /** 节流后抛事件：被拦下的仍然记录，只是 triggered=false */
  private emit(kind: WatchEventKind, nowMs: number, rmssd: number, hr: number,
               accelVar: number, reason: string, wantTrigger: boolean): void {
    let triggered = false
    if (wantTrigger) {
      const gapOk = nowMs - this.lastTriggerMs >= FocusTuning.MIN_TRIGGER_GAP_MS
      const quotaOk = this.triggerCount < FocusTuning.MAX_TRIGGER_PER_SESSION
      const kindKey = kind.toString()
      const last = this.lastKindMs.get(kindKey)
      const coolOk = last === undefined || nowMs - last >= FocusTuning.TRIGGER_COOLDOWN_MS
      triggered = gapOk && quotaOk && coolOk
      if (triggered) {
        this.triggerCount += 1
        this.lastTriggerMs = nowMs
        this.lastKindMs.set(kindKey, nowMs)
      } else {
        hilog.info(DOMAIN, TAG, '事件被节流拦下：%{public}s（gap/quota/cooldown 未满足）', reason)
      }
    }

    const e = new WatchEvent()
    e.id = IdUtils.uuid()
    e.sessionId = this.sessionId
    e.tMs = nowMs
    e.kind = kind
    e.rmssd = rmssd
    e.hr = hr
    e.accelVar = accelVar
    e.reason = reason
    e.triggered = triggered
    if (kind !== WatchEventKind.QUALITY_LOW) {
      this.recentEvent = e
    }

    if (kind !== WatchEventKind.QUALITY_LOW) {
      hilog.info(DOMAIN, TAG, '事件 %{public}s · 触发=%{public}s · %{public}s',
        kind.toString(), triggered ? '是' : '否', reason)
    }
    if (this.onEvent !== null) {
      this.onEvent(e)
    }
  }
}
