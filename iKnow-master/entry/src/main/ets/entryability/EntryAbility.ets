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
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}d', err.code)
        return
      }
      hilog.info(DOMAIN, TAG, 'iKnow loaded')
    })
  }
}
