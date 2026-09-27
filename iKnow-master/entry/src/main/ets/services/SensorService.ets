import { FocusState, FocusSource } from '../models/Enums'
import { FocusDetectionResult, MotionData, FocusSensor } from './ServiceTypes'
import { StorageService } from './StorageService'
import { BleWatchService } from './BleWatchService'
import { WatchSignalSource } from './WatchSignalSource'

/**
 * 传感器服务 —— 模拟智能手表（心率 / HRV / 手腕动作）
 * 未来替换真实 HarmonyOS / BLE 手表实现时，仅需替换本类。
 *
 * 诚实性约定（PRD §12）：**默认未佩戴**。未佩戴时 RED 干预走手机声音 + 屏幕，
 * 绝不允许"假装震动"；UI 必须如实显示未连接。
 */
export class SensorService implements FocusSensor {
  private static inst: SensorService | null = null
  private static readonly KV_PRESENT = 'ik_watch_present'
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

  /**
   * 启动初始化。
   *
   * 「模拟佩戴手表」开关已从设备页下架（2026-09-27）：模拟设备**恒为未佩戴**，
   * 因此这里不再回读历史 KV_PRESENT，而是把它清成 0 —— 否则老用户上次开的"模拟佩戴"
   * 会在重启后幽灵般保留，导致界面上"未佩戴"的文案与 `isWristPresent()` 的判定互相打架。
   * 真实佩戴以 BLE 连接为准（见 `isWristPresent()` / `BleWatchService`）。
   */
  async init(): Promise<void> {
    this.connected = false
    this.baseHeartRate = 0
    this.baseHrv = 0
    try {
      await StorageService.getInstance().saveKv(SensorService.KV_PRESENT, '0')
    } catch (e) {
      // 清残留失败无碍：内存里已经是不佩戴
    }
  }

  getVisualState(): FocusDetectionResult {
    const r = new FocusDetectionResult()
    r.state = FocusState.FOCUSED
    r.source = FocusSource.WATCH
    r.confidence = this.connected ? 60 : 0
    r.detail = this.connected ? '生理信号平稳' : '未佩戴手表'
    return r
  }

  /**
   * 真实 BLE 心率优先；没有真实设备时取**合成信号源的当前心率**（未佩戴则为 0）。
   *
   * 原来这里返回的是"佩戴那一刻随机生成的固定基线"，与驱动算法的合成信号是两个数：
   * 同屏会出现一个整段会话纹丝不动的"实时心率"和一个在 62/74/92 之间跳的心率，一眼假。
   */
  getHeartRate(): number {
    const realBle = BleWatchService.getInstance()
    if (realBle.isConnected() && realBle.getHeartRate() > 0) {
      return realBle.getHeartRate()
    }
    if (!this.connected) {
      return 0
    }
    return WatchSignalSource.getInstance().currentBpm()
  }

  /** 心率是否来自模拟设备（真实 BLE 未连接）—— UI 据此如实标注，不把模拟值当真实测量 */
  isSimulatedWrist(): boolean {
    return !BleWatchService.getInstance().isConnected()
  }

  getHRV(): number {
    // HRV 目前只有模拟来源；真实设备不提供时如实返回 0
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

  /**
   * 当前是否有可用的手腕设备（PRD §12：没有时 RED 干预走手机声音+屏幕，不假装震动）。
   * 真实 BLE 心率设备连上也算"佩戴"。
   */
  isWristPresent(): boolean {
    return this.connected || BleWatchService.getInstance().isConnected()
  }

  /** 模拟佩戴 / 断开（演示用；真实实现应由 BLE 连接状态驱动），并持久化 */
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
    StorageService.getInstance().saveKv(SensorService.KV_PRESENT, present ? '1' : '0').catch(() => {})
  }

  connect(): void {
    this.setPresent(true)
  }

  disconnect(): void {
    this.setPresent(false)
  }

  /** 手表状态一句话（设备页「模拟手表」条目下方的小字） */
  getStatusText(): string {
    if (!this.isWristPresent()) {
      return '未佩戴，走神干预为手机声音与屏幕'
    }
    const hr = this.getHeartRate()
    return hr > 0 ? `已佩戴 · 心率 ${hr} bpm` : '已佩戴'
  }
}
