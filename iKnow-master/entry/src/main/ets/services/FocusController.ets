import { FocusState, FocusSource, SessionStatus, TaskStatus } from '../models/Enums'
import { FocusSession, FocusEvent, FocusTimelinePoint } from '../models/FocusSession'
import { SessionSnapshot } from '../models/SessionSnapshot'
import { TaskTimelinePoint } from '../models/TaskTimeline'
import { InterventionEvent } from '../models/InterventionEvent'
import { Task } from '../models/Task'
import { QuestionRecord } from '../models/QuestionRecord'
import { FocusDetectionResult } from './ServiceTypes'
import { StorageKey } from '../common/Constants'
import { FocusTuning } from '../common/FocusTuning'
import { PermissionService } from './PermissionService'
import { StorageService } from './StorageService'
import { FocusDetectionService } from './FocusDetectionService'
import { SensorService } from './SensorService'
import { InterventionEngine, InterventionEvalContext } from './InterventionEngine'
import { CompanionDecision } from './ai/CompanionService'
import { IdUtils } from '../utils/IdUtils'

/**
 * 专注控制器 —— 唯一计时源（PRD §8，硬规则 §6/§7/§8）
 *
 *  - 计时用 Date.now() 差值驱动（非 setInterval 计数）：每心跳累加差值，后台长睡时
 *    以 MAX_TICK_DELTA_MS 封顶，避免差值爆炸。
 *  - 每 10 s 落一条 SessionSnapshot，支持崩溃/后台恢复。
 *  - 状态机去抖：confidence < 0.5 忽略（采而不信）；按 FocusTuning 的驻留/冷却参数
 *    决定是否切换（GREEN→黄 5s / 红→黄 5s / 黄→绿 10s；黄 3min / 红 5min 冷却）。
 *  - 进入分心状态时经 InterventionEngine 评估是否干预（无手表 RED 走手机声音+屏幕）。
 *  - FocusBreak 等页面只消费本控制器状态，不得自带计时器。
 */
export class FocusController {
  private static inst: FocusController | null = null
  private tickId: number = -1
  private snapshotId: number = -1
  private session: FocusSession = new FocusSession()
  private tasks: Task[] = []
  private questions: QuestionRecord[] = []
  private running: boolean = false
  private qaMode: boolean = false
  private resting: boolean = false
  private paused: boolean = false
  /** 进入答疑前的状态，退出答疑时还原（避免无条件跳回 FOCUSED） */
  private stateBeforeQA: FocusState = FocusState.FOCUSED
  /** 本次休息的起始时间戳（0 = 未在休息），休息剩余由它现算 */
  private breakStartedAt: number = 0

  // 计时累加器（秒，浮点；显示时取整）
  private totalSec: number = 0
  private focusSec: number = 0
  private distractionSec: number = 0
  private qaSec: number = 0
  private breakSec: number = 0
  private pausedAccum: number = 0

  private state: FocusState = FocusState.FOCUSED
  /** 最近一次感知结果的说明与置信度（用于 UI 呈现「依据」） */
  private lastDetail: string = ''
  private lastConfidence: number = 0
  private stateEnteredAt: number = 0
  private lastTickAt: number = 0
  private sampleAccumMs: number = 0
  private lastYellowAt: number = 0
  private lastRedAt: number = 0

  private timeline: FocusTimelinePoint[] = []
  private events: FocusEvent[] = []
  private currentTaskId: string = ''
  private perceptionMode: string = 'PERCEPTION_FULL'

  private onIntervention: ((d: CompanionDecision, e: InterventionEvent) => void) | null = null
  private lastDecision: CompanionDecision | null = null
  private permSubscribed: boolean = false

  static getInstance(): FocusController {
    if (FocusController.inst === null) {
      FocusController.inst = new FocusController()
    }
    return FocusController.inst
  }

  getSession(): FocusSession {
    return this.session
  }

  getTasks(): Task[] {
    return this.tasks
  }

  getQuestions(): QuestionRecord[] {
    return this.questions
  }

  getState(): FocusState {
    return this.state
  }

  getTotalSec(): number {
    return Math.floor(this.totalSec)
  }

  getFocusSec(): number {
    return Math.floor(this.focusSec)
  }

  getQaSec(): number {
    return Math.floor(this.qaSec)
  }

  isQaMode(): boolean {
    return this.qaMode
  }

  isResting(): boolean {
    return this.resting
  }

  isPaused(): boolean {
    return this.paused
  }

  isRunning(): boolean {
    return this.running
  }

  getPerceptionMode(): string {
    return this.perceptionMode
  }

  getLastDecision(): CompanionDecision | null {
    return this.lastDecision
  }

  /** 最近一次感知依据（说明 + 置信度 0~100） */
  getLastDetail(): string {
    return this.lastDetail
  }

  getLastConfidence(): number {
    return this.lastConfidence
  }

  /** 休息剩余秒数（0 = 不在休息或已结束） */
  getBreakRemainSec(): number {
    if (!this.resting || this.breakStartedAt <= 0) {
      return 0
    }
    const elapsed = Math.floor((Date.now() - this.breakStartedAt) / 1000)
    return Math.max(0, FocusTuning.BREAK_TOTAL_SEC - elapsed)
  }

  // ---------- 当前任务（E1 完成闭环 / B3 任务级归因入口） ----------

  getCurrentTask(): Task | null {
    if (this.currentTaskId.length > 0) {
      for (const t of this.tasks) {
        if (t.id === this.currentTaskId && !t.done) {
          return t
        }
      }
    }
    for (const t of this.tasks) {
      if (!t.done) {
        return t
      }
    }
    return null
  }

  getTaskCount(): number {
    return this.tasks.length
  }

  getCompletedCount(): number {
    return this.tasks.filter((t: Task): boolean => t.done).length
  }

  /** 勾选当前任务完成，下一个未完成任务自动成为当前任务 */
  completeCurrentTask(): boolean {
    const t = this.getCurrentTask()
    if (t === null) {
      return false
    }
    t.done = true
    t.status = TaskStatus.DONE
    this.currentTaskId = ''
    this.recordTaskTimeline()
    return true
  }

  switchToTask(id: string): void {
    this.currentTaskId = id
    this.recordTaskTimeline()
  }

  private recordTaskTimeline(): void {
    const p = new TaskTimelinePoint()
    p.minuteOffset = Math.floor(this.totalSec / 60)
    p.taskId = this.currentTaskId
    p.level = this.levelForState(this.state)
    this.session.taskTimeline.push(p)
  }

  /** UI 注册干预回调（Phase 1 用于弹窗/横幅呈现）；传 null 取消注册 */
  setOnIntervention(cb: ((d: CompanionDecision, e: InterventionEvent) => void) | null): void {
    this.onIntervention = cb
  }

  /** 开始一个专注会话 */
  start(tasks: Task[]): void {
    this.tasks = tasks
    this.session = new FocusSession()
    this.session.id = IdUtils.uuid()
    this.session.title = tasks.length > 0 ? tasks[0].subject : '专注学习'
    this.session.startTime = Date.now()
    this.session.taskIds = tasks.map((t: Task): string => t.id)
    this.session.plannedDuration = tasks.reduce((sum: number, t: Task): number => sum + t.estimatedDuration, 0)
    this.session.status = SessionStatus.RUNNING
    this.session.perceptionMode = PermissionService.getInstance().snapshot().camera ? 'PERCEPTION_FULL' : 'PERCEPTION_TIMER_ONLY'
    this.perceptionMode = this.session.perceptionMode
    this.currentTaskId = tasks.length > 0 ? tasks[0].id : ''
    this.resetCounters()
    this.running = true
    this.state = FocusState.FOCUSED
    this.stateEnteredAt = Date.now()
    this.questions = []
    InterventionEngine.getInstance().setSessionId(this.session.id)
    this.subscribePermission()

    if (PermissionService.getInstance().snapshot().camera) {
      FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
        this.onDetection(r)
      })
    }
    this.tickId = setInterval(() => {
      this.recomputeTick()
    }, FocusTuning.TICK_MS)
    this.snapshotId = setInterval(() => {
      this.writeSnapshot()
    }, FocusTuning.SNAPSHOT_INTERVAL_MS)
    this.pushLive()
    StorageService.getInstance().saveKv(StorageKey.ACTIVE_SESSION_ID, this.session.id).catch(() => {})
  }

  private subscribePermission(): void {
    if (this.permSubscribed) {
      return
    }
    this.permSubscribed = true
    PermissionService.getInstance().onChange((a) => {
      if (!a.camera) {
        FocusDetectionService.getInstance().stop()
        this.perceptionMode = 'PERCEPTION_TIMER_ONLY'
      } else if (this.running && !this.qaMode && !this.resting && !this.paused) {
        this.perceptionMode = 'PERCEPTION_FULL'
        FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
          this.onDetection(r)
        })
      }
    })
  }

  private resetCounters(): void {
    this.totalSec = 0
    this.focusSec = 0
    this.distractionSec = 0
    this.qaSec = 0
    this.breakSec = 0
    this.pausedAccum = 0
    this.stateEnteredAt = Date.now()
    this.lastTickAt = Date.now()
    this.sampleAccumMs = 0
    this.lastYellowAt = 0
    this.lastRedAt = 0
    this.timeline = []
    this.events = []
    this.qaMode = false
    this.resting = false
    this.paused = false
    this.stateBeforeQA = FocusState.FOCUSED
    this.breakStartedAt = 0
    this.lastDetail = ''
    this.lastConfidence = 0
  }

  /** 计时心跳：用 Date.now() 差值累加（硬规则 §7） */
  private recomputeTick(): void {
    const now = Date.now()
    if (!this.running) {
      this.lastTickAt = now
      return
    }
    const dtMs = Math.min(now - this.lastTickAt, FocusTuning.MAX_TICK_DELTA_MS)
    this.lastTickAt = now
    const dt = dtMs / 1000
    // 墙钟：包含休息 / 暂停 / 答疑（PRD §5 总学习 = 墙钟 − 休息 − 暂停）
    this.totalSec += dt
    if (this.paused) {
      this.pausedAccum += dt
      return
    }
    if (this.resting) {
      this.breakSec += dt
      this.pushLive()
      return
    }
    if (this.qaMode) {
      this.qaSec += dt
    } else if (this.state === FocusState.FOCUSED) {
      this.focusSec += dt
    } else {
      this.distractionSec += dt
    }
    this.sampleAccumMs += dtMs
    if (this.sampleAccumMs >= FocusTuning.TIMELINE_SAMPLE_MS) {
      this.sampleAccumMs = 0
      this.sampleTimeline()
    }
    this.pushLive()
  }

  /** 摄像头检测回调 → 去抖状态机（硬规则 §9 采而不信） */
  private onDetection(r: FocusDetectionResult): void {
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return
    }
    this.lastDetail = r.detail
    this.lastConfidence = Math.round(r.confidence)
    if (r.confidence < FocusTuning.CONFIDENCE_FLOOR) {
      // 采而不信：仅记账，不切换
      this.recordEvent(this.mapState(r.state), r.source, r.confidence, 'below-confidence')
      return
    }
    const target = this.mapState(r.state)
    if (target === this.state) {
      this.recordEvent(target, r.source, r.confidence, 'no-transit')
      return
    }
    const now = Date.now()
    const dwellOk = now - this.stateEnteredAt >= this.dwellFor(target)
    const coolOk = this.cooldownElapsed(target)
    if (dwellOk && coolOk) {
      this.transitionTo(target, r.confidence, r.source, r.detail)
    } else {
      this.recordEvent(target, r.source, r.confidence, 'debounced')
    }
  }

  private dwellFor(target: FocusState): number {
    if (target === FocusState.SLIGHTLY_DISTRACTED) {
      return FocusTuning.DWELL_GREEN_TO_YELLOW_MS
    }
    if (target === FocusState.DISTRACTED) {
      return FocusTuning.DWELL_RED_TO_YELLOW_MS
    }
    if (target === FocusState.FOCUSED) {
      return FocusTuning.DWELL_YELLOW_TO_GREEN_MS
    }
    return FocusTuning.MIN_DWELL_MS
  }

  private cooldownElapsed(target: FocusState): boolean {
    const now = Date.now()
    if (target === FocusState.SLIGHTLY_DISTRACTED) {
      return now - this.lastYellowAt >= FocusTuning.YELLOW_COOLDOWN_MS
    }
    if (target === FocusState.DISTRACTED) {
      return now - this.lastRedAt >= FocusTuning.RED_COOLDOWN_MS
    }
    return true
  }

  private mapState(s: FocusState): FocusState {
    if (s === FocusState.SLIGHTLY_DISTRACTED) {
      return FocusState.SLIGHTLY_DISTRACTED
    }
    if (s === FocusState.DISTRACTED) {
      return FocusState.DISTRACTED
    }
    return FocusState.FOCUSED
  }

  private transitionTo(target: FocusState, confidence: number, source: FocusSource, detail: string): void {
    const now = Date.now()
    this.state = target
    this.stateEnteredAt = now
    if (target === FocusState.SLIGHTLY_DISTRACTED) {
      this.lastYellowAt = now
    } else if (target === FocusState.DISTRACTED) {
      this.lastRedAt = now
    }
    this.recordEvent(target, source, confidence, detail)
    this.sampleTimeline()
    this.pushLive()
    if (target === FocusState.SLIGHTLY_DISTRACTED || target === FocusState.DISTRACTED) {
      this.evaluateIntervention()
    }
  }

  private recordEvent(state: FocusState, source: FocusSource, confidence: number, detail: string): void {
    const e = new FocusEvent()
    e.id = IdUtils.uuid()
    e.sessionId = this.session.id
    e.timestamp = Date.now()
    e.state = state
    e.source = source
    e.confidence = confidence
    this.events.push(e)
  }

  private sampleTimeline(): void {
    const p = new FocusTimelinePoint()
    p.minute = Math.floor(this.totalSec / 60)
    p.level = this.levelForState(this.state)
    p.state = this.state
    this.timeline.push(p)
  }

  /** 曲线等级由状态确定性推导 —— 不再用随机数，保证曲线/最佳时段/疲劳点可复现 */
  private levelForState(s: FocusState): number {
    if (s === FocusState.FOCUSED) {
      return 92
    }
    if (s === FocusState.SLIGHTLY_DISTRACTED) {
      return 62
    }
    return 30
  }

  /** 评估是否干预（经 InterventionEngine，Phase 0 仅决策+记录，UI 呈现留待第 1 步） */
  private evaluateIntervention(): void {
    const ctx: InterventionEvalContext = {
      sessionId: this.session.id,
      state: this.state,
      sinceMs: Date.now() - this.stateEnteredAt,
      hasWatch: SensorService.getInstance().isWristPresent(),
      personality: AppStorage.get<string>(StorageKey.USER_PERSONALITY) ?? 'GENTLE',
      perceptionMode: this.perceptionMode,
      recent: InterventionEngine.getInstance().getRecent()
    }
    const res = InterventionEngine.getInstance().evaluate(ctx)
    this.lastDecision = res.decision
    if (res.event !== null) {
      this.session.interventions.push(res.event)
      if (this.onIntervention !== null) {
        this.onIntervention(res.decision, res.event as InterventionEvent)
      }
    }
  }

  /** 进入 AI 答疑：停止摄像头监测，计时不中断（计入总时长，不计净专注） */
  startQA(): void {
    // 暂停/休息中不允许进答疑，否则退回时状态会被覆盖
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return
    }
    this.stateBeforeQA = this.state
    this.qaMode = true
    this.state = FocusState.QA_MODE
    this.stateEnteredAt = Date.now()
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  endQA(): void {
    if (!this.running || !this.qaMode) {
      return
    }
    this.qaMode = false
    this.restoreAfterQA()
    this.stateEnteredAt = Date.now()
    if (PermissionService.getInstance().snapshot().camera) {
      FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
        this.onDetection(r)
      })
    }
    this.pushLive()
  }

  /** 还原进入答疑前的状态（黄/红不丢失），异常值一律回落 FOCUSED */
  private restoreAfterQA(): void {
    const s = this.stateBeforeQA
    if (s === FocusState.SLIGHTLY_DISTRACTED || s === FocusState.DISTRACTED) {
      this.state = s
    } else {
      this.state = FocusState.FOCUSED
    }
  }

  addQuestion(q: QuestionRecord): void {
    this.questions.push(q)
  }

  /** 暂停 */
  pause(): void {
    if (!this.running || this.paused || this.resting || this.qaMode) {
      return
    }
    this.paused = true
    this.state = FocusState.PAUSED
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  resume(): void {
    if (!this.running || !this.paused) {
      return
    }
    this.paused = false
    this.state = FocusState.FOCUSED
    this.stateEnteredAt = Date.now()
    if (PermissionService.getInstance().snapshot().camera) {
      FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
        this.onDetection(r)
      })
    }
    this.pushLive()
  }

  /** 休息：停止检测，暂停专注统计（计入墙钟，计入休息） */
  startBreak(): void {
    if (!this.running || this.resting || this.qaMode) {
      return
    }
    this.paused = false
    this.resting = true
    this.breakStartedAt = Date.now()
    this.state = FocusState.RESTING
    this.stateEnteredAt = Date.now()
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  endBreak(): void {
    if (!this.running || !this.resting) {
      return
    }
    this.resting = false
    this.breakStartedAt = 0
    this.state = FocusState.FOCUSED
    this.stateEnteredAt = Date.now()
    if (PermissionService.getInstance().snapshot().camera) {
      FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
        this.onDetection(r)
      })
    }
    this.pushLive()
  }

  /** 延长休息（「再休息 5 分钟」），休息态由本控制器独占 */
  extendBreak(sec: number): void {
    if (!this.resting) {
      return
    }
    this.breakStartedAt = Date.now() - Math.max(0, FocusTuning.BREAK_TOTAL_SEC - sec) * 1000
    this.pushLive()
  }

  /** 手动切换状态（演示用，长按呼吸灯触发） */
  demoCycleState(): void {
    if (this.qaMode || this.resting || this.paused) {
      return
    }
    if (this.state === FocusState.FOCUSED) {
      FocusDetectionService.getInstance().simulate(FocusState.SLIGHTLY_DISTRACTED)
    } else if (this.state === FocusState.SLIGHTLY_DISTRACTED) {
      FocusDetectionService.getInstance().simulate(FocusState.DISTRACTED)
    } else {
      FocusDetectionService.getInstance().resume()
    }
  }

  /** 崩溃/后台恢复：从快照恢复计时累加器与状态（恢复弹窗在第 1 步接入） */
  restore(snap: SessionSnapshot, tasks?: Task[]): void {
    if (tasks !== undefined) {
      this.tasks = tasks
    }
    this.session = new FocusSession()
    this.session.id = snap.sessionId
    this.session.status = SessionStatus.RUNNING
    this.session.perceptionMode = snap.perceptionMode
    this.perceptionMode = snap.perceptionMode
    this.totalSec = snap.totalSec
    this.focusSec = snap.focusSec
    this.distractionSec = snap.distractionSec
    this.qaSec = snap.qaSec
    this.breakSec = snap.breakSec
    this.state = (snap.state as FocusState)
    this.resting = (this.state === FocusState.RESTING)
    this.breakStartedAt = this.resting ? Date.now() : 0
    this.stateEnteredAt = Date.now()
    this.running = true
    this.lastTickAt = Date.now()
    this.tickId = setInterval(() => {
      this.recomputeTick()
    }, FocusTuning.TICK_MS)
    this.snapshotId = setInterval(() => {
      this.writeSnapshot()
    }, FocusTuning.SNAPSHOT_INTERVAL_MS)
    this.pushLive()
    if (PermissionService.getInstance().snapshot().camera) {
      FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
        this.onDetection(r)
      })
    }
    StorageService.getInstance().saveKv(StorageKey.ACTIVE_SESSION_ID, this.session.id).catch(() => {})
  }

  /** 结束会话：落盘前的收尾 */
  finalize(): FocusSession {
    if (this.tickId >= 0) {
      clearInterval(this.tickId)
      this.tickId = -1
    }
    if (this.snapshotId >= 0) {
      clearInterval(this.snapshotId)
      this.snapshotId = -1
    }
    FocusDetectionService.getInstance().stop()
    this.running = false
    this.qaMode = false
    this.resting = false
    this.paused = false
    this.breakStartedAt = 0
    this.session.endTime = Date.now()
    this.session.totalDuration = Math.floor(this.totalSec)
    this.session.focusDuration = Math.floor(this.focusSec)
    this.session.distractionDuration = Math.floor(this.distractionSec)
    this.session.qaDuration = Math.floor(this.qaSec)
    this.session.breakDuration = Math.floor(this.breakSec)
    this.session.pausedDuration = Math.floor(this.pausedAccum)
    this.session.timeline = this.timeline
    this.session.events = this.events
    this.session.completedTaskIds = this.tasks.filter((t: Task): boolean => t.done).map((t: Task): string => t.id)
    this.session.status = SessionStatus.FINISHED
    this.session.updatedAt = Date.now()
    // 落最终快照 + 持久化干预事件 + 任务归属曲线
    this.writeSnapshot().catch(() => {})
    if (this.session.interventions.length > 0) {
      StorageService.getInstance().saveInterventions(this.session.interventions).catch(() => {})
    }
    if (this.session.taskTimeline.length > 0) {
      StorageService.getInstance().saveTaskTimeline(this.session.taskTimeline, this.session.id).catch(() => {})
    }
    StorageService.getInstance().saveKv(StorageKey.ACTIVE_SESSION_ID, '').catch(() => {})
    this.pushLive()
    return this.session
  }

  /**
   * 丢弃当前会话并复位运行时（E15：清数据时调用）。
   * 与 finalize() 的区别：不落盘、不计入统计，直接把计时与状态清空。
   */
  abort(): void {
    if (this.tickId >= 0) {
      clearInterval(this.tickId)
      this.tickId = -1
    }
    if (this.snapshotId >= 0) {
      clearInterval(this.snapshotId)
      this.snapshotId = -1
    }
    FocusDetectionService.getInstance().stop()
    this.running = false
    this.qaMode = false
    this.resting = false
    this.paused = false
    this.state = FocusState.FOCUSED
    this.stateEnteredAt = 0
    this.currentTaskId = ''
    this.tasks = []
    this.questions = []
    this.timeline = []
    this.events = []
    this.session = new FocusSession()
    this.totalSec = 0
    this.focusSec = 0
    this.distractionSec = 0
    this.qaSec = 0
    this.breakSec = 0
    this.pausedAccum = 0
    this.breakStartedAt = 0
    StorageService.getInstance().saveKv(StorageKey.ACTIVE_SESSION_ID, '').catch(() => {})
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_ELAPSED, 0)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_NET, 0)
    AppStorage.setOrCreate<string>(StorageKey.FOCUS_STATE, FocusState.FOCUSED)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_QA_ELAPSED, 0)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_BREAK_REMAIN, 0)
  }

  private async writeSnapshot(): Promise<void> {
    if (!this.running) {
      return
    }
    const snap = new SessionSnapshot()
    snap.sessionId = this.session.id
    snap.ts = Date.now()
    snap.totalSec = Math.floor(this.totalSec)
    snap.focusSec = Math.floor(this.focusSec)
    snap.distractionSec = Math.floor(this.distractionSec)
    snap.qaSec = Math.floor(this.qaSec)
    snap.breakSec = Math.floor(this.breakSec)
    snap.currentTaskId = this.currentTaskId
    snap.state = this.state
    snap.perceptionMode = this.perceptionMode
    try {
      await StorageService.getInstance().saveSnapshot(snap)
      this.session.snapshotsCount += 1
      this.session.lastSnapshotAt = snap.ts
    } catch (e) {
      // 存储失败不影响计时
    }
  }

  private pushLive(): void {
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_ELAPSED, Math.floor(this.totalSec))
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_NET, Math.floor(this.focusSec))
    AppStorage.setOrCreate<string>(StorageKey.FOCUS_STATE, this.state)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_QA_ELAPSED, Math.floor(this.qaSec))
    AppStorage.setOrCreate<string>(StorageKey.PERCEPTION_MODE, this.perceptionMode)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_BREAK_REMAIN, this.getBreakRemainSec())
  }
}
