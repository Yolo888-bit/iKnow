if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Login_Params {
    username?: string;
    password?: string;
    errorMsg?: string;
    loading?: boolean;
}
import router from "@ohos:router";
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AuthService } from "@normalized:N&&&entry/src/main/ets/services/AuthService&";
class Login extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__username = new ObservedPropertySimplePU('', this, "username");
        this.__password = new ObservedPropertySimplePU('', this, "password");
        this.__errorMsg = new ObservedPropertySimplePU('', this, "errorMsg");
        this.__loading = new ObservedPropertySimplePU(false, this, "loading");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Login_Params) {
        if (params.username !== undefined) {
            this.username = params.username;
        }
        if (params.password !== undefined) {
            this.password = params.password;
        }
        if (params.errorMsg !== undefined) {
            this.errorMsg = params.errorMsg;
        }
        if (params.loading !== undefined) {
            this.loading = params.loading;
        }
    }
    updateStateVars(params: Login_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__username.purgeDependencyOnElmtId(rmElmtId);
        this.__password.purgeDependencyOnElmtId(rmElmtId);
        this.__errorMsg.purgeDependencyOnElmtId(rmElmtId);
        this.__loading.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__username.aboutToBeDeleted();
        this.__password.aboutToBeDeleted();
        this.__errorMsg.aboutToBeDeleted();
        this.__loading.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __username: ObservedPropertySimplePU<string>;
    get username() {
        return this.__username.get();
    }
    set username(newValue: string) {
        this.__username.set(newValue);
    }
    private __password: ObservedPropertySimplePU<string>;
    get password() {
        return this.__password.get();
    }
    set password(newValue: string) {
        this.__password.set(newValue);
    }
    private __errorMsg: ObservedPropertySimplePU<string>;
    get errorMsg() {
        return this.__errorMsg.get();
    }
    set errorMsg(newValue: string) {
        this.__errorMsg.set(newValue);
    }
    private __loading: ObservedPropertySimplePU<boolean>;
    get loading() {
        return this.__loading.get();
    }
    set loading(newValue: boolean) {
        this.__loading.set(newValue);
    }
    aboutToAppear(): void {
        // 已登录（如热重载/回退到本页）直接进入主界面
        AuthService.getInstance().isLoggedIn().then((logged: boolean) => {
            if (logged) {
                router.replaceUrl({ url: 'pages/Index' });
            }
        });
    }
    private async doLogin(): Promise<void> {
        if (this.loading) {
            return;
        }
        this.errorMsg = '';
        this.loading = true;
        const r = await AuthService.getInstance().login(this.username, this.password);
        if (!r.ok) {
            this.errorMsg = r.message;
            this.loading = false;
            return;
        }
        // 登录用户名写入用户昵称，App 全局生效
        await AppStore.getInstance().applyLoginUser(r.username);
        this.loading = false;
        router.replaceUrl({ url: 'pages/Index' });
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.padding(28);
            Column.justifyContent(FlexAlign.Center);
            Column.backgroundColor(Colors.BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 品牌区
            Column.create();
            // 品牌区
            Column.margin({ bottom: 36 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('iKnow');
            Text.fontSize(40);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('专注感知智能考伴');
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 8 });
        }, Text);
        Text.pop();
        // 品牌区
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 登录卡片
            Column.create();
            // 登录卡片
            Column.width('100%');
            // 登录卡片
            Column.padding(24);
            // 登录卡片
            Column.backgroundColor(Colors.CARD);
            // 登录卡片
            Column.borderRadius(Radius.LG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('登录 / 注册');
            Text.fontSize(18);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '用户名' });
            TextInput.fontSize(15);
            TextInput.height(48);
            TextInput.margin({ top: 18 });
            TextInput.backgroundColor(Colors.BG);
            TextInput.borderRadius(Radius.MD);
            TextInput.onChange((v: string) => {
                this.username = v;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '密码（至少 6 位）' });
            TextInput.type(InputType.Password);
            TextInput.fontSize(15);
            TextInput.height(48);
            TextInput.margin({ top: 12 });
            TextInput.backgroundColor(Colors.BG);
            TextInput.borderRadius(Radius.MD);
            TextInput.onChange((v: string) => {
                this.password = v;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.errorMsg.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.errorMsg);
                        Text.fontSize(13);
                        Text.fontColor(Colors.CAMERA_RED);
                        Text.width('100%');
                        Text.margin({ top: 10 });
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.loading ? '登录中…' : '登录');
            Button.width('100%');
            Button.height(50);
            Button.fontSize(16);
            Button.fontWeight(FontWeight.Medium);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.PRIMARY);
            Button.borderRadius(Radius.LG);
            Button.margin({ top: 20 });
            Button.enabled(!this.loading);
            Button.onClick(() => {
                this.doLogin();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('首次使用该用户名会自动创建本地账号');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.width('100%');
            Text.textAlign(TextAlign.Center);
            Text.margin({ top: 14 });
        }, Text);
        Text.pop();
        // 登录卡片
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('登录后，应用内的称呼将使用你的用户名');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.margin({ top: 20 });
        }, Text);
        Text.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Login";
    }
}
registerNamedRoute(() => new Login(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Login", pageFullPath: "entry/src/main/ets/pages/Login", integratedHsp: "false", moduleType: "followWithHap" });
