import { FocusState, FocusSource, SessionStatus } from '../models/Enums'
import { FocusSession, FocusEvent, FocusTimelinePoint } from '../models/FocusSession'
import { Task } from '../models/Task'
import { QuestionRecord } from '../models/QuestionRecord'
import { FocusDetectionService } from './FocusDetectionService'
import { FocusDetectionResult } from './ServiceTypes'
import { StorageKey, DemoFlag } from '../common/Constants'
import { IdUtils } from '../utils/IdUtils'

/**
 * 专注控制器 —— 统一驱动：
 *   计时（总/净/分心/答疑/休息） + 状态机（绿/黄/红） + 检测订阅 + 曲线采样
 * 是「规划 → 专注 → 状态机 → 答疑(计时不中断) → 复盘」闭环的运行时引擎。
 */
export class FocusController {
  private static inst: FocusController | null = null
  private tickId: number = -1
  private session: FocusSession = new FocusSession()
  private tasks: Task[] = []
  private questions: QuestionRecord[] = []
  private running: boolean = false
  private qaMode: boolean = false
  private resting: boolean = false
  private paused: boolean = false

  private totalSec: number = 0
  private focusSec: number = 0
  private distractionSec: number = 0
  private qaSec: number = 0
  private breakSec: number = 0

  private state: FocusState = FocusState.FOCUSED
  private stateSinceSec: number = 0
  private sampleCounter: number = 0
  private timeline: FocusTimelinePoint[] = []
  private events: FocusEvent[] = []

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
    return this.totalSec
  }

  getFocusSec(): number {
    return this.focusSec
  }

  getQaSec(): number {
    return this.qaSec
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

    this.resetCounters()
    this.running = true
    this.state = FocusState.FOCUSED
    this.questions = []

    FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
      this.onDetection(r)
    })
    this.tickId = setInterval(() => {
      this.tick()
    }, DemoFlag.TICK)
    this.pushLive()
  }

  private resetCounters(): void {
    this.totalSec = 0
    this.focusSec = 0
    this.distractionSec = 0
    this.qaSec = 0
    this.breakSec = 0
    this.stateSinceSec = 0
    this.sampleCounter = 0
    this.timeline = []
    this.events = []
    this.qaMode = false
    this.resting = false
    this.paused = false
  }

  private tick(): void {
    if (!this.running) {
      return
    }
    if (this.paused) {
      return
    }
    if (this.resting) {
      this.breakSec++
      this.pushLive()
      return
    }
    this.totalSec++
    if (this.qaMode) {
      this.qaSec++
    } else if (this.state === FocusState.FOCUSED) {
      this.focusSec++
    } else {
      this.distractionSec++
    }
    this.stateSinceSec++
    this.sampleCounter++
    if (this.sampleCounter >= 30) {
      this.sampleCounter = 0
      this.sampleTimeline()
    }
    this.pushLive()
  }

  /** 摄像头检测回调 → 状态机 */
  private onDetection(r: FocusDetectionResult): void {
    if (!this.running || this.qaMode || this.resting || this.paused) {
      return
    }
    const target = this.mapState(r.state)
    if (target !== this.state) {
      this.state = target
      this.stateSinceSec = 0
      this.recordEvent(target, r.source, r.confidence, r.detail)
      this.sampleTimeline()
      this.pushLive()
    }
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

  private levelForState(s: FocusState): number {
    if (s === FocusState.FOCUSED) {
      return 90 + Math.round(Math.random() * 8)
    }
    if (s === FocusState.SLIGHTLY_DISTRACTED) {
      return 55 + Math.round(Math.random() * 15)
    }
    return 25 + Math.round(Math.random() * 15)
  }

  /** 进入 AI 答疑：停止摄像头监测，计时不中断（计入总时长，不计净专注） */
  startQA(): void {
    if (!this.running) {
      return
    }
    this.qaMode = true
    this.state = FocusState.QA_MODE
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  endQA(): void {
    this.qaMode = false
    this.state = FocusState.FOCUSED
    FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
      this.onDetection(r)
    })
    this.pushLive()
  }

  addQuestion(q: QuestionRecord): void {
    this.questions.push(q)
  }

  /** 暂停 */
  pause(): void {
    this.paused = true
    this.state = FocusState.PAUSED
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  resume(): void {
    this.paused = false
    this.state = FocusState.FOCUSED
    FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
      this.onDetection(r)
    })
    this.pushLive()
  }

  /** 休息：停止检测，暂停专注统计 */
  startBreak(): void {
    this.resting = true
    this.state = FocusState.RESTING
    FocusDetectionService.getInstance().stop()
    this.pushLive()
  }

  endBreak(): void {
    this.resting = false
    this.state = FocusState.FOCUSED
    FocusDetectionService.getInstance().start((r: FocusDetectionResult) => {
      this.onDetection(r)
    })
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

  /** 结束会话：落盘前的收尾 */
  finalize(): FocusSession {
    if (this.tickId >= 0) {
      clearInterval(this.tickId)
      this.tickId = -1
    }
    FocusDetectionService.getInstance().stop()
    this.running = false
    this.session.endTime = Date.now()
    this.session.totalDuration = this.totalSec
    this.session.focusDuration = this.focusSec
    this.session.distractionDuration = this.distractionSec
    this.session.qaDuration = this.qaSec
    this.session.breakDuration = this.breakSec
    this.session.timeline = this.timeline
    this.session.events = this.events
    this.session.completedTaskIds = this.tasks.filter((t: Task): boolean => t.done).map((t: Task): string => t.id)
    this.session.status = SessionStatus.FINISHED
    this.pushLive()
    return this.session
  }

  private pushLive(): void {
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_ELAPSED, this.totalSec)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_NET, this.focusSec)
    AppStorage.setOrCreate<string>(StorageKey.FOCUS_STATE, this.state)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_QA_ELAPSED, this.qaSec)
  }
}
