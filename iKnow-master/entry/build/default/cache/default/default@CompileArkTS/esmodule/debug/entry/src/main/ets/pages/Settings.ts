if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Settings_Params {
    personality?: AIPersonality;
    showClearConfirm?: boolean;
    personas?: PersonaOption[];
}
import promptAction from "@ohos:promptAction";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AIPersonality } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
interface PersonaOption {
    key: AIPersonality;
    label: string;
    desc: string;
}
export class Settings extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__personality = new ObservedPropertySimplePU(AIPersonality.GENTLE, this, "personality");
        this.__showClearConfirm = new ObservedPropertySimplePU(false, this, "showClearConfirm");
        this.personas = [
            { key: AIPersonality.STRICT, label: '严格教练型', desc: '直接 · 高执行力' },
            { key: AIPersonality.GENTLE, label: '温和陪伴型', desc: '鼓励 · 低压力' },
            { key: AIPersonality.QUIET, label: '极简安静型', desc: '不主动说话 · 轻量反馈' },
            { key: AIPersonality.ADAPTIVE, label: '智能适配', desc: '根据数据自动调整' }
        ];
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Settings_Params) {
        if (params.personality !== undefined) {
            this.personality = params.personality;
        }
        if (params.showClearConfirm !== undefined) {
            this.showClearConfirm = params.showClearConfirm;
        }
        if (params.personas !== undefined) {
            this.personas = params.personas;
        }
    }
    updateStateVars(params: Settings_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__personality.purgeDependencyOnElmtId(rmElmtId);
        this.__showClearConfirm.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__personality.aboutToBeDeleted();
        this.__showClearConfirm.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __personality: ObservedPropertySimplePU<AIPersonality>;
    get personality() {
        return this.__personality.get();
    }
    set personality(newValue: AIPersonality) {
        this.__personality.set(newValue);
    }
    private __showClearConfirm: ObservedPropertySimplePU<boolean>;
    get showClearConfirm() {
        return this.__showClearConfirm.get();
    }
    set showClearConfirm(newValue: boolean) {
        this.__showClearConfirm.set(newValue);
    }
    private personas: PersonaOption[];
    aboutToAppear(): void {
        this.personality = AppStore.getInstance().getUser().aiPersonality;
    }
    private selectPersona(key: AIPersonality): void {
        this.personality = key;
        AppStore.getInstance().saveUserPersonality(key);
        promptAction.showToast({ message: '已切换考伴人格' });
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
            Text.create('设置');
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // AI 考伴人格
            Column.create();
            __Column__settingCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 考伴人格');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.margin({ bottom: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const p = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.width('100%');
                    Row.padding({ top: 14, bottom: 14 });
                    Row.border({
                        width: { bottom: p.key === AIPersonality.ADAPTIVE ? 0 : 0.5 },
                        color: Colors.LINE
                    });
                    Row.onClick(() => {
                        this.selectPersona(p.key);
                    });
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.alignItems(HorizontalAlign.Start);
                    Column.layoutWeight(1);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(p.label);
                    Text.fontSize(15);
                    Text.fontColor(Colors.TEXT_PRIMARY);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(p.desc);
                    Text.fontSize(12);
                    Text.fontColor(Colors.TEXT_SECONDARY);
                    Text.margin({ top: 2 });
                }, Text);
                Text.pop();
                Column.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (this.personality === p.key) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('✓');
                                Text.fontSize(18);
                                Text.fontColor(Colors.PRIMARY);
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
                Row.pop();
            };
            this.forEachUpdateFunction(elmtId, this.personas, forEachItemGenFunction, (p: PersonaOption) => p.label, false, false);
        }, ForEach);
        ForEach.pop();
        // AI 考伴人格
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 数据清除（合规必备：一键清除 + 二次确认）
            Column.create();
            __Column__settingCard();
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
            Text.create('清除后所有学习记录与画像将不可恢复。');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.width('100%');
            Text.margin({ top: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('一键清除所有本地数据');
            Button.width('100%');
            Button.height(48);
            Button.fontSize(15);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.CAMERA_RED);
            Button.borderRadius(Radius.MD);
            Button.margin({ top: 16 });
            Button.onClick(() => {
                this.showClearConfirm = true;
            });
        }, Button);
        Button.pop();
        // 数据清除（合规必备：一键清除 + 二次确认）
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('iKnow · 专注感知智能考伴 v1.0.0');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.width('100%');
            Text.textAlign(TextAlign.Center);
            Text.margin({ top: 8 });
        }, Text);
        Text.pop();
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
                        Text.create('确定清除所有本地数据吗？');
                        Text.fontSize(17);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('将删除所有学习记录和生理数据。该操作不可恢复。');
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
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Settings";
    }
}
function __Column__settingCard(): void {
    Column.width('100%');
    Column.padding(18);
    Column.backgroundColor(Colors.CARD);
    Column.borderRadius(Radius.LG);
    Column.alignItems(HorizontalAlign.Start);
}
registerNamedRoute(() => new Settings(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Settings", pageFullPath: "entry/src/main/ets/pages/Settings", integratedHsp: "false", moduleType: "followWithHap" });
