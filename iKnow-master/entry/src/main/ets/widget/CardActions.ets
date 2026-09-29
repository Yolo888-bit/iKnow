import { StorageKey } from '../common/Constants'

/** 本应用包名（`router` 事件建议显式给出，否则系统可能定位不到目标 Ability） */
const BUNDLE_NAME = 'com.iknow.study'
/** 卡片归属的模块名与入口 Ability（与 module.json5 一致） */
const MODULE_NAME = 'entry'
const ABILITY_NAME = 'EntryAbility'

/**
 * 服务卡片的 `postCardAction` 动作构造 —— 两张卡片共用。
 *
 * ⚠️ 两个最容易踩的坑（都踩过了，记在这里）：
 *  ① **必须用 `action: 'router'`**。`call` 只是把 UIAbility **后台**拉起来，不弹界面 ——
 *     表现为"点了卡片没反应"。`router` 才会把应用拉到前台。
 *  ② **卡片必须是动态卡片**（`form_config.json` 里 `isDynamic: true`）。
 *     静态卡片（`isDynamic: false`）压根不支持 `postCardAction`，必须改用 `FormLink`。
 *
 * 为什么参数名从 `StorageKey` 取而不是写字面量：卡片、深链调试、主进程
 * （`entrypoints/ExternalEntry.ets`）三处必须用**同一套键名**，写错一处就是"点了没反应"。
 * `StorageKey` 本身零依赖，卡片进程引入它是安全的（不会把 AppStore 拖进来）。
 *
 * 另：`postCardAction` 是 ArkUI 的**全局函数**，卡片里直接调用即可，不需要 import；
 * 且必须在控件的 `.onClick` 里直接调用（不能包一层异步）。
 */
export class CardRouterAction {
  action: string = 'router'
  bundleName: string = BUNDLE_NAME
  moduleName: string = MODULE_NAME
  abilityName: string = ABILITY_NAME
  params: Record<string, string> = {}
}

/**
 * 点整张卡 → 打开 App 并落到指定 Tab。
 * @param page 'home' = 首页；'review' = 复盘（取值见 ExternalEntry.PAGE_*）
 */
export function openAppAction(page: string): CardRouterAction {
  const a = new CardRouterAction()
  a.params[StorageKey.IK_ACTION] = 'open_app'
  a.params[StorageKey.IK_PAGE] = page
  return a
}

/** 点「开始专注」→ 直接起一段专注会话（是否开摄像头由专注页弹确认） */
export function startFocusAction(): CardRouterAction {
  const a = new CardRouterAction()
  a.params[StorageKey.IK_ACTION] = 'start_focus'
  return a
}
