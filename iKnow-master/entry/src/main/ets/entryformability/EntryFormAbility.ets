import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'
import { StorageService } from '../services/StorageService'

const DOMAIN = 0x0000
const TAG = 'iKnow.Form'

/** 两张卡片的 form 名（与 `resources/base/profile/form_config.json` 一一对应） */
const FORM_TODAY = 'iknow_today_card'
const FORM_LONGTERM = 'iknow_longterm_card'

/**
 * 服务卡片的生命周期入口（两张卡片共用一个 ExtensionAbility）。
 *
 * 卡片可能运行在与主界面不同的上下文里，因此**不读主进程内存**，
 * 而是读取主界面在 `AppStore.pushAggregates()` 时写入的 KV 快照；
 * 读不到就退回占位文案，不编造数据。
 *
 * 两张卡的数据键不同，靠 `formInfo.FormParam.NAME_KEY` 区分：
 *   · 今日卡   todayFocus / focusRate / advice
 *   · 长期卡   ltTotal / ltStreak / ltDays
 * 注入多余的键不会出错，但**不能少注**——卡片侧 `@LocalStorageProp` 取不到就一直是占位值。
 */
export default class EntryFormAbility extends FormExtensionAbility {
  /** 本次要更新的是哪张卡（onUpdateForm 只给 formId，不给名字，得记下来） */
  private todayFocus: string = '0min'
  private focusRate: string = '0%'
  private advice: string = '开始一段专注吧'
  private ltTotal: string = '0min'
  private ltStreak: string = '0'
  private ltDays: string = '0'
  private isLongTerm: boolean = false

  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'onAddForm')
    // 先返回占位数据（onAddForm 必须同步返回），随后异步刷新为真实数据
    const params = want.parameters
    if (params !== undefined) {
      const formName = params[formInfo.FormParam.NAME_KEY]
      this.isLongTerm = formName === FORM_LONGTERM
      hilog.info(DOMAIN, TAG, 'onAddForm name=%{public}s', `${formName}`)
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
      if (this.isLongTerm) {
        const t = await svc.loadKv(StorageKey.CARD_LT_TOTAL)
        const s = await svc.loadKv(StorageKey.CARD_LT_STREAK)
        const d = await svc.loadKv(StorageKey.CARD_LT_DAYS)
        if (t.length > 0) {
          this.ltTotal = t
        }
        if (s.length > 0) {
          this.ltStreak = s
        }
        if (d.length > 0) {
          this.ltDays = d
        }
        return
      }
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
    if (this.isLongTerm) {
      return {
        'ltTotal': this.ltTotal,
        'ltStreak': this.ltStreak,
        'ltDays': this.ltDays
      }
    }
    return {
      'todayFocus': this.todayFocus,
      'focusRate': this.focusRate,
      'advice': this.advice
    }
  }
}
