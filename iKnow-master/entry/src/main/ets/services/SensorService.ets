import { FocusState, FocusSource } from '../models/Enums'
import { FocusDetectionResult, MotionData, FocusSensor } from './ServiceTypes'

/**
 * 传感器服务 —— 模拟智能手表（心率 / HRV / 手腕动作）
 * 未来替换真实 HarmonyOS / BLE 手表实现时，仅需替换本类。
 *
 * 诚实性约定（PRD §12）：**默认未佩戴**。未佩戴时 RED 干预走手机声音 + 屏幕，
 * 绝不允许"假装震动"；UI 必须如实显示未连接。
 */
export class SensorService implements FocusSensor {
  private static inst: SensorService | null = null
  private connected: boolean = false
  /** 稳定的生理基线：仅在"佩戴"时生成一次，避免每次刷新数字乱跳 */
  private baseHeartRate: number = 0
  private baseHrv: number = 0

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
    r.confidence = this.connected ? 60 : 0
    r.detail = this.connected ? '生理信号平稳' : '未佩戴手表'
    return r
  }

  getHeartRate(): number {
    return this.connected ? this.baseHeartRate : 0
  }

  getHRV(): number {
    return this.connected ? this.baseHrv : 0
  }

  getMotionData(): MotionData {
    const m = new MotionData()
    m.motionLevel = this.connected ? Math.round(Math.random() * 25) : 0
    m.wristMotion = this.connected ? Math.round(Math.random() * 8) : 0
    return m
  }

  isConnected(): boolean {
    return this.connected
  }

  /** 当前是否佩戴手表（PRD §12：无手表时 RED 干预走手机声音+屏幕，不假装震动） */
  isWristPresent(): boolean {
    return this.connected
  }

  /** 模拟佩戴 / 断开（演示用；真实实现应由 BLE 连接状态驱动） */
  setPresent(present: boolean): void {
    if (present && !this.connected) {
      this.baseHeartRate = 68 + Math.round(Math.random() * 8)
      this.baseHrv = 44 + Math.round(Math.random() * 16)
    }
    if (!present) {
      this.baseHeartRate = 0
      this.baseHrv = 0
    }
    this.connected = present
  }

  connect(): void {
    this.setPresent(true)
  }

  disconnect(): void {
    this.setPresent(false)
  }

  getStatusText(): string {
    if (!this.connected) {
      return '未佩戴（模拟设备未连接）'
    }
    return `心率 ${this.baseHeartRate} bpm · HRV ${this.baseHrv} ms · 动作正常`
  }
}
