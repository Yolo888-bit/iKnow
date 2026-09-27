import { DeviceInfo } from './ServiceTypes'
import { SensorService } from './SensorService'
import { PermissionService } from './PermissionService'

/**
 * 设备服务 —— 管理手机 / 摄像头 / 手表连接状态与模拟设备模式
 */
export class DeviceService {
  private static inst: DeviceService | null = null
  private cameraOn: boolean = true
  private simulateMode: boolean = true

  static getInstance(): DeviceService {
    if (DeviceService.inst === null) {
      DeviceService.inst = new DeviceService()
    }
    return DeviceService.inst
  }

  getDevices(): DeviceInfo[] {
    const list: DeviceInfo[] = []

    const phone = new DeviceInfo()
    phone.type = 'PHONE'
    phone.name = '本机'
    phone.connected = true
    phone.statusText = '已连接'
    list.push(phone)

    // 摄像头状态以真实授权为准，不再用独立的本地开关冒充
    const cameraOn = PermissionService.getInstance().snapshot().camera
    const camera = new DeviceInfo()
    camera.type = 'CAMERA'
    camera.name = '本机摄像头'
    camera.connected = cameraOn
    camera.statusText = cameraOn ? '感知中（信号触发时抓拍）' : '已关闭'
    list.push(camera)

    // 手表：模拟设备恒为「未佩戴」；只有真实 BLE 心率设备连上才算"有手腕设备"。
    // 用 isWristPresent()（含真实 BLE）而不是模拟开关，避免"真表已连却显示未连接"的自相矛盾。
    const watch = new DeviceInfo()
    watch.type = 'WATCH'
    watch.name = '模拟手表（非真实设备）'
    watch.connected = SensorService.getInstance().isWristPresent()
    watch.statusText = SensorService.getInstance().getStatusText()
    list.push(watch)

    return list
  }

  isCameraOn(): boolean {
    return this.cameraOn
  }

  setCamera(on: boolean): void {
    this.cameraOn = on
  }

  isSimulateMode(): boolean {
    return this.simulateMode
  }

  setSimulateMode(on: boolean): void {
    this.simulateMode = on
  }
}
