import type AbilityConstant from "@ohos:app.ability.AbilityConstant";
import UIAbility from "@ohos:app.ability.UIAbility";
import type Want from "@ohos:app.ability.Want";
import type window from "@ohos:window";
import hilog from "@ohos:hilog";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
const DOMAIN = 0x0000;
const TAG = 'iKnow';
export default class EntryAbility extends UIAbility {
    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        AppStore.getInstance().init(this.context).then(() => {
            hilog.info(DOMAIN, TAG, 'AppStore initialized');
        }).catch((err: Error) => {
            hilog.error(DOMAIN, TAG, 'AppStore init failed: ' + err.message);
        });
    }
    onWindowStageCreate(windowStage: window.WindowStage): void {
        windowStage.loadContent('pages/Index', (err) => {
            if (err.code) {
                hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}d', err.code);
                return;
            }
            hilog.info(DOMAIN, TAG, 'iKnow loaded');
        });
    }
}
