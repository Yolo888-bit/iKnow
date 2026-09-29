import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'

const DOMAIN = 0x0000
const TAG = 'iKnow.Entry'

/**
 * 外部唤起的参数与取值 —— **单一事实源**。
 *
 * 两个入口共用同一套参数（这正是本模块存在的意义：同一条链路，多处驱动）：
 *   ① 服务卡片（今日卡 / 长期卡）→ `postCardAction({action:'call'})` → EntryAbility.onNewWant
 *   ② 命令行调试 → `hdc shell aa start -a EntryAbility -b com.iknow.study --ps ik_action open_app`
 *
 * 为什么用 `ik_` 前缀：want 参数会与系统字段混在一起，不带前缀迟早撞名。
 * 参数名放在 `common/Constants.ets`（`StorageKey.IK_*`）是为了让**服务卡片也能引用** ——
 * 卡片跑在独立进程，不该为了几个字符串把 AppStore / StorageService 一起拉进来。
 */
export class ExternalEntry {
  static readonly PARAM_ACTION = StorageKey.IK_ACTION
  static readonly PARAM_MODE = StorageKey.IK_MODE
  static readonly PARAM_PAGE = StorageKey.IK_PAGE

  /** 打开 App（卡片整卡点击） */
  static readonly ACTION_OPEN_APP = 'open_app'
  /** 直接起一段专注（今日卡上的「开始专注」按钮） */
  static readonly ACTION_START_FOCUS = 'start_focus'

  /** 本次不抓拍、不上传（与首页「仅计时开始」同义） */
  static readonly MODE_TIMER_ONLY = 'timer_only'

  /** `ik_page` 的取值；Tab 下标要与 `pages/Index.ets` 的 tabBar 顺序一致（首页 0 / 复盘 2） */
  static readonly PAGE_HOME = 'home'
  static readonly PAGE_REVIEW = 'review'
  static readonly TAB_HOME = 0
  static readonly TAB_REVIEW = 2
}

/** 卡片 `router` 事件可能把 params 包一层的键名 */
const PARAM_WRAPPER = 'params'

/**
 * 从 want 里取出卡片 / 深链的业务参数。
 *
 * `router` 事件下 `params` 的落地形状在不同版本里出现过两种：**平铺**进 `want.parameters`，
 * 或**包一层** `want.parameters.params`。两个都认 —— 猜错一种的后果是"点了卡片没反应"，
 * 而且设备上完全不报错，只能靠猜。收到哪种形状由 `EntryAbility.onCreate` 的 hilog 自证。
 */
function pickParams(raw: Record<string, Object> | undefined): Record<string, Object> | undefined {
  if (raw === undefined || raw === null) {
    return undefined
  }
  const inner = raw[PARAM_WRAPPER]
  if (inner !== undefined && inner !== null) {
    return inner as Record<string, Object>
  }
  return raw
}

/**
 * 「打开 App」要落在哪个 Tab。
 *
 * @returns -1 = 这次 want 不是「打开 App」；否则是目标 Tab 下标
 */
export function desiredTab(raw: Record<string, Object> | undefined): number {
  const params = pickParams(raw)
  if (params === undefined) {
    return -1
  }
  if (params[ExternalEntry.PARAM_ACTION] !== ExternalEntry.ACTION_OPEN_APP) {
    return -1
  }
  const page = params[ExternalEntry.PARAM_PAGE]
  if (page === ExternalEntry.PAGE_REVIEW) {
    return ExternalEntry.TAB_REVIEW
  }
  return ExternalEntry.TAB_HOME
}

/**
 * 「开始专注」外部唤起的状态准备。
 *
 * ⚠️ 顺序不能颠倒：`Focus.aboutToAppear` 会**立刻**读 `AppStore.getCurrentPlan()` 开会话，
 * 冷启动时若不先 `await init()`，会话就会挂着一个空计划开始（表现为"从卡片进来没有今日任务"）。
 * `init()` 内部已完成 `StorageService` → `PermissionService` → `SensorService` 与 `restorePlan()`。
 *
 * 这里**只准备状态、不直接开会话**，也**不替用户决定是否开启感知** ——
 * 采集授权点只有"开始专注时的感知确认"，卡片不能绕过它（见
 * `StorageKey.FOCUS_CONFIRM_PERCEPTION_REQUEST`）。专注页会弹同一条确认再开始。
 *
 * @returns true = 这次确实是一次「开始专注」的外部唤起，调用方应据此跳转
 */
export async function prepareExternalStartFocus(
  ctx: common.UIAbilityContext,
  raw: Record<string, Object> | undefined
): Promise<boolean> {
  const params = pickParams(raw)
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
 * 放弃这次「开始专注」：把上面那几个标记清干净。
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
