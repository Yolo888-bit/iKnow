import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'
import { StorageService } from '../services/StorageService'

const DOMAIN = 0x0000
const TAG = 'iKnow.Form'

/**
 * 服务卡片的生命周期入口。
 *
 * 卡片可能运行在与主界面不同的上下文里，因此**不读主进程内存**，
 * 而是读取主界面在 `AppStore.pushAggregates()` 时写入的 3 个 KV 快照；
 * 读不到就退回占位文案，不编造数据。
 */
export default class EntryFormAbility extends FormExtensionAbility {
  private todayFocus: string = '0min'
  private focusRate: string = '0%'
  private advice: string = '开始一段专注吧'

  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'onAddForm')
    // 先返回占位数据（onAddForm 必须同步返回），随后异步刷新为真实数据
    const params = want.parameters
    if (params !== undefined) {
      const formId = params[formInfo.FormParam.IDENTITY_KEY]
      if (typeof formId === 'string') {
        this.refresh(formId)
      }
    }
    return formBindingData.createFormBindingData(this.buildData())
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onUpdateForm')
    this.refresh(formId)
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm')
  }

  private refresh(formId: string): void {
    this.loadFromStore()
      .then(() => {
        return formProvider.updateForm(formId, formBindingData.createFormBindingData(this.buildData()))
      })
      .catch((e: Error) => {
        hilog.error(DOMAIN, TAG, 'refresh failed: %{public}s', e.message)
      })
  }

  private async loadFromStore(): Promise<void> {
    try {
      const svc = StorageService.getInstance()
      await svc.init(this.context)
      const t = await svc.loadKv(StorageKey.CARD_TODAY)
      const r = await svc.loadKv(StorageKey.CARD_RATE)
      const a = await svc.loadKv(StorageKey.CARD_ADVICE)
      if (t.length > 0) {
        this.todayFocus = t
      }
      if (r.length > 0) {
        this.focusRate = r
      }
      if (a.length > 0) {
        this.advice = a
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'load card snapshot failed, keep defaults')
    }
  }

  private buildData(): Record<string, string> {
    return {
      'todayFocus': this.todayFocus,
      'focusRate': this.focusRate,
      'advice': this.advice
    }
  }
}
