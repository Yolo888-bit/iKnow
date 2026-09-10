if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Privacy_Params {
    allowCamera?: boolean;
    allowMic?: boolean;
    allowHealth?: boolean;
    showClearConfirm?: boolean;
}
import promptAction from "@ohos:promptAction";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
export class Privacy extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__allowCamera = new ObservedPropertySimplePU(true, this, "allowCamera");
        this.__allowMic = new ObservedPropertySimplePU(true, this, "allowMic");
        this.__allowHealth = new ObservedPropertySimplePU(false, this, "allowHealth");
        this.__showClearConfirm = new ObservedPropertySimplePU(false, this, "showClearConfirm");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Privacy_Params) {
        if (params.allowCamera !== undefined) {
            this.allowCamera = params.allowCamera;
        }
        if (params.allowMic !== undefined) {
            this.allowMic = params.allowMic;
        }
        if (params.allowHealth !== undefined) {
            this.allowHealth = params.allowHealth;
        }
        if (params.showClearConfirm !== undefined) {
            this.showClearConfirm = params.showClearConfirm;
        }
    }
    updateStateVars(params: Privacy_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__allowCamera.purgeDependencyOnElmtId(rmElmtId);
        this.__allowMic.purgeDependencyOnElmtId(rmElmtId);
        this.__allowHealth.purgeDependencyOnElmtId(rmElmtId);
        this.__showClearConfirm.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__allowCamera.aboutToBeDeleted();
        this.__allowMic.aboutToBeDeleted();
        this.__allowHealth.aboutToBeDeleted();
        this.__showClearConfirm.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __allowCamera: ObservedPropertySimplePU<boolean>;
    get allowCamera() {
        return this.__allowCamera.get();
    }
    set allowCamera(newValue: boolean) {
        this.__allowCamera.set(newValue);
    }
    private __allowMic: ObservedPropertySimplePU<boolean>;
    get allowMic() {
        return this.__allowMic.get();
    }
    set allowMic(newValue: boolean) {
        this.__allowMic.set(newValue);
    }
    private __allowHealth: ObservedPropertySimplePU<boolean>;
    get allowHealth() {
        return this.__allowHealth.get();
    }
    set allowHealth(newValue: boolean) {
        this.__allowHealth.set(newValue);
    }
    private __showClearConfirm: ObservedPropertySimplePU<boolean>;
    get showClearConfirm() {
        return this.__showClearConfirm.get();
    }
    set showClearConfirm(newValue: boolean) {
        this.__showClearConfirm.set(newValue);
    }
    private doClearAll(): void {
        this.showClearConfirm = false;
        AppStore.getInstance().clearAll().then(() => {
            promptAction.showToast({ message: '✓ 数据已彻底销毁' });
        });
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width('100%');
            Stack.height('100%');
            Stack.backgroundColor(Colors.BG);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.width('100%');
            Scroll.height('100%');
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.LG });
            Column.padding(20);
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('隐私与数据');
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 摄像头数据
            Column.create();
            __Column__privacyCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('摄像头数据');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('仅用于实时分析专注状态');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.width('100%');
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('✓ 本地分析\n✓ 不上传\n✓ 不保存原始视频');
            Text.fontSize(13);
            Text.fontColor(Colors.GREEN);
            Text.lineHeight(22);
            Text.width('100%');
            Text.margin({ top: 10 });
        }, Text);
        Text.pop();
        // 摄像头数据
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 生理数据（分项授权，不支持一键全部授权）
            Column.create();
            __Column__privacyCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('生理数据 · 分项授权');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.margin({ bottom: 8 });
        }, Text);
        Text.pop();
        this.authRow.bind(this)('允许摄像头', this.allowCamera, (v: boolean) => {
            this.allowCamera = v;
        });
        this.authRow.bind(this)('允许麦克风', this.allowMic, (v: boolean) => {
            this.allowMic = v;
        });
        this.authRow.bind(this)('允许健康数据', this.allowHealth, (v: boolean) => {
            this.allowHealth = v;
        });
        // 生理数据（分项授权，不支持一键全部授权）
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 数据管理
            Column.create();
            __Column__privacyCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('数据管理');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('清除学习数据');
            Button.width('100%');
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.CARD);
            Button.borderRadius(Radius.MD);
            Button.margin({ top: 12 });
            Button.onClick(() => {
                AppStore.getInstance().clearLearningData().then(() => {
                    promptAction.showToast({ message: '学习数据已清除' });
                });
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('清除生理数据');
            Button.width('100%');
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.CARD);
            Button.borderRadius(Radius.MD);
            Button.margin({ top: 10 });
            Button.onClick(() => {
                AppStore.getInstance().clearPhysioData().then(() => {
                    promptAction.showToast({ message: '当前为模拟模式，无持久化生理数据' });
                });
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('清除全部数据');
            Button.width('100%');
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.CAMERA_RED);
            Button.borderRadius(Radius.MD);
            Button.margin({ top: 10 });
            Button.onClick(() => {
                this.showClearConfirm = true;
            });
        }, Button);
        Button.pop();
        // 数据管理
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.height(20);
        }, Blank);
        Blank.pop();
        Column.pop();
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 二次确认弹窗
            if (this.showClearConfirm) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.height('100%');
                        Column.backgroundColor('#66000000');
                        Column.justifyContent(FlexAlign.Center);
                        Column.alignItems(HorizontalAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('82%');
                        Column.padding(24);
                        Column.backgroundColor(Colors.CARD);
                        Column.borderRadius(Radius.LG);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('确定清除所有学习记录和生理数据吗？');
                        Text.fontSize(17);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('该操作不可恢复。');
                        Text.fontSize(14);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 8 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 12 });
                        Row.margin({ top: 20 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('取消');
                        Button.layoutWeight(1);
                        Button.height(44);
                        Button.fontSize(15);
                        Button.fontColor(Colors.TEXT_SECONDARY);
                        Button.backgroundColor(Colors.BG);
                        Button.borderRadius(Radius.MD);
                        Button.onClick(() => {
                            this.showClearConfirm = false;
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('确认清除');
                        Button.layoutWeight(1);
                        Button.height(44);
                        Button.fontSize(15);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.CAMERA_RED);
                        Button.borderRadius(Radius.MD);
                        Button.onClick(() => {
                            this.doClearAll();
                        });
                    }, Button);
                    Button.pop();
                    Row.pop();
                    Column.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Stack.pop();
    }
    authRow(label: string, value: boolean, onChange: (v: boolean) => void, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ top: 10, bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.layoutWeight(1);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Toggle.create({ type: ToggleType.Switch, isOn: value });
            Toggle.selectedColor(Colors.PRIMARY);
            Toggle.onChange((v: boolean) => {
                onChange(v);
            });
        }, Toggle);
        Toggle.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Privacy";
    }
}
function __Column__privacyCard(): void {
    Column.width('100%');
    Column.padding(18);
    Column.backgroundColor(Colors.CARD);
    Column.borderRadius(Radius.LG);
    Column.alignItems(HorizontalAlign.Start);
}
registerNamedRoute(() => new Privacy(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Privacy", pageFullPath: "entry/src/main/ets/pages/Privacy", integratedHsp: "false", moduleType: "followWithHap" });
