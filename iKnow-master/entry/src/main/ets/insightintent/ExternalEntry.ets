import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'

const DOMAIN = 0x0000
const TAG = 'iKnow.Entry'

/**
 * 外部唤起的参数名与取值 —— **单一事实源**。
 *
 * 三个入口共用同一套参数（这正是本模块存在的意义：同一条链路，三处驱动）：
 *   ① 服务卡片按钮 → `postCardAction({action:'call'})`  → EntryAbility.onNewWant
 *   ② 意图框架      → `@InsightIntentEntry` 执行器
 *   ③ 命令行调试    → `hdc shell aa start -a EntryAbility -b com.iknow.study --ps ik_action start_focus`
 *
 * 为什么用 `ik_` 前缀：want 参数会与系统字段混在一起，不带前缀迟早撞名。
 */
export class ExternalEntry {
  /** 参数名来自 `StorageKey.IK_ACTION` / `IK_MODE`（卡片也能引用，见那里的说明） */
  static readonly PARAM_ACTION = StorageKey.IK_ACTION
  static readonly PARAM_MODE = StorageKey.IK_MODE

  /** 开始一段专注会话（目前唯一支持的唤起动作） */
  static readonly ACTION_START_FOCUS = 'start_focus'
  /** 本次不抓拍、不上传（与首页「仅计时开始」同义） */
  static readonly MODE_TIMER_ONLY = 'timer_only'
}

/**
 * 外部唤起的统一落地：把状态准备好，并把"要开始专注"这件事交给既有的一套标记。
 *
 * ⚠️ 顺序不能颠倒：`Focus.aboutToAppear` 会**立刻**读 `AppStore.getCurrentPlan()` 开会话，
 * 冷启动时若不先 `await init()`，会话就会挂着一个空计划开始（表现为"从卡片进来没有今日任务"）。
 * `init()` 内部已完成 `StorageService` → `PermissionService` → `SensorService` 与 `restorePlan()`。
 *
 * 这里**只准备状态、不直接开会话**，也**不替用户决定是否开启感知** ——
 * 采集授权点只有"开始专注时的感知确认"，外部入口不能绕过它（见
 * `StorageKey.FOCUS_CONFIRM_PERCEPTION_REQUEST`）。专注页会弹同一条确认再开始。
 *
 * @returns true = 这次确实是一次「开始专注」的外部唤起，调用方应据此跳转
 */
export async function prepareExternalStartFocus(
  ctx: common.UIAbilityContext,
  params: Record<string, Object> | undefined
): Promise<boolean> {
  if (params === undefined) {
    return false
  }
  const action = params[ExternalEntry.PARAM_ACTION]
  if (action !== ExternalEntry.ACTION_START_FOCUS) {
    return false
  }

  try {
    await AppStore.getInstance().init(ctx)
  } catch (e) {
    hilog.error(DOMAIN, TAG, '外部唤起前初始化失败，放弃直达：%{public}s', (e as Error).message)
    return false
  }

  // 与 Home.beginFocus() / enterFocus() 同一套标记（见 pages/Home.ets）
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 1)
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_HOME_INCOMPLETE_REQUEST, 1)
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_TIMER_ONLY_REQUEST, 0)
  // 外部入口多这一步：先弹确认再开始（首页路径已在弹窗里问过了，不用重复）
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_CONFIRM_PERCEPTION_REQUEST, 1)

  hilog.info(DOMAIN, TAG, '外部唤起「开始专注」：已准备好会话状态，待专注页确认感知')
  return true
}

/**
 * 放弃这次外部唤起：把上面那几个标记清干净。
 *
 * 必须清的原因：标记是全局的，留着就会在用户**后来自己**从首页点「开始专注」时
 * 多弹一次感知确认（首页已经问过了），或者让本次会话莫名变成"仅计时"。
 * 会走到这里的情形：还没登录 / 还没设目标（此时不该把专注页压到登录页上面）。
 */
export function resetPendingExternalStart(): void {
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 0)
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_HOME_INCOMPLETE_REQUEST, 0)
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_TIMER_ONLY_REQUEST, 0)
  AppStorage.setOrCreate<number>(StorageKey.FOCUS_CONFIRM_PERCEPTION_REQUEST, 0)
}
