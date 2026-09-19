import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppStore } from '../store/AppStore'

const DOMAIN = 0x0000
const TAG = 'iKnow'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStore.getInstance().init(this.context).then(() => {
      hilog.info(DOMAIN, TAG, 'AppStore initialized')
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'AppStore init failed: ' + err.message)
    })
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

  /** 是否已完成首次引导（本地体验模式：以"是否设置过称呼"为标志，无账号体系） */
  private async loadStartPage(windowStage: window.WindowStage): Promise<void> {
    let page = 'pages/Login'
    try {
      const started = AppStore.getInstance().getUser().nickname.length > 0
      page = started ? 'pages/Index' : 'pages/Login'
    } catch (e) {
      page = 'pages/Login'
    }
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}d', err.code)
        return
      }
      hilog.info(DOMAIN, TAG, 'iKnow loaded: ' + page)
    })
  }
}
