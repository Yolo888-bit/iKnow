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
import { ObservationRecord, WatchEvent, WatchEventKind } from '../models/WatchSignal'
import { WatchEventEngine } from './WatchEventEngine'
import { WatchSignalSource } from './WatchSignalSource'
import { SimActivity } from './WatchSignalSimulator'
import { RealWatchSignalSource } from './RealWatchSignalSource'
import { BleWatchService } from './BleWatchService'
import { ObservationQueue, FrameRecognizer } from './ObservationQueue'
import { CameraService } from './CameraService'
import { SimulatedRecognizer } from './SimulatedRecognizer'
import { GatewayRecognizer } from './GatewayRecognizer'
import { AIService } from './AIService'
import { FeedbackService } from './FeedbackService'
import { hilog } from '@kit.PerformanceAnalysisKit'
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
 *  - 计时用 Date.now() 差值驱动（非 setInterval 计数），按**段**结算：每一段的时长在
 *    "状态/模式切换"时与每次心跳时用墙钟差值结清，**不封顶** —— 手机扣在桌上、锁屏学习
 *    的那段时间正是本产品的核心场景，封顶会让 30 分钟的专注只涨几秒，时长与专注率一起失真。
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
  /** 当前段起点：段 = 一段"所处模式/状态不变"的时间，切换与心跳时用墙钟结清（见 settleSegment） */
  private segStartAt: number = 0

  private state: FocusState = FocusState.FOCUSED
  /** 最近一次感知结果的说明与置信度（用于 UI 呈现「依据」） */
  private lastDetail: string = ''
  private lastConfidence: number = 0
  /** 演示注入标记：为真时下一次感知结论跳过去抖/冷却（用完即清） */
  private manualInject: boolean = false
  /** 工作台注入的"待生效"标记：由 onObservation 消费并转成 manualInject */
  private simInjectPending: boolean = false
  /** 演示注入的延迟结算定时器 id（-1 = 无） */
  private simSettleTimerId: number = -1
  /** 注入标记的宽限期清理定时器 id（-1 = 无） */
  private simInjectClearId: number = -1
  private stateEnteredAt: number = 0
  private lastTickAt: number = 0
  private sampleAccumMs: number = 0
  private lastYellowAt: number = 0
  private lastRedAt: number = 0

  private timeline: FocusTimelinePoint[] = []
  /** 本次会话的手表事件（随会话落库） */
  private watchEvents: WatchEvent[] = []
  /** 本次会话的云端观察记录（随会话落库） */
  private observations: ObservationRecord[] = []
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

  /** 当前任务 id（未显式指定时回落到第一个未完成任务）；用于列表高亮 */
  getCurrentTaskId(): string {
    const t = this.getCurrentTask()
    return t !== null ? t.id : ''
  }

  /**
   * 按 id 设置任务完成状态 —— 列表勾选与"撤销误勾"都走这里。
   * 返回是否命中该任务。
   */
  setTaskDone(id: string, done: boolean): boolean {
    for (const t of this.tasks) {
      if (t.id === id) {
        t.done = done
        t.status = done ? TaskStatus.DONE : TaskStatus.TODO
        if (done && this.currentTaskId === id) {
          this.currentTaskId = ''
        }
        this.recordTaskTimeline()
        return true
      }
    }
    return false
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
    this.bindPerception()
  }

  /**
   * 绑定感知链并启动时钟：感知结论订阅 → 手表事件 → 信号源 → 观察队列 → 识别器 → tick / 快照定时器。
   *
   * `start()` 与 `restore()` 必须共用这一步。崩溃或后台被杀后选「继续专注」，
   * 如果只恢复计时器、不重建这条链，会话会看起来在跑、其实永远不来任何干预 ——
   * 这比直接崩掉更难发现（用户以为在感知，实际上链路是断的）。
   */
  private bindPerception(): void {
    InterventionEngine.getInstance().setSessionId(this.session.id)
    this.subscribePermission()

    // 感知结论的订阅与"是否开摄像头"**解耦**：未授权摄像头时 start() 内部不会启动轮询，
    // 但仍会注册回调。否则手表事件/模拟工作台算出的结论会"没人接"，
    // 表现为"控制台点了没反应"（仅计时模式下整条链路是断的）。
    FocusDetectionService.getInstance().beginSession()
    this.subscribeDetection()
    // 手表事件驱动（复赛为合成信号）：产出"状态变化待确认"事件
    this.watchEvents = []
    this.observations = []
    // 时基取"本链开始拉起的这一刻"：恢复会话时 session.startTime 没有快照可还原（= 0），
    // 用 0 会让基线硬超时被瞬间判定为已过；而引擎的样本缓冲本来就是从此刻重新累积的
    WatchEventEngine.getInstance().start(this.session.id, Date.now(),
      (e: WatchEvent) => {
        this.onWatchEvent(e)
      })
    // 信号源选择：**真表已连 → 真实信号；否则按模拟开关决定是否用合成信号**。
    // 两条路都接同一个 WatchEventEngine，算法完全一致。
    if (BleWatchService.getInstance().isConnected()) {
      RealWatchSignalSource.getInstance().start()
      hilog.info(0x0000, 'iKnow.Focus', '信号源=真实手表（BLE 心率/RR + 手机加速度）')
    } else {
      const raw: number | undefined = AppStorage.get<number>(StorageKey.SIM_MODE)
      const simOn = raw === undefined ? true : raw === 1
      if (simOn) {
        WatchSignalSource.getInstance().start(WatchEventEngine.getInstance())
        hilog.info(0x0000, 'iKnow.Focus', '信号源=合成信号（模拟模式）')
      } else {
        hilog.info(0x0000, 'iKnow.Focus', '信号源=无（模拟关闭且未连接手表，不产生信号）')
      }
    }
    // 观察队列：结果回调做规则组合
    ObservationQueue.getInstance().setOnObservation((o: ObservationRecord) => {
      this.onObservation(o)
    })
    // 识别器按"真实链路是否可用"自动选择：**网关已配置 且 本机有摄像头**才走真实识别；
    // 否则用模拟识别源（结果与合成手表阶段对应，并在 evidence/日志里标注为模拟）。
    // 同一份代码：真机上是真实识别，无摄像头的演示环境自动降级，业务逻辑一行不改。
    let rec: FrameRecognizer = SimulatedRecognizer.getInstance()
    const camCtx = StorageService.getInstance().appContext()
    const hasCamera = camCtx !== null && CameraService.getInstance().probe(camCtx) > 0
    if (AIService.getInstance().isGatewayReady() && hasCamera) {
      rec = GatewayRecognizer.getInstance()
    }
    ObservationQueue.getInstance().setRecognizer(rec)
    hilog.info(0x0000, 'iKnow.Focus', '识别器=%{public}s（网关=%{public}s 摄像头=%{public}s）',
      AIService.getInstance().isGatewayReady() && hasCamera ? '真实多模态' : '模拟源',
      AIService.getInstance().isGatewayReady() ? '已配置' : '未配置',
      hasCamera ? '有' : '无')
    this.tickId = setInterval(() => {
      this.recomputeTick()
    }, FocusTuning.TICK_MS)
    this.snapshotId = setInterval(() => {
      this.writeSnapshot()
    }, FocusTuning.SNAPSHOT_INTERVAL_MS)
    this.pushLive()
    StorageService.getInstance().saveKv(StorageKey.ACTIVE_SESSION_ID, this.session.id).catch(() => {})
  }

  /**
   * 注册感知结论回调。
   * 是否"轮询摄像头"由 `FocusDetectionService.start()` 内部按授权决定，
   * 但**回调总是要注册** —— 否则手表事件/模拟工作台的结论无处送达。
   */
  private subscribeDetection(): void {
    FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
      this.onDetection(r)
    })
  }

  private subscribePermission(): void {
    if (this.permSubscribed) {
      return
    }
    this.permSubscribed = true
    PermissionService.getInstance().onChange((a) => {
      if (!a.camera) {
        // 关掉轮询，但保留回调，避免"降级为仅计时"时把感知结论的出口也一起关掉
        FocusDetectionService.getInstance().stop()
        // 相机会话是独占资源：撤销授权必须真的把它放掉，否则指示灯一直亮、抓拍也抢不到相机
        CameraService.getInstance().stopPreview()
        this.subscribeDetection()
        this.perceptionMode = 'PERCEPTION_TIMER_ONLY'
      } else if (this.running && !this.qaMode && !this.resting && !this.paused) {
        this.perceptionMode = 'PERCEPTION_FULL'
        this.subscribeDetection()
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
    this.segStartAt = Date.now()
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
    this.manualInject = false
    this.simInjectPending = false
    this.clearSimTimer()
  }

  /** 清掉演示注入的延迟结算定时器（会话结束/复位时必调，避免回调打到已结束的会话） */
  private clearSimTimer(): void {
    if (this.simSettleTimerId >= 0) {
      clearTimeout(this.simSettleTimerId)
      this.simSettleTimerId = -1
    }
    if (this.simInjectClearId >= 0) {
      clearTimeout(this.simInjectClearId)
      this.simInjectClearId = -1
    }
  }

  /**
   * 段结算：把从 segStartAt 到 now 的这段墙钟时间，按**当前所处模式**记入对应累计值。
   *
   * 墙钟包含休息 / 暂停 / 答疑（PRD §5 总学习 = 墙钟 − 休息 − 暂停）。
   * 关键点：**不封顶**。原来每 tick 只加 min(差值, 5 s)，息屏/后台的空档被截成 5 秒 ——
   * 而"手机扣在桌上学习"正是本产品的前提，这条封顶等于把核心场景的时长整段丢掉。
   * 状态/模式切换处都会先结算，段的边界因此始终落在真实的切换时刻上。
   */
  private settleSegment(now: number): void {
    const dt = (now - this.segStartAt) / 1000
    this.segStartAt = now
    if (!this.running || dt <= 0) {
      return
    }
    this.totalSec += dt
    if (this.paused) {
      this.pausedAccum += dt
    } else if (this.resting) {
      this.breakSec += dt
    } else if (this.qaMode) {
      this.qaSec += dt
    } else if (this.state === FocusState.FOCUSED) {
      this.focusSec += dt
    } else {
      this.distractionSec += dt
    }
  }

  /** 计时心跳：结算当前段 + 驱动曲线采样与 UI 刷新（硬规则 §7） */
  private recomputeTick(): void {
    const now = Date.now()
    this.settleSegment(now)
    if (!this.running) {
      this.lastTickAt = now
      return
    }
    const dtMs = now - this.lastTickAt
    this.lastTickAt = now
    if (this.paused) {
      return
    }
    if (this.resting) {
      this.pushLive()
      return
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
    // 演示注入标记是**一次性**的：无论本次是否真的切换，都在这里消费掉
    const manual = this.manualInject
    this.manualInject = false
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
    const dwellOk = manual || now - this.stateEnteredAt >= this.dwellFor(target)
    const coolOk = manual || this.cooldownElapsed(target)
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

  /**
   * 手表事件回调。
   *
   * 语义边界：手表线索**本身不足以判定任何状态**，所以这里不产生结论；
   * 只有 `triggered === true` 时才去采集画面、交给云端识别"在做什么"，
   * 结果回来后由 `onObservation()` 用规则翻译成可解释的结论。
   * 采集/识别全程异步，不阻塞计时。
   */
  private onWatchEvent(e: WatchEvent): void {
    // 平稳窗口：把状态带回专注。没有这一条，状态只能"变可疑"、永远回不到绿，
    // 用户点了「静息/正常/静止」就会觉得"点了没反应"。
    if (e.kind === WatchEventKind.CALM) {
      FocusDetectionService.getInstance().submit(
        FocusState.FOCUSED, '信号平稳', 70, FocusSource.CAMERA)
      return
    }
    this.watchEvents.push(e)
    if (e.triggered) {
      this.triggerVisualCheck(e)
    }
  }

  /** 触发一次短片段采集并交给云端（异步，不阻塞） */
  private triggerVisualCheck(e: WatchEvent): void {
    // 未授权摄像头（仅计时模式）不抓拍、不上传：授权是采集与云端识别的前提
    if (!PermissionService.getInstance().snapshot().camera) {
      return
    }
    // 答疑 / 休息 / 暂停期间不抓拍：那段时间本就"不打扰"，也不该留下分心记录
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return
    }
    const ctx = StorageService.getInstance().appContext()
    if (ctx === null) {
      return
    }
    // 无摄像头时**不要空等采集超时**（BURST_TIMEOUT_MS = 3.5s）：那是纯等待，
    // 会让"点一下 → 看到红灯"延迟到 5 秒以上。识别器此时是模拟的，不需要帧。
    if (CameraService.getInstance().probe(ctx) === 0) {
      ObservationQueue.getInstance().enqueue(this.session.id, e, [])
      return
    }
    CameraService.getInstance().captureBurst(ctx)
      .then((frames: ArrayBuffer[]) => {
        ObservationQueue.getInstance().enqueue(this.session.id, e, frames)
      })
      .catch(() => {
        // 采集失败（无摄像头/权限/被占用）不影响专注流程
      })
  }

  /**
   * 云端返回"可观察状态"后的规则组合（App 侧，可解释）。
   * '无法判断' 不产生任何结论 —— 宁可不提示，也不猜。
   */
  private onObservation(o: ObservationRecord): void {
    // 答疑 / 休息 / 暂停期间不产生结论、不触达：异步识别可能在进入这些状态之后才回来，
    // 那时再震动/计分心是误伤（采集入口也有同样的守卫，这里兜住"在途"的结果）
    if (!this.running || this.qaMode || this.resting || this.paused) {
      this.simInjectPending = false
      hilog.info(0x0000, 'iKnow.Focus', '非专注态收到观察结果，不产生结论（如实不猜）')
      return
    }
    this.observations.push(o)
    const conf = Math.round(o.confidence * 100)
    const svc = FocusDetectionService.getInstance()
    // 工作台注入：这次结论是用户显式指定的，等价于一次人工确认 → 允许跳过去抖
    const injected = this.simInjectPending
    this.simInjectPending = false
    this.manualInject = injected
    if (o.activity === '看手机' || o.handheld) {
      svc.submit(FocusState.DISTRACTED, `云端识别：${o.activity}`, conf, FocusSource.CAMERA)
      // 只对"确认分心"做触达；趴桌/无法判断都不震，避免变成骚扰
      FeedbackService.getInstance().vibrateOnce()
      FeedbackService.getInstance().speak('检测到你在看手机，要回来吗？')
    } else if (o.activity === '离开') {
      svc.submit(FocusState.DISTRACTED, '云端识别：画面中没有人', conf, FocusSource.CAMERA)
      FeedbackService.getInstance().vibrateOnce()
    } else if (o.activity === '趴桌') {
      // 趴桌更像疲劳，不等于分心，因此只给轻提示
      svc.submit(FocusState.SLIGHTLY_DISTRACTED, '云端识别：趴桌（可能是疲劳）', conf, FocusSource.CAMERA)
    } else if (o.activity === '做题' || o.activity === '看书') {
      // 确认为在学习 → 允许事件引擎用新窗口缓慢更新基线
      WatchEventEngine.getInstance().setLearningConfirmed(true)
      svc.submit(FocusState.FOCUSED, `云端识别：${o.activity}`, conf, FocusSource.CAMERA)
    } else {
      // 多人 / 无法判断：不产生任何结论，也不要把注入标记留给下一次判定
      this.manualInject = false
      hilog.info(0x0000, 'iKnow.Focus', '观察结果「%{public}s」不产生结论（如实不猜）', o.activity)
    }
  }

  /** 本次会话的手表事件（供复盘与排查） */
  getWatchEvents(): WatchEvent[] {
    return this.watchEvents
  }

  /** 本次会话的云端观察记录（供复盘时间线） */
  getObservations(): ObservationRecord[] {
    return this.observations
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
    // 先结清上一段：段的边界必须落在真实切换时刻，不能被心跳的相位带偏
    this.settleSegment(now)
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
    this.settleSegment(Date.now())
    this.stateBeforeQA = this.state
    this.qaMode = true
    this.state = FocusState.QA_MODE
    this.stateEnteredAt = Date.now()
    // 只停摄像头轮询；结论回调保留（否则从答疑回来后感知链就断了）
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  endQA(): void {
    if (!this.running || !this.qaMode) {
      return
    }
    this.settleSegment(Date.now())
    this.qaMode = false
    this.restoreAfterQA()
    this.stateEnteredAt = Date.now()
    this.subscribeDetection()
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
    this.settleSegment(Date.now())
    this.paused = true
    this.state = FocusState.PAUSED
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  resume(): void {
    if (!this.running || !this.paused) {
      return
    }
    this.settleSegment(Date.now())
    this.paused = false
    this.state = FocusState.FOCUSED
    this.stateEnteredAt = Date.now()
    this.subscribeDetection()
    this.pushLive()
  }

  /** 休息：停止检测，暂停专注统计（计入墙钟，计入休息） */
  startBreak(): void {
    if (!this.running || this.resting || this.qaMode) {
      return
    }
    this.settleSegment(Date.now())
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
    this.settleSegment(Date.now())
    this.resting = false
    this.breakStartedAt = 0
    this.state = FocusState.FOCUSED
    this.stateEnteredAt = Date.now()
    this.subscribeDetection()
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

  /**
   * 呼吸灯点击：按 做题 → 趴桌 → 看手机 → 做题 循环（演示用）。
   * 走 `simulateObservation`，因此是**立刻生效**的。
   */
  demoCycleState(): void {
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return
    }
    if (this.state === FocusState.FOCUSED) {
      this.simulateObservation('趴桌')
    } else if (this.state === FocusState.SLIGHTLY_DISTRACTED) {
      this.simulateObservation('看手机')
    } else {
      this.simulateObservation('做题')
    }
  }

  /**
   * 用户点「继续专注」= 一次人工确认。
   *
   * 必须走人工确认通道：普通判定要满足 dwell（黄→绿 10 秒）与冷却才能切换，
   * 用户已经表态了却还要等，卡片一消失、灯还是红的，看起来就是"没生效"。
   * 与工作台注入同一条通道 —— 只影响这一次，用完即清。
   */
  resumeByUser(): void {
    this.manualInject = true
    FocusDetectionService.getInstance().resume()
  }

  /**
   * 模拟工作台 · **状态注入**：直接注入一条"云端识别结果"，立刻走规则组合 → 状态 → 干预 → UI。
   *
   * 为什么这一层可以直接注入：无摄像头时，"触发 → 采集 → 识别"三段没有真实输入，
   * 让合成信号去撞真实的基线/阈值只会得到"无结论"（表现为点了没反应）。
   * 而**识别结果之后**的部分（规则组合 / 干预预算 / 状态机 / 卡片）都是真实链路，
   * 注入它能当场看到真实反应。注入的记录 evidence 里写明"模拟"，复盘时间线可见。
   *
   * @returns false = 当前没有进行中的会话（调用方应提示先开始专注）
   */
  simulateObservation(activity: string, confidence: number = FocusTuning.SIM_INJECT_CONFIDENCE): boolean {
    // 答疑 / 休息 / 暂停不算专注时间：返回 false 让界面如实提示，而不是"提示成功但什么都没发生"
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return false
    }
    // 自动把合成信号阶段也对齐，避免"工作台显示看手机、信号控制台还写着 STUDY"的自相矛盾
    WatchSignalSource.getInstance().setPhase(SimActivity.phaseOf(activity))
    const o = new ObservationRecord()
    o.id = IdUtils.uuid()
    o.sessionId = this.session.id
    o.tMs = Date.now()
    o.activity = activity
    o.handheld = activity === '看手机'
    o.facingDesk = activity === '做题' || activity === '看书'
    o.confidence = confidence
    o.evidence = '模拟注入：由模拟工作台指定的可观察状态（本机无摄像头，非真实识别）'
    this.simInjectPending = true
    hilog.info(0x0000, 'iKnow.Focus', '[模拟注入] activity=%{public}s', activity)
    this.onObservation(o)
    return true
  }

  /**
   * 模拟工作台 · **信号注入**：切换合成信号阶段，等新阶段样本填满窗口后
   * 强制结算一次（`WatchEventEngine.evaluateNow()`）。
   *
   * 与状态注入的分工：这里不改任何阈值，走的是真实的 SQI/基线/触发判定，
   * 用于演示"信号 → 事件 → 采集"这一段；因此它的结论依赖信号强度，
   * 不保证每次都有结论（例如"看手机"的运动特征不足以触发 MOTION_HIGH）。
   *
   * @returns false = 当前没有进行中的会话
   */
  simulateWatchPhase(activity: string): boolean {
    // 同上：非专注态不注入信号
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return false
    }
    WatchSignalSource.getInstance().setPhase(SimActivity.phaseOf(activity))
    WatchEventEngine.getInstance().clearTriggerThrottle()
    this.clearSimTimer()
    this.simSettleTimerId = setTimeout(() => {
      this.simSettleTimerId = -1
      this.simInjectPending = true
      WatchEventEngine.getInstance().evaluateNow()
      // 结论是**异步**回来的（采集 → 识别 → 规则组合），所以不能在这里立刻清标记；
      // 给一个宽限期：真出了结论会被 onObservation 消费，没出结论也会自己过期，
      // 不会把"人工确认"漏给后续的真实判定。
      this.simInjectClearId = setTimeout(() => {
        this.simInjectClearId = -1
        this.simInjectPending = false
      }, FocusTuning.SIM_INJECT_GRACE_MS)
    }, FocusTuning.SIM_INJECT_SETTLE_MS)
    return true
  }

  /** 当前合成信号阶段对应的可观察状态（工作台显示用） */
  getSimulatedActivity(): string {
    return SimActivity.activityOf(WatchSignalSource.getInstance().getPhase())
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
    // 快照里的感知模式可能已经过期（恢复期间撤销了授权）：以当前授权为准，
    // 否则界面会显示「感知中」而实际不抓拍
    this.perceptionMode = PermissionService.getInstance().snapshot().camera
      ? snap.perceptionMode : 'PERCEPTION_TIMER_ONLY'
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
    this.segStartAt = Date.now()
    // 与 start() 共用同一条初始化：只恢复计时、不重建感知链的话，恢复后的会话永远不来任何干预
    this.bindPerception()
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
    WatchSignalSource.getInstance().stop()
    RealWatchSignalSource.getInstance().stop()
    WatchEventEngine.getInstance().stop()
    this.clearSimTimer()
    // 收尾前先结清最后一段，否则"最后一次切换 → 用户点结束"这段时间不会计入任何累计值
    this.settleSegment(Date.now())
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
    // 手表事件随会话落库（观察记录由队列逐条落库）
    if (this.watchEvents.length > 0) {
      StorageService.getInstance().saveWatchEvents(this.watchEvents).catch(() => {})
    }
    ObservationQueue.getInstance().resetSession(this.session.id)
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
    WatchSignalSource.getInstance().stop()
    RealWatchSignalSource.getInstance().stop()
    WatchEventEngine.getInstance().stop()
    this.clearSimTimer()
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
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_RUNNING, 0)
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
    // 运行标志：根页/首页以 @StorageProp 读取，才能响应式地显示“专注进行中”
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_RUNNING, this.running ? 1 : 0)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_ELAPSED, Math.floor(this.totalSec))
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_NET, Math.floor(this.focusSec))
    // 与复盘页「总学习时长」同口径，避免专注页看到的数字比复盘大而显得"对不上"
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_STUDY,
      Math.floor(this.totalSec - this.breakSec - this.pausedAccum))
    AppStorage.setOrCreate<string>(StorageKey.FOCUS_STATE, this.state)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_QA_ELAPSED, Math.floor(this.qaSec))
    AppStorage.setOrCreate<string>(StorageKey.PERCEPTION_MODE, this.perceptionMode)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_BREAK_REMAIN, this.getBreakRemainSec())
  }
}
