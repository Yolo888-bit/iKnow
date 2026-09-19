import { vibrator } from '@kit.SensorServiceKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'

const DOMAIN = 0x0000
const TAG = 'iKnow.Feedback'

/**
 * 反馈服务 —— 云端**确认**分心后的触达手段。
 *
 * 设计约束（重要）：
 *  - 只在"识别结果明确"时调用（见 `FocusController.onObservation`），
 *    **不跟手表线索联动**——手表线索一变就震会变成骚扰；
 *  - 所有调用**失败静默**：无振动器、权限未授、模拟器不支持，都不影响专注主流程；
 *  - 语音提醒依赖 HMS（`@kit.CoreSpeechKit`），openharmony 侧无该 API，
 *    因此本服务只保留接口位，待真机可验证时实现（避免盲写一个编译得过但跑不起来的调用）。
 */
export class FeedbackService {
  private static inst: FeedbackService | null = null

  static getInstance(): FeedbackService {
    if (FeedbackService.inst === null) {
      FeedbackService.inst = new FeedbackService()
    }
    return FeedbackService.inst
  }

  private switchOn(key: string, defaultOn: boolean): boolean {
    const raw: number | undefined = AppStorage.get<number>(key)
    if (raw === undefined) {
      return defaultOn
    }
    return raw === 1
  }

  /** 震动开关（默认开） */
  isVibrateOn(): boolean {
    return this.switchOn(StorageKey.VIBRATE_ON, true)
  }

  /** 语音开关（默认关：依赖 HMS，环境不支持时无意义） */
  isVoiceOn(): boolean {
    return this.switchOn(StorageKey.VOICE_ON, false)
  }

  /**
   * 短震一次（约 0.3 秒）。用于"云端确认分心"的提醒。
   * 失败静默——没有振动器或权限未授时不该影响专注流程。
   */
  vibrateOnce(): void {
    if (!this.isVibrateOn()) {
      return
    }
    try {
      vibrator.startVibration(
        { type: 'time', duration: 300 },
        { usage: 'alarm' }
      ).catch((e: Error) => {
        hilog.info(DOMAIN, TAG, '震动不可用（可忽略）：%{public}s', e.message)
      })
    } catch (e) {
      hilog.info(DOMAIN, TAG, '震动调用异常（可忽略）')
    }
  }

  /**
   * 语音提醒（占位）。
   *
   * 为什么先不实现：TTS 在 **HMS 侧**（`@kit.CoreSpeechKit` → `speechKit.textToSpeech`），
   * openharmony 侧没有对应 API；在只有模拟器的环境里无法验证任何写法是否正确。
   * 盲写一个"能编译但跑不起来"的调用，不如等你到真机上我再一次写对。
   * 接口先留在这里，调用点已经接好（`FocusController.onObservation`）。
   */
  speak(text: string): void {
    if (!this.isVoiceOn()) {
      return
    }
    hilog.info(DOMAIN, TAG, '语音提醒待实现（需 HMS 真机）：%{public}s', text)
  }
}
