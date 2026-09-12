if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    currentTab?: number;
    showRecover?: boolean;
    recoverSnap?: SessionSnapshot | null;
    controller?: TabsController;
}
import router from "@ohos:router";
import { Dashboard } from "@normalized:N&&&entry/src/main/ets/pages/Dashboard&";
import { TaskPlanning } from "@normalized:N&&&entry/src/main/ets/pages/TaskPlanning&";
import { Review } from "@normalized:N&&&entry/src/main/ets/pages/Review&";
import { Mine } from "@normalized:N&&&entry/src/main/ets/pages/Mine&";
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { StorageService } from "@normalized:N&&&entry/src/main/ets/services/StorageService&";
import { FocusController } from "@normalized:N&&&entry/src/main/ets/services/FocusController&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import type { SessionSnapshot } from '../models/SessionSnapshot';
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__currentTab = new ObservedPropertySimplePU(0, this, "currentTab");
        this.__showRecover = new ObservedPropertySimplePU(false, this, "showRecover");
        this.__recoverSnap = new ObservedPropertyObjectPU(null, this, "recoverSnap");
        this.controller = new TabsController();
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.currentTab !== undefined) {
            this.currentTab = params.currentTab;
        }
        if (params.showRecover !== undefined) {
            this.showRecover = params.showRecover;
        }
        if (params.recoverSnap !== undefined) {
            this.recoverSnap = params.recoverSnap;
        }
        if (params.controller !== undefined) {
            this.controller = params.controller;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__currentTab.purgeDependencyOnElmtId(rmElmtId);
        this.__showRecover.purgeDependencyOnElmtId(rmElmtId);
        this.__recoverSnap.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__currentTab.aboutToBeDeleted();
        this.__showRecover.aboutToBeDeleted();
        this.__recoverSnap.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __currentTab: ObservedPropertySimplePU<number>;
    get currentTab() {
        return this.__currentTab.get();
    }
    set currentTab(newValue: number) {
        this.__currentTab.set(newValue);
    }
    private __showRecover: ObservedPropertySimplePU<boolean>;
    get showRecover() {
        return this.__showRecover.get();
    }
    set showRecover(newValue: boolean) {
        this.__showRecover.set(newValue);
    }
    private __recoverSnap: ObservedPropertyObjectPU<SessionSnapshot | null>;
    get recoverSnap() {
        return this.__recoverSnap.get();
    }
    set recoverSnap(newValue: SessionSnapshot | null) {
        this.__recoverSnap.set(newValue);
    }
    private controller: TabsController;
    aboutToAppear(): void {
        this.checkRecovery();
    }
    /** 硬规则 §7：启动检查是否有被中断（崩溃/被杀）的会话，弹"继续/结束/放弃" */
    private async checkRecovery(): Promise<void> {
        try {
            const id = await StorageService.getInstance().loadKv(StorageKey.ACTIVE_SESSION_ID);
            if (id.length === 0) {
                return;
            }
            const snap = await StorageService.getInstance().loadLatestSnapshot(id);
            if (snap === null) {
                return;
            }
            // 仅当最近快照在 30 分钟内，才视为"被中断的会话"
            if (Date.now() - snap.ts > 30 * 60 * 1000) {
                return;
            }
            this.recoverSnap = snap;
            this.showRecover = true;
        }
        catch (e) {
            // 恢复检查失败不影响正常使用
        }
    }
    tabBar(title: string, index: number, icon: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.justifyContent(FlexAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(icon);
            Text.fontSize(20);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(11);
            Text.margin({ top: 2 });
            Text.fontColor(this.currentTab === index ? Colors.PRIMARY : Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        Column.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width('100%');
            Stack.height('100%');
            Stack.backgroundColor(Colors.BG);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Tabs.create({ barPosition: BarPosition.End, controller: this.controller });
            Tabs.scrollable(false);
            Tabs.barHeight(60);
            Tabs.backgroundColor(Colors.BG);
            Tabs.onChange((index: number) => {
                this.currentTab = index;
            });
        }, Tabs);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Dashboard(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 66, col: 11 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Dashboard" });
                }
            });
            TabContent.tabBar({ builder: () => {
                    this.tabBar.call(this, '工作台', 0, '📊');
                } });
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new TaskPlanning(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 70, col: 11 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "TaskPlanning" });
                }
            });
            TabContent.tabBar({ builder: () => {
                    this.tabBar.call(this, 'AI 规划', 1, '🤖');
                } });
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Review(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 74, col: 11 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Review" });
                }
            });
            TabContent.tabBar({ builder: () => {
                    this.tabBar.call(this, '复盘', 2, '📈');
                } });
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new Mine(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 78, col: 11 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "Mine" });
                }
            });
            TabContent.tabBar({ builder: () => {
                    this.tabBar.call(this, '我的', 3, '👤');
                } });
        }, TabContent);
        TabContent.pop();
        Tabs.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 中断恢复弹窗（覆盖层，不影响 Tabs 布局）
            if (this.showRecover && this.recoverSnap !== null) {
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
                        Text.create('发现未结束的专注');
                        Text.fontSize(17);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('上次专注似乎被打断了，要接着继续，还是结束它？');
                        Text.fontSize(14);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 8 });
                        Text.width('100%');
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.margin({ top: 20 });
                        Row.width('100%');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('放弃');
                        Button.layoutWeight(1);
                        Button.height(44);
                        Button.fontSize(14);
                        Button.fontColor(Colors.TEXT_SECONDARY);
                        Button.backgroundColor(Colors.BG);
                        Button.borderRadius(Radius.MD);
                        Button.onClick(() => {
                            StorageService.getInstance().saveKv(StorageKey.ACTIVE_SESSION_ID, '').catch(() => { });
                            if (this.recoverSnap !== null) {
                                StorageService.getInstance().deleteSnapshots(this.recoverSnap.sessionId).catch(() => { });
                            }
                            this.showRecover = false;
                            this.recoverSnap = null;
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('结束本次');
                        Button.layoutWeight(1);
                        Button.height(44);
                        Button.fontSize(14);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY_DARK);
                        Button.borderRadius(Radius.MD);
                        Button.onClick(() => {
                            if (this.recoverSnap !== null) {
                                FocusController.getInstance().restore(ObservedObject.GetRawObject(this.recoverSnap));
                                AppStore.getInstance().endSession()
                                    .then(() => {
                                    this.showRecover = false;
                                    this.recoverSnap = null;
                                })
                                    .catch(() => {
                                    this.showRecover = false;
                                    this.recoverSnap = null;
                                });
                            }
                            else {
                                this.showRecover = false;
                            }
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('继续专注');
                        Button.layoutWeight(1);
                        Button.height(44);
                        Button.fontSize(14);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.borderRadius(Radius.MD);
                        Button.onClick(() => {
                            if (this.recoverSnap !== null) {
                                FocusController.getInstance().restore(ObservedObject.GetRawObject(this.recoverSnap));
                            }
                            this.showRecover = false;
                            this.recoverSnap = null;
                            router.pushUrl({ url: 'pages/Focus' });
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
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
