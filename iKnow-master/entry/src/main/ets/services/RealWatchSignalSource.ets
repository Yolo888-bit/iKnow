import { sensor } from '@kit.SensorServiceKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AccelSample, RrSample } from '../models/WatchSignal'
import { BleWatchService } from './BleWatchService'
import { WatchEventEngine } from './WatchEventEngine'

const DOMAIN = 0x0000
const TAG = 'iKnow.RealWatch'
/** 25Hz：与模拟源一致，保证引擎侧行为完全相同 */
const SAMPLE_INTERVAL_NS = 40000000
const SAMPLE_INTERVAL_MS = 40

/**
 * 真实手表信号源 —— 真机 + 真表连上后，由它驱动算法。
 *
 * 组成：
 *  - **手表**：标准 HRS（`0x180D`/`0x2A37`）的心率 + **RR 间期**（RR 是算 RMSSD 的前提）
 *  - **手机加速度**：手表多数不通过标准 profile 暴露加速度，因此动作来源用手机加速度计
 *
 * 关键：它直接调用 `WatchEventEngine.onRr/onAccel` —— 与模拟源**共用同一个引擎**，
 * 所以基线/SQI/触发/节流这些算法一行都不用改。
 */
export class RealWatchSignalSource {
  private static inst: RealWatchSignalSource | null = null
  private running: boolean = false
  private accelOn: boolean = false
  private lastAccelMs: number = 0

  static getInstance(): RealWatchSignalSource {
    if (RealWatchSignalSource.inst === null) {
      RealWatchSignalSource.inst = new RealWatchSignalSource()
    }
    return RealWatchSignalSource.inst
  }

  isRunning(): boolean {
    return this.running
  }

  start(): void {
    if (this.running) {
      return
    }
    this.running = true

    // —— 手表：心率 + RR 间期 ——
    BleWatchService.getInstance().setVitalsListener((hr: number, rrMs: number[]) => {
      if (!this.running || rrMs.length === 0) {
        return
      }
      const now = Date.now()
      // 一包可能带多个 RR：按顺序近似回推时间戳，让引擎看到的序列是时间的
      for (let i = 0; i < rrMs.length; i++) {
        const s = new RrSample()
        s.tMs = now - (rrMs.length - 1 - i) * rrMs[i]
        s.rrMs = rrMs[i]
        s.quality = 1
        WatchEventEngine.getInstance().onRr(s)
      }
    })

    // —— 手机加速度（真实路径的动作来源）——
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        if (!this.running) {
          return
        }
        const now = Date.now()
        // 传感器可能高于 25Hz，这里降采样，保证与模拟源同频
        if (now - this.lastAccelMs < SAMPLE_INTERVAL_MS) {
          return
        }
        this.lastAccelMs = now
        const a = new AccelSample()
        a.tMs = now
        a.x = data.x
        a.y = data.y
        a.z = data.z
        WatchEventEngine.getInstance().onAccel(a)
      }, { interval: SAMPLE_INTERVAL_NS })
      this.accelOn = true
    } catch (e) {
      // 无加速度计/未授权：动作维度失效，但心率/RR 仍可用（如实降级）
      this.accelOn = false
      hilog.error(DOMAIN, TAG, '手机加速度计不可用，动作维度降级')
    }

    hilog.info(DOMAIN, TAG, '真实信号源已启动（心率+RR 来自手表，加速度来自手机=%{public}s）',
      this.accelOn ? '可用' : '不可用')
  }

  stop(): void {
    if (!this.running) {
      return
    }
    this.running = false
    BleWatchService.getInstance().setVitalsListener(null)
    if (this.accelOn) {
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER)
      } catch (e) {
        // ignore
      }
      this.accelOn = false
    }
    hilog.info(DOMAIN, TAG, '真实信号源已停止')
  }
}
