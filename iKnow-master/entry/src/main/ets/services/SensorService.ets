import { FocusState, FocusSource } from '../models/Enums'
import { FocusDetectionResult, MotionData, FocusSensor } from './ServiceTypes'

/**
 * 传感器服务 —— Mock 智能手表数据（心率 / HRV / 手腕动作）
 * 未来替换真实 HarmonyOS / BLE 手表实现时，仅需替换本类。
 */
export class SensorService implements FocusSensor {
  private static inst: SensorService | null = null
  private connected: boolean = true

  static getInstance(): SensorService {
    if (SensorService.inst === null) {
      SensorService.inst = new SensorService()
    }
    return SensorService.inst
  }

  getVisualState(): FocusDetectionResult {
    const r = new FocusDetectionResult()
    r.state = FocusState.FOCUSED
    r.source = FocusSource.WATCH
    r.confidence = 60
    r.detail = '生理信号平稳'
    return r
  }

  getHeartRate(): number {
    return 68 + Math.round(Math.random() * 8)
  }

  getHRV(): number {
    return 44 + Math.round(Math.random() * 16)
  }

  getMotionData(): MotionData {
    const m = new MotionData()
    m.motionLevel = Math.round(Math.random() * 25)
    m.wristMotion = Math.round(Math.random() * 8)
    return m
  }

  isConnected(): boolean {
    return this.connected
  }

  /** 当前是否佩戴手表（PRD §12：无手表时 RED 干预走手机声音+屏幕，不假装震动） */
  isWristPresent(): boolean {
    return this.connected
  }

  connect(): void {
    this.connected = true
  }

  disconnect(): void {
    this.connected = false
  }

  getStatusText(): string {
    if (!this.connected) {
      return '未连接'
    }
    return `心率 ${this.getHeartRate()} bpm · HRV ${this.getHRV()} ms · 动作正常`
  }
}
