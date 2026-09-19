import { ble, access, constant } from '@kit.ConnectivityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'iKnow.Ble'

/** 标准心率服务（HRS）UUID —— 只支持公开标准，不碰厂商私有协议 */
const HRS_SERVICE = '0000180D-0000-1000-8000-00805F9B34FB'
const HRS_MEASUREMENT = '00002A37-0000-1000-8000-00805F9B34FB'

/**
 * 真实蓝牙心率设备接入（标准 HRS）
 *
 * 诚实性约定：
 *  - 只扫描广播标准心率服务的设备；找不到就如实说"没找到"，不假装连上；
 *  - 连上但没有 0x2A37 特征时，明确提示"该设备未提供标准心率服务"
 *    （很多手环/手表用私有协议，本服务覆盖不到，这是已知边界）；
 *  - 未连接时 `getHeartRate()` 返回 0，由 `SensorService` 决定是否回落到模拟值。
 *
 * 资源管理：BLE 回调必须 `off` 注销、连接必须 `disconnect + close` 释放。
 */
export class BleWatchService {
  private static inst: BleWatchService | null = null

  private scanning: boolean = false
  private device: ble.GattClientDevice | null = null
  private connected: boolean = false
  private heartRate: number = 0
  private statusText: string = '未连接'
  private found: Array<ble.ScanResult> = []
  private connectTimer: number = -1

  private onFound: ((list: Array<ble.ScanResult>) => void) | null = null
  /** 真实生理数据回调：心率 + RR 间期（毫秒数组）——真实信号源靠它喂算法 */
  private onVitals: ((hr: number, rrMs: number[]) => void) | null = null
  private onState: (() => void) | null = null

  static getInstance(): BleWatchService {
    if (BleWatchService.inst === null) {
      BleWatchService.inst = new BleWatchService()
    }
    return BleWatchService.inst
  }

  setListeners(
    onFound: ((list: Array<ble.ScanResult>) => void) | null,
    onState: (() => void) | null
  ): void {
    this.onFound = onFound
    this.onState = onState
  }

  /** 注册生理数据回调（真实信号源用）；传 null 取消 */
  setVitalsListener(cb: ((hr: number, rrMs: number[]) => void) | null): void {
    this.onVitals = cb
  }

  isConnected(): boolean {
    return this.connected
  }

  getHeartRate(): number {
    return this.heartRate
  }

  getStatusText(): string {
    return this.statusText
  }

  getFound(): Array<ble.ScanResult> {
    return this.found
  }

  isScanning(): boolean {
    return this.scanning
  }

  private isBluetoothOn(): boolean {
    return access.getState() === access.BluetoothState.STATE_ON
  }

  /** 开始扫描广播标准心率服务的设备；返回错误提示（空串 = 已开始） */
  async startScan(): Promise<string> {
    if (!this.isBluetoothOn()) {
      return '蓝牙未开启，请先在系统设置中打开蓝牙'
    }
    this.found = []
    if (this.onFound !== null) {
      this.onFound([])
    }
    if (!this.scanning) {
      ble.on('BLEDeviceFind', (results: Array<ble.ScanResult>) => {
        for (const r of results) {
          let exists = false
          for (const x of this.found) {
            if (x.deviceId === r.deviceId) {
              exists = true
              break
            }
          }
          if (!exists) {
            this.found.push(r)
            hilog.info(DOMAIN, TAG, 'found device id=%{public}s rssi=%{public}d',
              r.deviceId, r.rssi)
          }
        }
        if (this.onFound !== null) {
          this.onFound(this.found)
        }
      })
      this.scanning = true
    }
    try {
      const filters: Array<ble.ScanFilter> = [{ serviceUuid: HRS_SERVICE }]
      ble.startBLEScan(filters)
      return ''
    } catch (err) {
      const e = err as BusinessError
      return `扫描失败 ${e.code}: ${e.message}`
    }
  }

  stopScan(): void {
    if (!this.scanning) {
      return
    }
    try {
      ble.stopBLEScan()
    } catch (e) {
      // ignore
    }
    try {
      ble.off('BLEDeviceFind')
    } catch (e) {
      // ignore
    }
    this.scanning = false
  }

  /** 连接指定设备（连接是同步发起、结果靠事件回调） */
  connect(deviceId: string): void {
    if (this.connected) {
      this.disconnect()
    }
    this.statusText = '连接中…'
    this.emitState()
    try {
      const d = ble.createGattClientDevice(deviceId)
      this.device = d
      d.on('BLEConnectionStateChange', (st: ble.BLEConnectionChangeState) => {
        hilog.info(DOMAIN, TAG, 'conn state=%{public}d id=%{public}s', st.state, st.deviceId)
        if (st.state === constant.ProfileConnectionState.STATE_CONNECTED) {
          this.connected = true
          this.subscribeHeartRate()
        } else if (st.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
          this.connected = false
          this.heartRate = 0
          this.statusText = '已断开'
          this.emitState()
        }
      })
      d.connect()
    } catch (err) {
      const e = err as BusinessError
      this.statusText = `连接失败 ${e.code}: ${e.message}`
      this.emitState()
      return
    }
    // connect() 同步返回，超时要自己兜底
    if (this.connectTimer >= 0) {
      clearTimeout(this.connectTimer)
    }
    this.connectTimer = setTimeout(() => {
      if (!this.connected) {
        this.statusText = '连接超时：该设备可能不支持标准心率服务，或距离太远'
        this.emitState()
      }
    }, 10000)
  }

  private async subscribeHeartRate(): Promise<void> {
    const d = this.device
    if (d === null) {
      return
    }
    try {
      const services: Array<ble.GattService> = await d.getServices()
      let target: ble.BLECharacteristic | null = null
      for (const s of services) {
        if (s.serviceUuid.toUpperCase().indexOf('180D') < 0) {
          continue
        }
        for (const c of s.characteristics) {
          if (c.characteristicUuid.toUpperCase().indexOf('2A37') >= 0) {
            target = c
            break
          }
        }
        if (target !== null) {
          break
        }
      }
      if (target === null) {
        let names = ''
        for (const s of services) {
          names += `${s.serviceUuid} `
        }
        hilog.warn(DOMAIN, TAG, 'no HRS 2A37, services=[%{public}s]', names)
        this.statusText = '已连接，但该设备未提供标准心率服务（0x180D/0x2A37）'
        this.emitState()
        return
      }
      d.on('BLECharacteristicChange', (c: ble.BLECharacteristic) => {
        const buf: ArrayBuffer = c.characteristicValue
        this.heartRate = BleWatchService.parseHeartRate(buf)
        // RR 间期（flags bit4=0x10 时附带）：**算法算 RMSSD 必须要有它**，
        // 只解心率是不够的 —— 这正是"连上手表也用不了"的原因。
        const rr = BleWatchService.parseRrIntervals(buf)
        this.statusText = rr.length > 0
          ? `已连接 · 心率实时更新（含 RR ${rr.length} 个）`
          : '已连接 · 心率实时更新（该设备未附带 RR 间期）'
        hilog.info(DOMAIN, TAG, 'hr=%{public}d rr=%{public}d 个', this.heartRate, rr.length)
        if (this.onVitals !== null) {
          this.onVitals(this.heartRate, rr)
        }
        this.emitState()
      })
      await d.setCharacteristicChangeNotification(target, true)
      this.statusText = '已连接，等待心率数据…'
      hilog.info(DOMAIN, TAG, 'subscribed HRS 2A37')
      this.emitState()
    } catch (err) {
      const e = err as BusinessError
      this.statusText = `订阅心率失败 ${e.code}: ${e.message}`
      this.emitState()
    }
  }

  /**
   * 按 HRS 规范解析 **RR 间期**（毫秒）。
   *
   * `0x2A37` 布局：flags(1B) + HR(1~2B) [+ EnergyExpended(2B)] [+ RR 数组]
   *  - flags bit0 = 1 → HR 占 2 字节
   *  - flags bit3 = 0x08 → 含 EnergyExpended（占 2 字节，需跳过）
   *  - **flags bit4 = 0x10 → 其后为 RR 间期数组**，每个 uint16 小端，单位 1/1024 秒
   *
   * 设备不附带 RR 时返回空数组（此时算法无法算 HRV，会如实降级，不编造）。
   */
  private static parseRrIntervals(buf: ArrayBuffer): number[] {
    const out: number[] = []
    const bytes = new Uint8Array(buf)
    if (bytes.length < 3) {
      return out
    }
    const flags = bytes[0]
    if ((flags & 0x10) === 0) {
      return out
    }
    let offset = 1 + (((flags & 0x01) === 0) ? 1 : 2)
    if ((flags & 0x08) !== 0) {
      offset += 2
    }
    while (offset + 1 < bytes.length) {
      const raw = bytes[offset] | (bytes[offset + 1] << 8)
      const rrMs = Math.round(raw * 1000 / 1024)
      // 只保留生理可能区间，伪影直接丢（RMSSD 对单个坏点极敏感）
      if (rrMs >= 300 && rrMs <= 2000) {
        out.push(rrMs)
      }
      offset += 2
    }
    return out
  }

  /** 按 HRS 规范解析：flags 位 0 = 0 时心率是 8bit，= 1 时是 16bit（小端） */
  private static parseHeartRate(buf: ArrayBuffer): number {
    const bytes = new Uint8Array(buf)
    if (bytes.length < 2) {
      return 0
    }
    const flags = bytes[0]
    if ((flags & 0x01) === 0) {
      return bytes[1]
    }
    if (bytes.length < 3) {
      return 0
    }
    return bytes[1] | (bytes[2] << 8)
  }

  disconnect(): void {
    if (this.connectTimer >= 0) {
      clearTimeout(this.connectTimer)
      this.connectTimer = -1
    }
    const d = this.device
    if (d !== null) {
      try {
        d.off('BLECharacteristicChange')
      } catch (e) {
        // ignore
      }
      try {
        d.off('BLEConnectionStateChange')
      } catch (e) {
        // ignore
      }
      try {
        d.disconnect()
      } catch (e) {
        // ignore
      }
      try {
        d.close()
      } catch (e) {
        // ignore
      }
    }
    this.device = null
    this.connected = false
    this.heartRate = 0
    this.statusText = '未连接'
    this.emitState()
  }

  private emitState(): void {
    if (this.onState !== null) {
      this.onState()
    }
  }
}
