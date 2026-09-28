import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { router, window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppStore } from '../store/AppStore'
import { AuthService } from '../services/AuthService'
import { FocusController } from '../services/FocusController'
import { prepareExternalStartFocus, resetPendingExternalStart } from '../insightintent/ExternalEntry'

const DOMAIN = 0x0000
const TAG = 'iKnow'

export default class EntryAbility extends UIAbility {
  /**
   * 这次冷启动是否由外部唤起触发（服务卡片按钮 / 意图框架 / `hdc aa start`）。
   * 判定放在 onCreate，跳转放到 loadContent 回调里 —— 内容没加载完就 `pushUrl` 会跳失败。
   */
  private externalStartFocus: boolean = false
  /** 外部唤起的判定结果（onCreate 里发起，loadStartPage 里 await，避免竞态） */
  private externalCheck: Promise<boolean> = Promise.resolve(false)

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStore.getInstance().init(this.context).then(() => {
      hilog.info(DOMAIN, TAG, 'AppStore initialized')
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'AppStore init failed: ' + err.message)
    })
    // 外部唤起：只判定与准备状态，不在这里跳页（窗口内容还没加载）
    this.externalCheck = prepareExternalStartFocus(this.context, want.parameters)
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '外部唤起判定失败：%{public}s', err.message)
        return false
      })
  }

  /**
   * 应用已在运行时又收到 want（用户切走后再点卡片 / 小艺再次唤起）。
   * 这时窗口内容已就绪，可以直接跳；但仍要过一遍门禁 —— 运行中不等于已登录。
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    prepareExternalStartFocus(this.context, want.parameters)
      .then(async (hit: boolean) => {
        if (!hit) {
          return
        }
        const allowed = await this.canEnterApp()
        if (!allowed) {
          resetPendingExternalStart()
          hilog.info(DOMAIN, TAG, 'onNewWant 被丢弃：未登录或未设目标')
          return
        }
        router.pushUrl({ url: 'pages/Focus' })
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'onNewWant 处理失败：%{public}s', err.message)
      })
  }

  /** 应用门禁：已登录且走过目标引导，才允许进主界面（loadStartPage 与 onNewWant 共用） */
  private async canEnterApp(): Promise<boolean> {
    try {
      const loggedIn = await AuthService.getInstance().isLoggedIn()
      if (!loggedIn) {
        return false
      }
      // 用显式标记判断是否走过目标引导，避免历史残留的目标数据把引导顶掉
      return await AppStore.getInstance().isGoalConfigured()
    } catch (e) {
      return false
    }
  }

  /**
   * 回到前台：结算"专注中切走"的那段时间。
   *
   * 放在 Ability 生命周期而不是页面的 onPageHide，是因为页面的 hide 在应用内部跳转
   * （专注 → 答疑 / 休息）时也会触发，会把正常跳转误判成"去用手机了"。
   * 只有整个应用进入后台，才是"人在别的应用上"。
   */
  onForeground(): void {
    FocusController.getInstance().onAppForeground()
  }

  /**
   * 进入后台：只记录时刻与屏幕状态并结清已过去的段，**是否算分心留到回前台时判定** ——
   * 熄屏（手机扣在桌上学习）是核心场景，不能算分心；而且后台定时器会被冻结，
   * 离开多久只有回到前台时用真实时钟才知道。
   */
  onBackground(): void {
    FocusController.getInstance().onAppBackground()
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 存储初始化完成后再决定入口页：已登录进主界面，否则先进登录页（登录门禁）
    this.initWithRetry().then((ok: boolean) => {
      if (ok) {
        this.loadStartPage(windowStage)
        return
      }
      windowStage.loadContent('pages/Login', (e) => {
        if (e.code) {
          hilog.error(DOMAIN, TAG, 'loadContent Login failed: %{public}d', e.code)
        }
      })
    })
  }

  /**
   * 初始化失败重试一次再决定入口页。
   * 原先 initPromise 一旦失败就永久缓存在 rejected 上，同一个进程内没有第二次机会：
   * 用户看到的就是"直接掉回引导页、数据全没了"。
   */
  private async initWithRetry(): Promise<boolean> {
    try {
      await AppStore.getInstance().init(this.context)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init before load failed: ' + err.message)
    }
    try {
      await AppStore.getInstance().init(this.context)
      return true
    } catch (err2) {
      hilog.error(DOMAIN, TAG, 'init retry failed: ' + err2.message)
      return false
    }
  }

  /**
   * 入口页门禁：
   *  未登录 → 登录页；已登录但还没设目标 → 目标设置页；都完成 → 主界面。
   *
   * 外部唤起（卡片 / 意图 / hdc）只在**已登录且设过目标**时才直达专注页；
   * 否则把这次请求丢掉并清标记 —— 不能把专注页压在登录页上面。
   */
  private async loadStartPage(windowStage: window.WindowStage): Promise<void> {
    let page = 'pages/Login'
    try {
      const loggedIn = await AuthService.getInstance().isLoggedIn()
      if (!loggedIn) {
        page = 'pages/Login'
      } else {
        const configured = await AppStore.getInstance().isGoalConfigured()
        page = configured ? 'pages/Index' : 'pages/GoalSetup'
      }
    } catch (e) {
      page = 'pages/Login'
    }
    // 等外部唤起判定完（它内部会 await AppStore.init，幂等），再决定要不要跳
    const external = await this.externalCheck
    const canJump = external && page === 'pages/Index'
    if (external && !canJump) {
      resetPendingExternalStart()
      hilog.info(DOMAIN, TAG, '外部唤起被丢弃：当前入口页是 %{public}s', page)
    }
    this.externalStartFocus = canJump
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}d', err.code)
        return
      }
      hilog.info(DOMAIN, TAG, 'iKnow loaded: ' + page)
      // 内容就绪后再跳，否则 router 可能拿不到页面栈
      if (this.externalStartFocus) {
        this.externalStartFocus = false
        router.pushUrl({ url: 'pages/Focus' })
      }
    })
  }
}
