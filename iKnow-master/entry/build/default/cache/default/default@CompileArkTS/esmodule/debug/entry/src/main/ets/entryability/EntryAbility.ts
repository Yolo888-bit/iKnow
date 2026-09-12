import type AbilityConstant from "@ohos:app.ability.AbilityConstant";
import UIAbility from "@ohos:app.ability.UIAbility";
import type Want from "@ohos:app.ability.Want";
import type window from "@ohos:window";
import hilog from "@ohos:hilog";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AuthService } from "@normalized:N&&&entry/src/main/ets/services/AuthService&";
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
        // 存储初始化完成后再决定入口页：已登录进主界面，否则先进登录页（登录门禁）
        AppStore.getInstance().init(this.context)
            .then(() => {
            this.loadStartPage(windowStage);
        })
            .catch((err: Error) => {
            hilog.error(DOMAIN, TAG, 'init before load failed: ' + err.message);
            windowStage.loadContent('pages/Login', (e) => {
                if (e.code) {
                    hilog.error(DOMAIN, TAG, 'loadContent Login failed: %{public}d', e.code);
                }
            });
        });
    }
    private async loadStartPage(windowStage: window.WindowStage): Promise<void> {
        let page = 'pages/Login';
        try {
            const logged = await AuthService.getInstance().isLoggedIn();
            page = logged ? 'pages/Index' : 'pages/Login';
        }
        catch (e) {
            page = 'pages/Login';
        }
        windowStage.loadContent(page, (err) => {
            if (err.code) {
                hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}d', err.code);
                return;
            }
            hilog.info(DOMAIN, TAG, 'iKnow loaded: ' + page);
        });
    }
}
