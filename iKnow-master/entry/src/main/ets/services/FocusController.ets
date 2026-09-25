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
import { power } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
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
  /**
   * 最近一次"模拟注入抓拍"的诊断结论（给工作台直接显示）。
   * 为什么要它：抓拍失败的原因只在 hilog 里，用户看不到，导致"点了没反应/还是占位图"
   * 无法自证。把原因搬到界面上，一次点击就能定位是探测、配置还是取帧的问题。
   */
  private lastCaptureDiag: string = ''
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

  /**
   * 切后台的时间戳（0 = 当前在前台）。
   * 手机侧的唯一信号：进后台 + 亮屏 = 用户在别的应用上（手机使用）；
   * 熄屏/锁屏 = 手机被放下（本产品的核心学习场景），不算分心。
   * 归属在**回到前台时**用真实时钟一次性结算，避免后台定时器被冻结导致算不准。
   */
  private bgStartedAt: number = 0
  /** 切走那一刻屏幕是否亮着 */
  private bgScreenOn: boolean = false
  /** 切走时是否处于"可判定"的模式（非暂停/非休息/非答疑） */
  private bgEligible: boolean = false

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

  /**
   * 语音提醒的**待定线索**（'' / 'PHONE' / 'AWAY'）。
   *
   * 由 `onObservation()` 在看到明确的观察状态时写入，由 `onDetection()` 在
   * **真正转入「分心」**的那一次判定里消费掉，用完即清 —— 因此它天然受去抖、
   * 置信度地板、形态冷却与干预预算的约束，不会在"没真的分心"时响。
   * 会话边界必须清空，否则会跨会话残留。
   */
  private pendingVoiceCue: string = ''

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

  /**
   * 重排任务顺序：**未完成在上，已完成沉底**。
   *
   * 用途（用户原话「让未完成任务在上面」）：专注时勾掉一项 = 该任务完成并「降级」到列表底部，
   * 余下的未完成任务自然留在上面。`start()` / `restore()` 后也排一次，保证进入专注时
   * 跨天残留的已完成项同样沉底，与勾选降级保持同一套顺序。各组内部保持原有相对次序。
   */
  private sortTasks(): void {
    const pending: Task[] = []
    const done: Task[] = []
    for (const t of this.tasks) {
      if (t.done) {
        done.push(t)
      } else {
        pending.push(t)
      }
    }
    this.tasks = pending.concat(done)
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
        // 勾选完成 → 该任务「降级」沉底，未完成任务留在上面
        this.sortTasks()
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

  /**
   * 按任务归属曲线**分段反算**实际投入，累加写回 `Task.actualDuration`（秒）。
   *
   * 口径：**墙钟段长** —— 不细分段内的休息/暂停，代表"这段计划时间里真的投进去了多少"。
   * 它与"勾选完成"是两个口径：这个由会话计时自动产生，不需要用户打钩。
   *
   * 规则：
   *  - 每个采样点 `minuteOffset` 到下一个采样点之间算给该点的任务；末段补到 `totalSec`；
   *  - 首点之前的那一段（恢复会话时可能存在）归给首个采样点的任务；
   *  - 整条曲线为空时退化为"整段算给当前任务"（宁可粗，也不要凭空发明归属）；
   *  - 空任务 id（未分配任务）的段不计入任何任务。
   */
  private applyTaskDurations(): void {
    const totalMin = Math.floor(this.totalSec / 60)
    if (totalMin <= 0 || this.tasks.length === 0) {
      return
    }
    const pts: TaskTimelinePoint[] = this.session.taskTimeline.slice()
    pts.sort((a: TaskTimelinePoint, b: TaskTimelinePoint): number => a.minuteOffset - b.minuteOffset)
    const minutes: Map<string, number> = new Map()
    if (pts.length === 0) {
      const fallbackId = this.currentTaskId.length > 0 ? this.currentTaskId : this.firstUnfinishedTaskId()
      if (fallbackId.length > 0) {
        minutes.set(fallbackId, totalMin)
      }
    } else {
      for (let i = 0; i < pts.length; i++) {
        const startMin = i === 0 ? 0 : pts[i].minuteOffset
        const endMin = i + 1 < pts.length ? pts[i + 1].minuteOffset : totalMin
        const span = endMin - startMin
        if (pts[i].taskId.length === 0 || span <= 0) {
          continue
        }
        const prev: number | undefined = minutes.get(pts[i].taskId)
        minutes.set(pts[i].taskId, (prev !== undefined ? prev : 0) + span)
      }
    }
    for (const t of this.tasks) {
      const m: number | undefined = minutes.get(t.id)
      if (m !== undefined && m > 0) {
        t.actualDuration = t.actualDuration + m * 60
      }
    }
    hilog.info(0x0000, 'iKnow.Focus', '任务实际投入反算：按 %{public}d 个采样点、共 %{public}d 分钟',
      pts.length, totalMin)
  }

  /** 第一个未完成的任务 id（无则空串）：没有归属信息时的兜底对象 */
  private firstUnfinishedTaskId(): string {
    for (const t of this.tasks) {
      if (!t.done) {
        return t.id
      }
    }
    return ''
  }

  /** UI 注册干预回调（Phase 1 用于弹窗/横幅呈现）；传 null 取消注册 */
  setOnIntervention(cb: ((d: CompanionDecision, e: InterventionEvent) => void) | null): void {
    this.onIntervention = cb
  }

  /** 开始一个专注会话 */
  start(tasks: Task[]): void {
    this.tasks = tasks
    this.sortTasks()
    this.session = new FocusSession()
    this.session.id = IdUtils.uuid()
    this.session.title = tasks.length > 0 ? tasks[0].subject : '专注学习'
    this.session.startTime = Date.now()
    this.session.taskIds = tasks.map((t: Task): string => t.id)
    this.session.plannedDuration = tasks.reduce((sum: number, t: Task): number => sum + t.estimatedDuration, 0)
    this.session.status = SessionStatus.RUNNING
    // 感知模式按「本机是否有摄像头硬件」判定，而不是按「当前是否已授权摄像头」。
    // 授权是进入专注后才申请的（见 Focus.tryStartCamera），start() 这一刻用 snapshot().camera
    // 判定会误杀：非首页入口进入时还没要过权限 → 被判成 PERCEPTION_TIMER_ONLY → 相机预览不挂载、
    // 摄像头永远开不起来（首页预先要过权限才侥幸没暴露这个 bug）。
    const ctx0 = StorageService.getInstance().appContext()
    const hwCam = ctx0 !== null && CameraService.getInstance().probe(ctx0) > 0
    this.session.perceptionMode = hwCam ? 'PERCEPTION_FULL' : 'PERCEPTION_TIMER_ONLY'
    this.perceptionMode = this.session.perceptionMode
    // 同步写回 StorageProp：确保 Focus 页进入瞬间读到的就是本次正确模式，
    // 否则会读到上一段会话落库的旧值（有硬件却显示「未开启感知」）
    AppStorage.setOrCreate<string>(StorageKey.PERCEPTION_MODE, this.perceptionMode)
    this.currentTaskId = tasks.length > 0 ? tasks[0].id : ''
    this.resetCounters()
    this.running = true
    this.state = FocusState.FOCUSED
    this.stateEnteredAt = Date.now()
    // 任务归属曲线的初始点：没有它，第一段（0 分钟 → 首次切换任务）没有归属，
    // 分段反算时开头这一段会被整段丢掉
    this.recordTaskTimeline()
    // 状态时间轴的初始点（sec = 0）：否则第一个采样点要等到 30 秒后才落，
    // 开头这半分钟永远不会被画出来，色带总宽会短于"分心 + 专注"的实际时长
    this.sampleTimeline()
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
    // 时基取"本链开始拉起的这一刻"：引擎的样本缓冲是从此刻重新累积的，用 0（或会话的真实
    // 起始时间）都会让基线硬超时被瞬间判定为已过。会话的 startTime 是给复盘统计用的，与此无关。
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
    // 待定的语音线索必须跨会话清空，否则上一段留下的"看手机"会打到下一段
    this.pendingVoiceCue = ''
    this.clearSimTimer()
    this.resetBackgroundProbe()
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
    // 语音提醒线索同理：**只对触发它的这一次判定有效**。
    // 先取走再判断，这样"被去抖拦下 / 没真的转到分心"时线索自动作废，
    // 不会挂到很久之后的某一次状态切换上突然响一声。
    const cue = this.pendingVoiceCue
    this.pendingVoiceCue = ''
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
      // 触达（震动 / 语音）只在**真正转入「分心」**这一刻发生：
      //   · 去抖与冷却已在上面的 dwellOk / coolOk 里判过，同一段专注不会反复响；
      //   · 「趴桌」这类轻度（黄）不震不响，避免变成骚扰；
      //   · 语音还要求这次判定带着明确的场景线索（看手机 / 画面无人）。
      if (target === FocusState.DISTRACTED) {
        FeedbackService.getInstance().vibrateOnce()
        if (cue.length > 0) {
          // 提醒语由 FeedbackService 按场景 + 考伴人格生成，这里只报"哪种场景"
          FeedbackService.getInstance().speak(cue === 'PHONE' ? 'PHONE' : 'AWAY')
        }
      }
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

  /**
   * 触发一次短片段采集并交给云端（异步，不阻塞）。
   *
   * 改造（演示闭环 · B 方案）：原先这里第一行就 `if (!camera) return`，
   * 于是**没有摄像头授权 / 纯预览模拟器**里，所有触发（含模拟控制台的"目标状态""一键模拟分心"
   * 以及实时合成信号触发的事件）都被静默丢弃——控制台点了"系统根本没反应"。
   *
   * 现在：真实抓拍（照片）仍**严格需要 摄像头授权 + 真实硬件**；但若处于模拟模式（SIM_MODE）
   * 且没有可用摄像头（预览 / 模拟器 / 未授权），则**不采帧**、直接把事件送进观察队列，
   * 由 `SimulatedRecognizer` 给出与当前合成阶段一致的结论，状态机 / 干预 / 复盘照常走。
   * 这样无真机环境下，"触发 → 采集 → 识别 → 规则组合 → 干预 → 复盘"整条闭环依旧可见，
   * 只是没有真实照片、识别是模拟的（UI / 日志 / 记录 evidence 已如实标注）。
   * 非模拟模式（真机且关闭模拟）保持原语义：未授权摄像头则不抓拍、不送识别。
   */
  private triggerVisualCheck(e: WatchEvent): void {
    // 答疑 / 休息 / 暂停期间不抓拍：那段时间本就"不打扰"，也不该留下分心记录
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return
    }
    const ctx = StorageService.getInstance().appContext()
    if (ctx === null) {
      return
    }
    // 模拟模式（SIM_MODE 默认开）：允许在无摄像头时仍跑闭环；非模拟模式保持原严格语义
    const simModeRaw: number | undefined = AppStorage.get<number>(StorageKey.SIM_MODE)
    const isSim: boolean = simModeRaw === undefined ? true : simModeRaw === 1
    const permitted: boolean = PermissionService.getInstance().snapshot().camera
    const cam = CameraService.getInstance()
    const hasCam: boolean = cam.probe(ctx) > 0
    // 真实抓拍 = 模拟模式 + 授权 + 有硬件；否则（预览 / 未授权）走"无帧"演示识别
    const canCapture: boolean = isSim && permitted && hasCam
    if (!isSim && !permitted) {
      // 真机且未授权摄像头：原语义，不抓拍、不送识别
      return
    }
    const sessionId = this.session.id
    const run = async (): Promise<void> => {
      let frames: ArrayBuffer[] = []
      try {
        if (canCapture) {
          // 抓拍直接在**正在跑的预览会话**上完成（预览不中断，也不必重建会话）
          frames = await cam.captureBurst()
          if (frames.length === 0) {
            // 不再静默：区分"没触发"与"触发了但采不到"，否则复盘里只看到"没照片"
            hilog.error(0x0000, 'iKnow.Focus', '抓拍未取到帧（%{public}s），本次记录将没有照片',
              cam.getLastError())
          }
        } else {
          hilog.info(0x0000, 'iKnow.Focus',
            '无可用摄像头（模拟 / 预览），本次只记结论、不采集真实画面（演示识别）')
        }
      } catch (err) {
        hilog.error(0x0000, 'iKnow.Focus', '采集流程异常：%{public}s', err.message)
      } finally {
        // **无论采集成不成，记录都要入队落库** —— 采集失败不该让"发生过一次触发"这件事消失，
        // 否则复盘里什么都没有，比"没有照片"更难排查
        ObservationQueue.getInstance().enqueue(sessionId, e, frames)
      }
    }
    run().catch(() => {
      // 极端情况下不再向外抛，避免未捕获的 Promise
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
    // 防御性兜底：注入路径的 confidence 绝不能为 0，否则会被 CONFIDENCE_FLOOR 直接拦死，
    // 导致"点了分心但页面不变色"。若因构建缓存/默认值未生效出现 0，则强制拉回默认值。
    let oc = o.confidence
    if (this.simInjectPending && (oc === 0 || oc === undefined || oc === null)) {
      hilog.warn(0x0000, 'iKnow.Focus',
        '[onObservation] 注入记录的 confidence 为 %{public}s，强制使用默认值，避免被状态机门禁拦下',
        String(oc))
      oc = FocusTuning.SIM_INJECT_CONFIDENCE
      o.confidence = oc
    }
    const conf = Math.round(oc * 100)
    const svc = FocusDetectionService.getInstance()
    // 工作台注入：这次结论是用户显式指定的，等价于一次人工确认 → 允许跳过去抖
    const injected = this.simInjectPending
    this.simInjectPending = false
    this.manualInject = injected
    hilog.info(0x0000, 'iKnow.Focus', '[onObservation] activity=%{public}s, confidence=%{public}d, injected=%{public}s',
      o.activity, conf, String(injected))
    if (o.activity === '看手机' || o.handheld) {
      // 这里**只留线索、不直接触达**：触达交给状态机在"真正转入分心"那一刻做。
      // 原先直接在这里调 vibrateOnce / speak，绕过了去抖、置信度地板、冷却与干预预算，
      // 结果就是"低头看一眼手机"也会反复响 —— 这正是接上真实音频前必须先改掉的地方。
      this.pendingVoiceCue = 'PHONE'
      svc.submit(FocusState.DISTRACTED, `云端识别：${o.activity}`, conf, FocusSource.CAMERA)
    } else if (o.activity === '离开') {
      this.pendingVoiceCue = 'AWAY'
      svc.submit(FocusState.DISTRACTED, '云端识别：画面中没有人', conf, FocusSource.CAMERA)
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
    /**
     * 绝对时间戳（毫秒）。
     *
     * 单次复盘的图要按**真实钟点**排版（"14:05–14:12 专注"），所以每个采样点都要带上时刻；
     * `sec` 只是"已判定学习秒数"，休息 / 暂停期间不前进，用它排不出真实时间轴。
     * 旧记录没有这个字段（回填为 0），图会退回按 sec 推算并在图注里如实说明。
     */
    p.atMs = Date.now()
    p.minute = Math.floor(this.totalSec / 60)
    // 横轴按「已判定的学习秒数」走：答疑 / 休息 / 暂停这段横轴不前进，
    // 这样色带里专注与分心的宽度才能和复盘里的时长数字严格成比例
    p.sec = Math.round(this.focusSec + this.distractionSec)
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
    // 中断类状态也必须落进**状态时间线**：回复盘要按真实时间画状态段，
    // 少了这几个采样点，「休息 / 暂停 / 答疑」在图上会被画成专注（不诚实）。
    this.sampleTimeline()
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
    this.sampleTimeline()
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
    this.sampleTimeline()
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
    this.sampleTimeline()
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
    this.sampleTimeline()
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
    this.sampleTimeline()
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
   * 按 做题 → 趴桌 → 看手机 → 做题 循环（演示用）。
   * 走 `simulateFlow`：即"信号变化到达触发点 → 真实抓拍 → 云端识别 → 落库（含照片）→ 干预"。
   */
  demoCycleState(): void {
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return
    }
    if (this.state === FocusState.FOCUSED) {
      this.simulateFlow('趴桌')
    } else if (this.state === FocusState.SLIGHTLY_DISTRACTED) {
      this.simulateFlow('看手机')
    } else {
      this.simulateFlow('做题')
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
   * 模拟控制台 · **一键走完整流程**（控制台存在的意义就是它）。
   *
   * 语义：点一下 = 真机场景下"生理信号发生变化、到达拍照触发点"。
   * 之后**全部是真实链路**：抓拍 → 上传云端识别 → 落库（含照片）→ 规则组合 → 干预。
   * 唯一被模拟的是那一条"触发事件"（reason 里标明），其余没有一处是假的。
   *
   * 结论由识别器给出：没配网关时按当前阶段给（与所选状态一致），
   * 配了网关则由大模型**看照片**判断"在做什么"。
   *
   * @returns false = 没在专注（答疑/休息/暂停同理），或本次会话触发配额已用完
   */
  /** 本会话已用掉的演示配额（控制台显示用）：一个来自事件引擎的触发次数，一个来自观察队列的入队次数 */
  getTriggerQuotaUsed(): number {
    return WatchEventEngine.getInstance().getTriggerCount()
  }

  getQueueQuotaUsed(): number {
    return ObservationQueue.getInstance().getQuotaUsed(this.session.id)
  }

  /** 最近一次模拟注入抓拍的诊断结论（工作台上直接显示，便于定位"为什么没有真实画面"） */
  getLastCaptureDiag(): string {
    return this.lastCaptureDiag
  }

  /**
   * 重置本会话的演示配额（控制台的显式操作）。
   * 两个配额都是**累计**的、只在会话结束时复位；被用完之后再点就是静默丢弃
   * （没有记录、没有结论、状态也不变），看起来完全像"点了没反应" —— 所以必须给出口。
   */
  resetDemoQuota(): void {
    WatchEventEngine.getInstance().resetSessionQuota()
    ObservationQueue.getInstance().resetQuota(this.session.id)
    hilog.info(0x0000, 'iKnow.Focus', '[模拟控制台] 本会话演示配额已重置')
  }

  simulateFlow(activity: string): boolean {
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return false
    }
    // ① 信号侧对齐：等价于"信号变化到该状态对应的阶段"
    WatchSignalSource.getInstance().setPhase(SimActivity.phaseOf(activity))
    // ② 等价于"到达拍照触发点" —— 之后走真实抓拍与云端识别
    const ok = WatchEventEngine.getInstance().injectTrigger(`模拟：信号变化到「${activity}」对应的阶段`)
    hilog.info(0x0000, 'iKnow.Focus', '[模拟流程] 目标状态=%{public}s 触发=%{public}s',
      activity, ok ? '已发出' : '被配额拦下')
    return ok
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
    // 画面从哪来：**先探测硬件，有就真抓拍**；抓拍失败 / 无硬件 / 无权限时 fallback 到
    // **明确标注的占位画面**（rawfile 自带，图片与证据文字都写明"演示占位"），绝不伪造真实照片。
    // 注意：不依赖 PermissionService 的本地授权标记——它可能和系统实际授权状态不同步；
    // 只要硬件存在就尝试抓拍，catch 所有异常再降级，这样有摄像头却总显示占位图的问题才能定位。
    const ctx = StorageService.getInstance().appContext()
    const cam = CameraService.getInstance()
    const camCount: number = ctx !== null ? cam.probe(ctx) : -1
    hilog.info(0x0000, 'iKnow.Focus',
      '[模拟注入] 摄像头探测：ctx=%{public}s，cameras=%{public}d，previewRunning=%{public}s，permCamera=%{public}s',
      ctx !== null ? 'ok' : 'null', camCount, cam.isRunning() ? 'Y' : 'N',
      PermissionService.getInstance().snapshot().camera ? 'Y' : 'N')
    if (ctx !== null && camCount > 0) {
      hilog.info(0x0000, 'iKnow.Focus',
        '[模拟注入] 探测到摄像头，尝试真实抓拍：activity=%{public}s', activity)
      this.captureThenDeliver(activity, confidence, ctx).catch((err: Error) => {
        hilog.error(0x0000, 'iKnow.Focus',
          '[模拟注入] 抓拍异常，改用占位画面交付：%{public}s', err.message)
        this.deliverInjected(activity, confidence, this.placeholderFrames(ctx),
          `抓拍流程异常（${err.message}），已降级为演示占位图（非真实照片）。`)
      })
    } else {
      const why = ctx === null
        ? '拿不到应用上下文，无法访问摄像头，使用演示占位图（非真实照片）。'
        : `未探测到可用摄像头（getSupportedCameras 返回 ${camCount}）${cam.getLastError().length > 0 ? '：' + cam.getLastError() : ''}，使用演示占位图（非真实照片）。`
      this.lastCaptureDiag = `未进入真实抓拍：${why}`
      hilog.info(0x0000, 'iKnow.Focus',
        '[模拟注入] 未进入真实抓拍，使用占位画面：activity=%{public}s reason=%{public}s', activity, why)
      this.deliverInjected(activity, confidence, this.placeholderFrames(ctx), why)
    }
    return true
  }

  /** 有摄像头且已授权：在预览会话上真实抓拍一束片段，再连同画面一起交付（页面 / 复盘都稳定可见） */
  private async captureThenDeliver(activity: string, confidence: number, ctx: common.Context): Promise<void> {
    const cam = CameraService.getInstance()
    let frames: ArrayBuffer[] = []
    let why = ''
    try {
      // 抓拍就在**正在跑的预览会话**上完成（预览不中断、不需重建会话）
      frames = await cam.captureBurst()
      if (frames.length === 0) {
        const err0 = cam.getLastError()
        why = `真实抓拍未取到帧（${err0.length > 0 ? err0 : '未知原因'}），已降级为演示占位图（非真实照片）。`
        hilog.error(0x0000, 'iKnow.Focus', '[模拟注入] %{public}s', why)
      }
    } catch (err) {
      why = `真实抓拍失败（${err.message}），已降级为演示占位图（非真实照片）。`
      hilog.error(0x0000, 'iKnow.Focus', '[模拟注入] %{public}s', why)
    }
    if (frames.length > 0) {
      hilog.info(0x0000, 'iKnow.Focus', '[模拟注入] 真实抓拍成功，%{public}d 张', frames.length)
      this.lastCaptureDiag = `真实抓拍成功：${frames.length} 张`
      this.deliverInjected(activity, confidence, frames, `真实抓拍 ${frames.length} 张。`)
    } else {
      this.lastCaptureDiag = `真实抓拍失败：${why}`
      this.deliverInjected(activity, confidence, this.placeholderFrames(ctx), why)
    }
  }

  /**
   * 无摄像头时的"占位画面"（rawfile/sim_placeholder.png）。
   * 它**不是**真实抓拍：图片本身就写着"演示占位图 · 未接摄像头"，证据文字同样注明，避免误导。
   */
  private placeholderFrames(ctx: common.Context | null): ArrayBuffer[] {
    if (ctx === null) {
      hilog.warn(0x0000, 'iKnow.Focus', '[placeholder] appContext 为空，无法读取 rawfile 占位图')
      return []
    }
    try {
      const bytes: Uint8Array = ctx.resourceManager.getRawFileContentSync('sim_placeholder.png')
      if (!bytes || bytes.length === 0) {
        hilog.warn(0x0000, 'iKnow.Focus', '[placeholder] rawfile/sim_placeholder.png 读取为空，' +
          '通常是 DevEco 增量构建未打包新增 rawfile，请 Build > Clean Project 后重试')
        return []
      }
      const buf: ArrayBuffer = new ArrayBuffer(bytes.length)
      new Uint8Array(buf).set(bytes)
      hilog.info(0x0000, 'iKnow.Focus', '[placeholder] 已读取 rawfile 占位图，%{public}d 字节', bytes.length)
      return [buf]
    } catch (err) {
      hilog.error(0x0000, 'iKnow.Focus', '[placeholder] rawfile 占位图读取失败：%{public}s，' +
        '请在 DevEco 中 Build > Clean Project 后重试', err.message)
      return []
    }
  }

  /**
   * 交付一次"注入识别结果"：建记录 → 附画面 → 落库 → 走规则组合 / 状态机 / 干预。
   * 与真实链路（`ObservationQueue`）共用 `saveFrames` 落盘口径。
   */
  private deliverInjected(activity: string, confidence: number, frames: ArrayBuffer[], note?: string): void {
    // 抓拍是异步的：会话可能已结束，这时不该再产生结论
    if (!this.running || this.qaMode || this.resting || this.paused) {
      hilog.info(0x0000, 'iKnow.Focus', '[模拟注入] 会话已结束，丢弃这次注入结果')
      return
    }
    const o = new ObservationRecord()
    o.id = IdUtils.uuid()
    o.sessionId = this.session.id
    o.tMs = Date.now()
    o.activity = activity
    o.handheld = activity === '看手机'
    o.facingDesk = activity === '做题' || activity === '看书'
    // 兜底：confidence 为 0/undefined/null 时强制回到默认注入置信度，否则会被状态机置信度门禁拦死
    o.confidence = (confidence === undefined || confidence === null || confidence === 0)
      ? FocusTuning.SIM_INJECT_CONFIDENCE
      : confidence
    o.imagePaths = ObservationQueue.getInstance().saveFrames(this.session.id, frames)
    o.evidence = this.injectedEvidence(o.imagePaths.length > 0, note)
    // 一次性"人工确认"标记：让规则组合跳过去抖 / 冷却，页面即刻变色
    this.simInjectPending = true
    hilog.info(0x0000, 'iKnow.Focus', '[模拟注入] activity=%{public}s，画面 %{public}d 张，note=%{public}s',
      activity, o.imagePaths.length, note ?? '')
    this.onObservation(o)
    // **必须落库**：学习记录（复盘）是按 sessionId 从库里读的
    StorageService.getInstance().saveObservation(o).catch(() => {
      hilog.error(0x0000, 'iKnow.Focus', '模拟注入的观察记录落库失败，复盘里将看不到这一次')
    })
  }

  /**
   * 注入记录的证据文案。
   * @param hasImage 是否真的落盘了画面（真实抓拍 或 占位图字节都算"有图"）
   * @param note     为什么是占位图 / 为什么没图（由调用方如实填入，复盘里直接可见，便于定位）
   */
  private injectedEvidence(hasImage: boolean, note?: string): string {
    // 版本标记：复盘里能看到，用于确认"设备上跑的是不是最新代码"。
    // 之前几轮反复分不清"代码没重新构建"与"构建了但仍失败"，这里让它可自证。
    const base = '[v9] 模拟注入：可观察状态由「模拟状态」面板指定；结论为演示值，非真实识别。'
    const why = note !== undefined && note.length > 0 ? note : ''
    if (hasImage) {
      if (why.length > 0) {
        return base + ' 画面说明：' + why
      }
      return base + ' 画面为触发时刻的真实抓拍（演示注入路径）。'
    }
    return base + ' 未生成任何画面：' + (why.length > 0 ? why : '原因未知')
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
      this.sortTasks()
    }
    this.session = new FocusSession()
    this.session.id = snap.sessionId
    this.session.status = SessionStatus.RUNNING
    this.session.perceptionMode = snap.perceptionMode
    // 恢复起始时间：快照里带上就还原它；旧快照没有这个字段（= 0）时按「现在 − 已计时长」反推，
    // 绝不能留 0 —— 那会让这次会话永远不计入"今天"
    this.session.startTime = snap.startTime > 0
      ? snap.startTime
      : Date.now() - Math.floor(snap.totalSec) * 1000
    // 感知模式以快照里保存的为准（它本就是按「是否有摄像头硬件」判定的，不是按授权）。
    // 不再用 snapshot().camera 降级：授权是进入后才申请的，恢复瞬间它多半还是 false，
    // 据此判成 PERCEPTION_TIMER_ONLY 会把相机预览关掉；权限变化由 subscribePermission 实时处理。
    this.perceptionMode = snap.perceptionMode
    AppStorage.setOrCreate<string>(StorageKey.PERCEPTION_MODE, this.perceptionMode)
    this.totalSec = snap.totalSec
    this.focusSec = snap.focusSec
    this.distractionSec = snap.distractionSec
    this.qaSec = snap.qaSec
    this.breakSec = snap.breakSec
    this.state = (snap.state as FocusState)
    this.resting = (this.state === FocusState.RESTING)
    this.breakStartedAt = this.resting ? Date.now() : 0
    this.stateEnteredAt = Date.now()
    // 快照里带了"当时在哪个任务上"，必须还原 —— 否则恢复后当前任务变成空，
    // 之后的任务归属曲线全都没有归属，界面也显示成没在任务上
    this.currentTaskId = snap.currentTaskId
    // 任务归属曲线补一个初始点（偏移 = 已计时长），让恢复后的这一段也有归属
    this.recordTaskTimeline()
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
    this.resetBackgroundProbe()
    this.running = false
    this.qaMode = false
    this.resting = false
    this.paused = false
    this.breakStartedAt = 0
    this.session.endTime = Date.now()
    // 兜底：起始时间缺失（旧快照恢复、异常路径）时按「结束时间 − 总学习时长」反推。
    // 留 0 会让这次会话在按日聚合里静默消失（今日/本周/近 30 天/时段归属全都漏），
    // 相比"起始时间差几十秒"，这是更严重的问题。
    if (this.session.startTime <= 0) {
      this.session.startTime = Math.max(0, this.session.endTime - Math.floor(this.totalSec) * 1000)
    }
    this.session.totalDuration = Math.floor(this.totalSec)
    this.session.focusDuration = Math.floor(this.focusSec)
    this.session.distractionDuration = Math.floor(this.distractionSec)
    this.session.qaDuration = Math.floor(this.qaSec)
    this.session.breakDuration = Math.floor(this.breakSec)
    this.session.pausedDuration = Math.floor(this.pausedAccum)
    this.session.timeline = this.timeline
    this.session.events = this.events
    this.session.completedTaskIds = this.tasks.filter((t: Task): boolean => t.done).map((t: Task): string => t.id)
    // 按任务归属曲线分段反算"实际投入"，写回 Task.actualDuration。
    // 必须在这里（而不是 AppStore 里）：endSession() 紧接着会 getTasks() 并逐个 saveTask()
    this.applyTaskDurations()
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
   * 「直接结束」——丢弃本次专注：**一条记录都不留**。
   *
   * 与 finalize() / endSession() 的区别：
   *  - 不落库会话、不生成复盘、不计入任何统计（走 `abort()` 复位运行时）；
   *  - 额外清掉会话过程中**已经实时写进去**的两样东西：快照与答疑记录。
   *
   * 为什么必须清这两样：快照每 10s 落一条、答疑是产生时立即落库，
   * 它们都不是"结束那一刻"才写的。不清掉的话，虽然本次专注不计入统计，
   * 但库里仍留着它的痕迹（快照还可能在 30 分钟恢复窗口内被根页判定为"被中断的会话"）。
   */
  async discard(): Promise<void> {
    const id = this.session.id
    try {
      if (id.length > 0) {
        await StorageService.getInstance().deleteSnapshots(id)
        await StorageService.getInstance().deleteQuestions(id)
      }
    } catch (e) {
      // 清理失败也必须继续复位：宁可留一点残迹，也不能让会话"卡在半死状态"
      hilog.error(0x0000, 'iKnow.Focus', '清理本次专注残迹失败：%{public}s', e.message)
    }
    this.abort()
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
    this.resetBackgroundProbe()
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
    // 首页会读它算「专注占比」（虽然前提是 FOCUS_RUNNING=1，这里也一并归零，
    // 否则下一次专注刚开始的瞬间会拿上一次的旧值算比例）
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_STUDY, 0)
  }

  // ===================== 手机侧信号：专注中切后台 =====================
  //
  // 为什么需要：专注中切到别的应用，计时仍在继续，而没有任何地方记下"用户在用手机"。
  // 这两个方法由 EntryAbility 的生命周期回调驱动 —— 零外设、零权限。
  //
  // 判据的关键：**进后台 ≠ 分心**。"手机扣在桌上、锁屏后专心写题"正是本产品的核心场景，
  // 那时 App 也在后台。所以只有当"后台 + 屏幕亮着"（= 人在别的应用上）才算手机使用。
  //
  // 归属时间在**回到前台时**用真实时钟一次性结算：后台定时器会被系统冻结，
  // 用 tick 累加会严重少算；而且熄屏与亮屏要分别归属到不同的累计值。

  /** App 进入后台（EntryAbility.onBackground 调用）：只记录与结清，不在这里下结论 */
  onAppBackground(): void {
    if (!this.running || this.bgStartedAt > 0) {
      return
    }
    const now = Date.now()
    // 先把"一直到切走前"的这一段按当前状态结清，段的边界落在真实切换时刻
    this.settleSegment(now)
    this.bgStartedAt = now
    this.bgScreenOn = FocusController.isScreenOn()
    this.bgEligible = !this.paused && !this.resting && !this.qaMode
    hilog.info(0x0000, 'iKnow.Focus', '进入后台：屏幕=%{public}s 可判定=%{public}s',
      this.bgScreenOn ? '亮' : '灭', this.bgEligible ? '是' : '否')
  }

  /**
   * App 回到前台（EntryAbility.onForeground 调用）：结算后台这段时间的归属。
   *  - 亮屏 + 离开 ≥ BG_PHONE_MIN_SEC + 可判定 → 记为「手机使用」分心，并走一次干预阶梯；
   *  - 熄屏 / 离开过短 → 不算分心，按当时模式归入净专注；
   *  - 休息 / 暂停 / 答疑途中 → 归入对应累计值（后台不影响这些模式的计时）。
   */
  onAppForeground(): void {
    if (!this.running || this.bgStartedAt <= 0) {
      return
    }
    const now = Date.now()
    const away = Math.max(0, (now - this.bgStartedAt) / 1000)
    const screenOn = this.bgScreenOn
    const eligible = this.bgEligible
    this.resetBackgroundProbe()
    // 这段时间由下面手工归属，把段起点挪到"现在"，避免 settleSegment 再算一遍
    this.segStartAt = now
    if (away <= 0) {
      return
    }
    this.totalSec += away

    if (eligible && screenOn && away >= FocusTuning.BG_PHONE_MIN_SEC) {
      this.distractionSec += away
      this.lastDetail = `切到其他应用 ${Math.round(away)} 秒（手机使用）`
      this.lastConfidence = Math.round(FocusTuning.BG_PHONE_CONFIDENCE * 100)
      this.recordEvent(FocusState.DISTRACTED, FocusSource.PHONE,
        FocusTuning.BG_PHONE_CONFIDENCE, `亮屏离开本应用 ${Math.round(away)} 秒`)
      this.sampleTimeline()
      this.pushLive()
      hilog.info(0x0000, 'iKnow.Focus', '记为手机使用分心：%{public}d 秒', Math.round(away))
      // 干预阶梯照常走（冷却与预算由 InterventionEngine 管）。
      // 评估时把状态临时置为"分心"，让引擎按一次真实分心来决定是否提醒；评估完立刻还原。
      const prevState = this.state
      const prevEntered = this.stateEnteredAt
      this.state = FocusState.DISTRACTED
      this.stateEnteredAt = now - Math.round(away * 1000)
      this.evaluateIntervention()
      this.state = prevState
      this.stateEnteredAt = prevEntered
      return
    }

    if (this.paused) {
      this.pausedAccum += away
    } else if (this.resting) {
      this.breakSec += away
    } else if (this.qaMode) {
      this.qaSec += away
    } else {
      // 熄屏（手机扣桌 / 放兜里）或极短离开：这仍然是专注
      this.focusSec += away
    }
    this.pushLive()
  }

  /** 屏幕是否亮着（power.isActive()，免权限，since 9）。取不到时按"亮"处理：宁可多记一次也不漏判 */
  private static isScreenOn(): boolean {
    try {
      return power.isActive()
    } catch (e) {
      return true
    }
  }

  /** 复位切后台探测状态（结束 / 中止 / 新会话开始都要做，避免脏时间戳打到下一段会话） */
  private resetBackgroundProbe(): void {
    this.bgStartedAt = 0
    this.bgScreenOn = false
    this.bgEligible = false
  }

  private async writeSnapshot(): Promise<void> {
    if (!this.running) {
      return
    }
    const snap = new SessionSnapshot()
    snap.sessionId = this.session.id
    snap.ts = Date.now()
    // 起始时间必须随快照走，否则恢复后落库 start_time = 0 → 今日/本周/30 天全都漏记这一次
    snap.startTime = this.session.startTime
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
