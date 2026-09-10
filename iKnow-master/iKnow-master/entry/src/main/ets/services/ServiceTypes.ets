import { FocusState, FocusSource } from '../models/Enums'

/** 视觉专注检测结果（由 FocusDetectionService 产出） */
export class FocusDetectionResult {
  state: FocusState = FocusState.FOCUSED
  confidence: number = 0
  source: FocusSource = FocusSource.CAMERA
  detail: string = ''
  timestamp: number = 0
}

/** 手腕动作数据 */
export class MotionData {
  motionLevel: number = 0
  wristMotion: number = 0
}

/**
 * 统一传感器抽象接口（PRD 第十四节）
 * 未来替换真实 HarmonyOS / BLE 设备实现时，仅需实现此接口
 */
export interface FocusSensor {
  getVisualState(): FocusDetectionResult
  getHeartRate(): number
  getHRV(): number
  getMotionData(): MotionData
}

/** 设备连接信息 */
export class DeviceInfo {
  type: string = ''
  name: string = ''
  connected: boolean = false
  statusText: string = ''
}
