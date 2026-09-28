import { insightIntent, InsightIntentEntry, InsightIntentEntryExecutor, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ExternalEntry } from './ExternalEntry'

const DOMAIN = 0x0000
const TAG = 'iKnow.Intent'

/** 本应用自己的包名与入口 Ability（意图执行器要显式拉起它） */
const BUNDLE_NAME = 'com.iknow.study'
const ENTRY_ABILITY = 'EntryAbility'

/**
 * 意图入口：小艺说「开始专注」→ 起一段专注会话。
 *
 * 为什么执行器里**不直接开始会话**，而是把 want 转给 `EntryAbility`：
 *  ① 卡片按钮、意图、`hdc aa start` 三条路必须走**同一段代码**（见 `ExternalEntry.ets`），
 *     否则三条路的"会话状态准备顺序"迟早各写一份、各错一份；
 *  ② 会话开始前要先 `await AppStore.init()`（冷启动时计划/权限都还没就绪），
 *     这套时序只在 `EntryAbility` 里成立；
 *  ③ 是否开启摄像头**由用户确认**（授权点唯一），执行器不该替用户决定。
 *
 * `executeMode` 选 `UI_ABILITY_BACKGROUND`：执行器自己不渲染界面，只是把请求转给
 * 能渲染的那个 Ability —— 选 FOREGROUND 会让系统按"执行器自带界面"来调度，与我们的做法不符。
 *
 * ⚠️ 现状说明（写进比赛材料时必须保留这句话）：**小艺侧识别到这条意图需要先在
 * AGC 申请意图框架并在小艺开放平台注册意图**（未注册时 `shareIntent` 会抛
 * `1000101101`）。本工程只完成了"声明 + 实现"，注册与白名单未办。
 * 因此演示走卡片按钮或 `hdc` 深链驱动同一段代码。
 */
@InsightIntentEntry({
  intentName: 'StartFocus',
  domain: 'iKnow',
  intentVersion: '1.0.0',
  displayName: '开始专注',
  displayDescription: '让小伴开始一段专注学习会话',
  llmDescription: '开始一段专注学习，可选择是否开启摄像头感知',
  keywords: ['开始专注', '专注', '学习', 'iKnow'],
  abilityName: ENTRY_ABILITY,
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND]
})
export class StartFocusExecutor extends InsightIntentEntryExecutor<string> {
  onExecute(): Promise<insightIntent.IntentResult<string>> {
    return new Promise<insightIntent.IntentResult<string>>((resolve) => {
      const params: Record<string, Object> = {}
      // 参数名与卡片 / hdc 完全一致：见 common/Constants.ets 的 StorageKey.IK_ACTION
      params[ExternalEntry.PARAM_ACTION] = ExternalEntry.ACTION_START_FOCUS
      const want: Want = {
        bundleName: BUNDLE_NAME,
        abilityName: ENTRY_ABILITY,
        parameters: params
      }
      this.context.startAbility(want)
        .then(() => {
          hilog.info(DOMAIN, TAG, '意图 StartFocus：已转交 EntryAbility')
          resolve({ code: 0, result: 'ok' })
        })
        .catch((err: Error) => {
          // 如实返回失败码，不假装成功（硬规则：不伪造）
          hilog.error(DOMAIN, TAG, '意图 StartFocus 转交失败：%{public}s', err.message)
          resolve({ code: -1, result: 'start ability failed' })
        })
    })
  }
}
