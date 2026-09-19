import { FocusState, FocusSource } from '../models/Enums'
import { FocusDetectionResult, MotionData, FocusSensor } from './ServiceTypes'
import { DemoFlag } from '../common/Constants'
import { PermissionService } from './PermissionService'

/**
 * 专注检测服务 —— Mock 摄像头视觉
 * 未来替换为真实摄像头视觉检测时，仅需替换本类实现。
 */
export class FocusDetectionService implements FocusSensor {
  private static inst: FocusDetectionService | null = null
  private timerId: number = -1
  private callback: ((r: FocusDetectionResult) => void) | null = null
  private startTs: number = 0
  /** 最近一次判定（由云端识别结果经规则组合后 submit；初始无结论，置信度 0 → 被门禁忽略） */
  private lastState: FocusState = FocusState.FOCUSED
  private lastDetail: string = ''
  private lastConfidence: number = 0

  static getInstance(): FocusDetectionService {
    if (FocusDetectionService.inst === null) {
      FocusDetectionService.inst = new FocusDetectionService()
    }
    return FocusDetectionService.inst
  }

  getVisualState(): FocusDetectionResult {
    return this.current()
  }

  getHeartRate(): number {
    return 68 + Math.round(Math.random() * 6)
  }

  getHRV(): number {
    return 44 + Math.round(Math.random() * 14)
  }

  getMotionData(): MotionData {
    const m = new MotionData()
    m.motionLevel = Math.round(Math.random() * 20)
    m.wristMotion = Math.round(Math.random() * 6)
    return m
  }

  /** 启动自动检测：每 DETECT_INTERVAL 回调一次 */
  start(cb: (r: FocusDetectionResult) => void): void {
    this.callback = cb
    // 硬规则 §4：未授权摄像头则不启动视觉检测，由调用方降级为"仅计时模式"
    if (!PermissionService.getInstance().snapshot().camera) {
      return
    }
    this.startTs = Date.now()
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
    }
    this.timerId = setInterval(() => {
      if (this.callback !== null) {
        this.callback(this.current())
      }
    }, DemoFlag.DETECT_INTERVAL)
    if (this.callback !== null) {
      this.callback(this.current())
    }
  }

  /** 由 PermissionService 在授权变化时调用：关闭则立即停止检测 */
  setEnabled(enabled: boolean): void {
    if (!enabled) {
      this.stop()
    }
  }

  /**
   * 会话边界复位：**新会话开始时必须清掉上一段留下的结论**。
   * 否则上一段以"看手机"（红）结束时，下一段一开始就会回放这条红色结论，
   * 表现为"刚坐下就被提示分心"。
   */
  beginSession(): void {
    this.lastState = FocusState.FOCUSED
    this.lastDetail = ''
    this.lastConfidence = 0
    this.startTs = Date.now()
  }

  /**
   * 停止检测（只停轮询，不断开结论回调 —— 回调是手表事件/模拟工作台的唯一出口）。
   */
  stop(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /**
   * 显式注入一次判定结论（演示用）。
   *
   * ⚠️ 历史 bug：这里原先把状态写进 `manualOverride` 字段，而 `current()` 从不读它，
   * 于是「模拟轻度分心 / 重度走神」按钮弹了成功提示却毫无效果。
   * 现在改为直接 `submit()`，与真实判定共用同一个出口。
   */
  simulate(state: FocusState): void {
    const detail = state === FocusState.DISTRACTED
      ? '模拟注入：长时间离开屏幕'
      : state === FocusState.SLIGHTLY_DISTRACTED
        ? '模拟注入：频繁低头'
        : '模拟注入：状态正常'
    this.submit(state, detail, 85, FocusSource.CAMERA)
  }

  /**
   * 恢复专注。**必须同时把最近判定改回"专注"** ——
   * 否则重新提交的还是上一条"分心"结论，用户点了「继续专注」界面看起来毫无反应。
   */
  resume(): void {
    this.startTs = Date.now()
    this.lastState = FocusState.FOCUSED
    this.lastDetail = '已确认继续专注'
    this.lastConfidence = 90
    if (this.callback !== null) {
      this.callback(this.current())
    }
  }

  /**
   * 产出一次检测结果。
   *
   * 判定不在本类里"编造"：结论来自"手表事件 → 摄像头短片段 → 云端可观察状态"
   * 这条链，经规则组合后通过 `submit()` 注入；本方法只负责取最近一次结论。
   * 没有输入时状态不变（不产出新结论）。
   */
  private current(): FocusDetectionResult {
    const r = new FocusDetectionResult()
    r.timestamp = Date.now()
    r.source = FocusSource.CAMERA
    r.state = this.lastState
    r.detail = this.lastDetail
    r.confidence = this.lastConfidence
    return r
  }

  /**
   * 由分析器提交一次真实判定结果（视觉/生理融合后的结论）。
   * 这是**唯一**能改变专注状态的入口。
   */
  submit(state: FocusState, detail: string, confidence: number, source: FocusSource): void {
    this.lastState = state
    this.lastDetail = detail
    this.lastConfidence = confidence
    if (this.callback !== null) {
      const r = new FocusDetectionResult()
      r.timestamp = Date.now()
      r.state = state
      r.detail = detail
      r.confidence = confidence
      r.source = source
      this.callback(r)
    }
  }
}
