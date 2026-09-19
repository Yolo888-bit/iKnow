import { hilog } from '@kit.PerformanceAnalysisKit'
import { AccelSample, RrSample } from '../models/WatchSignal'
import { WatchSignalSimulator } from './WatchSignalSimulator'

const DOMAIN = 0x0000
const TAG = 'iKnow.WatchSource'

/** 25Hz：人活动频率 < 20Hz，对加速度计足够（这是本方案唯一用到 25Hz 的地方） */
const SAMPLE_INTERVAL_MS = 40

/** 信号接收方（由事件引擎实现） */
export interface WatchSignalSink {
  onAccel(s: AccelSample): void
  onRr(s: RrSample): void
}

/**
 * 手表信号源。
 *
 * 目前**只有模拟实现**（复赛环境没有真实手表）。接入真表时新增一个基于
 * `BleWatchService` 的实现即可（HRS `0x2A37` 的 RR 解析位置已留好），上层不用改。
 *
 * ⚠️ 模拟实现产出的是**合成信号**，UI 与演示材料必须标注。
 */
export class WatchSignalSource {
  private static inst: WatchSignalSource | null = null
  private sim: WatchSignalSimulator = new WatchSignalSimulator()
  private timerId: number = -1
  private sink: WatchSignalSink | null = null

  static getInstance(): WatchSignalSource {
    if (WatchSignalSource.inst === null) {
      WatchSignalSource.inst = new WatchSignalSource()
    }
    return WatchSignalSource.inst
  }

  /** 当前信号是否为合成（代码/UI/PPT 三处都要如实标注） */
  isSimulated(): boolean {
    return true
  }

  getPhase(): string {
    return this.sim.getPhase()
  }

  /** 演示控制：切换合成信号的阶段 */
  setPhase(phase: string): void {
    this.sim.setPhase(phase, Date.now())
  }

  isBaselineDone(): boolean {
    return this.sim.isBaselineDone(Date.now())
  }

  isRunning(): boolean {
    return this.timerId >= 0
  }

  // ---- 信号控制台：逐项控制（都只改输入信号，判定仍走真算法）----
  setHeartRate(bpm: number): void {
    this.sim.setHeartRate(bpm)
  }

  setLowHrv(on: boolean): void {
    this.sim.setLowHrv(on)
  }

  setMotion(mode: string): void {
    this.sim.setMotion(mode)
  }

  setSpo2(v: number): void {
    this.sim.setSpo2(v)
  }

  currentBpm(): number {
    return this.sim.currentBpm()
  }

  currentSpo2(): number {
    return this.sim.getSpo2()
  }

  start(sink: WatchSignalSink): void {
    this.stop()
    this.sink = sink
    this.sim.reset(Date.now())
    this.timerId = setInterval(() => {
      const s = this.sink
      if (s === null) {
        return
      }
      this.sim.step(
        Date.now(),
        (a: AccelSample) => {
          s.onAccel(a)
        },
        (r: RrSample) => {
          s.onRr(r)
        }
      )
    }, SAMPLE_INTERVAL_MS)
    hilog.info(DOMAIN, TAG, '[合成信号] 信号源已启动，25Hz 加速度 + 心跳节拍 RR')
  }

  stop(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    this.sink = null
  }
}
