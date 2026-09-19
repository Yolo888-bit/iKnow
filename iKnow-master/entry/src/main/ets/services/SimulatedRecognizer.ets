import { hilog } from '@kit.PerformanceAnalysisKit'
import { ObservationRecord } from '../models/WatchSignal'
import { FrameRecognizer } from './ObservationQueue'
import { WatchSignalSource } from './WatchSignalSource'
import { SimActivity } from './WatchSignalSimulator'

const DOMAIN = 0x0000
const TAG = 'iKnow.SimVision'

/**
 * 模拟视觉识别器 —— ⚠️ **产出的是模拟识别结果，不是真实识别**
 *
 * 为什么需要它：复赛环境**没有摄像头、也没有可上传的照片**，
 * 真实的多模态调用无法验证。但整条链路（触发 → 采集 → 识别 → 规则组合 →
 * 复盘时间线）必须能演示，因此这里提供与真实识别器**完全相同的接口实现**，
 * 让链路的其余部分保持真实、可利用。
 *
 * 诚实性约定（三处标注）：
 *  1. 代码注释（本段）
 *  2. 运行日志（TAG = iKnow.SimVision）
 *  3. 记录里的 evidence 字段写明"模拟识别"——复盘时间线上用户能直接看到
 *
 * 取值与云端模型**完全一致**（`Prompts.activity()` 的 7 个取值：做题 / 看书 /
 * 看手机 / 趴桌 / 离开 / 多人 / 无法判断），映射集中在 `SimActivity`，
 * 避免出现"工作台能选、云端永远给不出来"的假状态。
 *
 * 接入真实识别时只需把 `ObservationQueue.setRecognizer()` 换成网关实现，其余不动。
 */
export class SimulatedRecognizer implements FrameRecognizer {
  private static inst: SimulatedRecognizer | null = null

  static getInstance(): SimulatedRecognizer {
    if (SimulatedRecognizer.inst === null) {
      SimulatedRecognizer.inst = new SimulatedRecognizer()
    }
    return SimulatedRecognizer.inst
  }

  recognize(frames: ArrayBuffer[]): Promise<ObservationRecord | null> {
    const phase = WatchSignalSource.getInstance().getPhase()
    const activity = SimActivity.activityOf(phase)
    const o = new ObservationRecord()
    o.activity = activity
    o.handheld = activity === '看手机'
    o.facingDesk = activity === '做题' || activity === '看书'
    // "无法判断"如实给 0 置信度：它本来就不该产生任何结论
    o.confidence = activity === '无法判断' ? 0 : 0.9
    o.evidence = `模拟识别：与合成信号阶段「${phase}」对应（本机无摄像头，结果为演示数据）`
    hilog.info(DOMAIN, TAG, '[模拟识别] 阶段=%{public}s → activity=%{public}s（非真实识别）',
      phase, activity)
    return Promise.resolve(o)
  }
}
