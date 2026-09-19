import { ObservationRecord } from '../models/WatchSignal'
import { FrameRecognizer } from './ObservationQueue'
import { AIService } from './AIService'

/**
 * 真实视觉识别器 —— 把触发时抓拍的帧交给网关的多模态模型（qwen-vl-plus）。
 *
 * 未配置 Key、无帧、超时、解析失败都返回 null；由 `ObservationQueue`
 * 如实记为「无法判断」，绝不编造 activity。
 *
 * 与 `SimulatedRecognizer` 实现同一接口，因此**切换只需换一行注入**。
 */
export class GatewayRecognizer implements FrameRecognizer {
  private static inst: GatewayRecognizer | null = null

  static getInstance(): GatewayRecognizer {
    if (GatewayRecognizer.inst === null) {
      GatewayRecognizer.inst = new GatewayRecognizer()
    }
    return GatewayRecognizer.inst
  }

  recognize(frames: ArrayBuffer[]): Promise<ObservationRecord | null> {
    return AIService.getInstance().recognizeActivity(frames)
  }
}
