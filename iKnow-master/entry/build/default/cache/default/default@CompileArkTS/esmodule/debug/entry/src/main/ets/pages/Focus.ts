if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Focus_Params {
    elapsed?: number;
    net?: number;
    focusState?: string;
    taskTitle?: string;
    taskSubject?: string;
    showEndConfirm?: boolean;
    ending?: boolean;
}
import router from "@ohos:router";
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { FocusController } from "@normalized:N&&&entry/src/main/ets/services/FocusController&";
import { FocusDetectionService } from "@normalized:N&&&entry/src/main/ets/services/FocusDetectionService&";
import type { Task } from '../models/Task';
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
import { FocusStateUi } from "@normalized:N&&&entry/src/main/ets/common/FocusStateUi&";
import { FocusTimer } from "@normalized:N&&&entry/src/main/ets/components/FocusTimer&";
import { BreathingLight } from "@normalized:N&&&entry/src/main/ets/components/BreathingLight&";
import { AITag } from "@normalized:N&&&entry/src/main/ets/components/AITag&";
export class Focus extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__elapsed = this.createStorageProp(StorageKey.FOCUS_ELAPSED, 0, "elapsed");
        this.__net = this.createStorageProp(StorageKey.FOCUS_NET, 0, "net");
        this.__focusState = this.createStorageProp(StorageKey.FOCUS_STATE, 'FOCUSED', "focusState");
        this.__taskTitle = new ObservedPropertySimplePU('自由专注', this, "taskTitle");
        this.__taskSubject = new ObservedPropertySimplePU('无任务', this, "taskSubject");
        this.__showEndConfirm = new ObservedPropertySimplePU(false, this, "showEndConfirm");
        this.__ending = new ObservedPropertySimplePU(false, this, "ending");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Focus_Params) {
        if (params.taskTitle !== undefined) {
            this.taskTitle = params.taskTitle;
        }
        if (params.taskSubject !== undefined) {
            this.taskSubject = params.taskSubject;
        }
        if (params.showEndConfirm !== undefined) {
            this.showEndConfirm = params.showEndConfirm;
        }
        if (params.ending !== undefined) {
            this.ending = params.ending;
        }
    }
    updateStateVars(params: Focus_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__elapsed.purgeDependencyOnElmtId(rmElmtId);
        this.__net.purgeDependencyOnElmtId(rmElmtId);
        this.__focusState.purgeDependencyOnElmtId(rmElmtId);
        this.__taskTitle.purgeDependencyOnElmtId(rmElmtId);
        this.__taskSubject.purgeDependencyOnElmtId(rmElmtId);
        this.__showEndConfirm.purgeDependencyOnElmtId(rmElmtId);
        this.__ending.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__elapsed.aboutToBeDeleted();
        this.__net.aboutToBeDeleted();
        this.__focusState.aboutToBeDeleted();
        this.__taskTitle.aboutToBeDeleted();
        this.__taskSubject.aboutToBeDeleted();
        this.__showEndConfirm.aboutToBeDeleted();
        this.__ending.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __elapsed: ObservedPropertyAbstractPU<number>;
    get elapsed() {
        return this.__elapsed.get();
    }
    set elapsed(newValue: number) {
        this.__elapsed.set(newValue);
    }
    private __net: ObservedPropertyAbstractPU<number>;
    get net() {
        return this.__net.get();
    }
    set net(newValue: number) {
        this.__net.set(newValue);
    }
    private __focusState: ObservedPropertyAbstractPU<string>;
    get focusState() {
        return this.__focusState.get();
    }
    set focusState(newValue: string) {
        this.__focusState.set(newValue);
    }
    private __taskTitle: ObservedPropertySimplePU<string>;
    get taskTitle() {
        return this.__taskTitle.get();
    }
    set taskTitle(newValue: string) {
        this.__taskTitle.set(newValue);
    }
    private __taskSubject: ObservedPropertySimplePU<string>;
    get taskSubject() {
        return this.__taskSubject.get();
    }
    set taskSubject(newValue: string) {
        this.__taskSubject.set(newValue);
    }
    private __showEndConfirm: ObservedPropertySimplePU<boolean>;
    get showEndConfirm() {
        return this.__showEndConfirm.get();
    }
    set showEndConfirm(newValue: boolean) {
        this.__showEndConfirm.set(newValue);
    }
    private __ending: ObservedPropertySimplePU<boolean>;
    get ending() {
        return this.__ending.get();
    }
    set ending(newValue: boolean) {
        this.__ending.set(newValue);
    }
    aboutToAppear(): void {
        const controller = FocusController.getInstance();
        if (!controller.isRunning()) {
            controller.start(AppStore.getInstance().getCurrentPlan());
        }
        this.refreshTask();
    }
    private refreshTask(): void {
        const plan = AppStore.getInstance().getCurrentPlan();
        let cur: Task | null = null;
        for (const t of plan) {
            if (!t.done) {
                cur = t;
                break;
            }
        }
        if (cur === null && plan.length > 0) {
            cur = plan[0];
        }
        if (cur !== null) {
            this.taskTitle = cur.title;
            this.taskSubject = cur.subject;
        }
    }
    private togglePause(): void {
        const c = FocusController.getInstance();
        if (c.isPaused()) {
            c.resume();
        }
        else {
            c.pause();
        }
    }
    private rest(): void {
        FocusController.getInstance().startBreak();
        router.pushUrl({ url: 'pages/FocusBreak' });
    }
    private openQA(): void {
        FocusController.getInstance().startQA();
        router.pushUrl({ url: 'pages/AIChat' });
    }
    private continueFromRed(): void {
        FocusDetectionService.getInstance().resume();
    }
    private async endFlow(showReport: boolean): Promise<void> {
        if (this.ending) {
            return;
        }
        this.ending = true;
        await AppStore.getInstance().endSession();
        this.ending = false;
        if (showReport) {
            router.replaceUrl({ url: 'pages/StudyReport' });
        }
        else {
            router.back();
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.BottomEnd });
            Stack.width('100%');
            Stack.height('100%');
            Stack.backgroundColor(Colors.BG);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部合规栏：红色摄像头指示灯 + AI 智能体标签
            Row.create();
            // 顶部合规栏：红色摄像头指示灯 + AI 智能体标签
            Row.width('100%');
            // 顶部合规栏：红色摄像头指示灯 + AI 智能体标签
            Row.padding({ left: 20, right: 20, top: 14, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(8);
            Circle.height(8);
            Circle.fill(Colors.CAMERA_RED);
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('摄像头感知中');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ left: 6 });
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new AITag(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Focus.ets", line: 105, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {};
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {});
                }
            }, { name: "AITag" });
        }
        // 顶部合规栏：红色摄像头指示灯 + AI 智能体标签
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 主体
            Column.create();
            // 主体
            Column.width('100%');
            // 主体
            Column.padding({ left: 24, right: 24 });
            // 主体
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.taskSubject);
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.taskTitle);
            Text.fontSize(22);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('当前任务');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.margin({ top: 40 });
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new FocusTimer(this, { seconds: this.elapsed, big: true }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Focus.ets", line: 125, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            seconds: this.elapsed,
                            big: true
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        seconds: this.elapsed, big: true
                    });
                }
            }, { name: "FocusTimer" });
        }
        __Common__.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`已专注 ${TimeUtils.formatHMin(this.net)}`);
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.margin({ top: 48 });
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new BreathingLight(this, {
                        state: this.focusState,
                        onTap: () => {
                            FocusController.getInstance().demoCycleState();
                        }
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Focus.ets", line: 133, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            state: this.focusState,
                            onTap: () => {
                                FocusController.getInstance().demoCycleState();
                            }
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        state: this.focusState
                    });
                }
            }, { name: "BreathingLight" });
        }
        __Common__.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(FocusStateUi.label(this.focusState));
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ top: 24 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(FocusStateUi.subLabel(this.focusState));
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 红灯：AI 主动询问（给选择，不指责）
            if (this.focusState === 'DISTRACTED') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('86%');
                        Column.padding(16);
                        Column.backgroundColor(Colors.RED_SOFT);
                        Column.borderRadius(Radius.LG);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('注意到你离开有一会儿了。');
                        Text.fontSize(15);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.margin({ top: 24 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('需要休息一下，还是继续学习？');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 6 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.margin({ top: 16 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('继续学习');
                        Button.fontSize(13);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.height(38);
                        Button.borderRadius(19);
                        Button.onClick(() => {
                            this.continueFromRed();
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('休息一下');
                        Button.fontSize(13);
                        Button.fontColor(Colors.TEXT_PRIMARY);
                        Button.backgroundColor(Colors.CARD);
                        Button.height(38);
                        Button.borderRadius(19);
                        Button.onClick(() => {
                            this.rest();
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('结束本次专注');
                        Button.fontSize(13);
                        Button.fontColor(Colors.TEXT_SECONDARY);
                        Button.backgroundColor(Colors.CARD);
                        Button.height(38);
                        Button.borderRadius(19);
                        Button.onClick(() => {
                            this.showEndConfirm = true;
                        });
                    }, Button);
                    Button.pop();
                    Row.pop();
                    Column.pop();
                });
            }
            // 暂停：轻量恢复
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 暂停：轻量恢复
            if (this.focusState === 'PAUSED') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('86%');
                        Column.padding(16);
                        Column.backgroundColor(Colors.CARD);
                        Column.borderRadius(Radius.LG);
                        Column.margin({ top: 24 });
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('已暂停');
                        Text.fontSize(15);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('继续专注');
                        Button.fontSize(14);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.height(40);
                        Button.borderRadius(20);
                        Button.margin({ top: 12 });
                        Button.onClick(() => {
                            FocusController.getInstance().resume();
                        });
                    }, Button);
                    Button.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        // 主体
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 底部控制
            Row.create({ space: 12 });
            // 底部控制
            Row.width('100%');
            // 底部控制
            Row.padding({ left: 20, right: 20, bottom: 24, top: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.focusState === 'PAUSED' ? '继续' : '暂停');
            Button.layoutWeight(1);
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.CARD);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                this.togglePause();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('休息');
            Button.layoutWeight(1);
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.CARD);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                this.rest();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('结束');
            Button.layoutWeight(1);
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.PRIMARY_DARK);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                this.showEndConfirm = true;
            });
        }, Button);
        Button.pop();
        // 底部控制
        Row.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // AI 答疑悬浮按钮（右下角半透明）
            Button.createWithLabel('AI');
            // AI 答疑悬浮按钮（右下角半透明）
            Button.width(58);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.height(58);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.fontSize(18);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.fontWeight(FontWeight.Medium);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.fontColor(Color.White);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.backgroundColor(Colors.PRIMARY);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.opacity(0.92);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.borderRadius(29);
            // AI 答疑悬浮按钮（右下角半透明）
            Button.margin({ right: 20, bottom: 90 });
            // AI 答疑悬浮按钮（右下角半透明）
            Button.shadow({ radius: 12, color: Colors.SHADOW, offsetX: 0, offsetY: 4 });
            // AI 答疑悬浮按钮（右下角半透明）
            Button.onClick(() => {
                this.openQA();
            });
        }, Button);
        // AI 答疑悬浮按钮（右下角半透明）
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 结束确认（AI 语气，二次确认）
            if (this.showEndConfirm) {
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
                        Text.create('今天这一段辛苦了。');
                        Text.fontSize(17);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('专注结束，需要我帮你总结一下这次学习吗？');
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
                        Button.createWithLabel('直接结束');
                        Button.layoutWeight(1);
                        Button.height(44);
                        Button.fontSize(15);
                        Button.fontColor(Colors.TEXT_SECONDARY);
                        Button.backgroundColor(Colors.BG);
                        Button.borderRadius(Radius.MD);
                        Button.onClick(() => {
                            this.showEndConfirm = false;
                            this.endFlow(false);
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('生成复盘');
                        Button.layoutWeight(1);
                        Button.height(44);
                        Button.fontSize(15);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.borderRadius(Radius.MD);
                        Button.onClick(() => {
                            this.showEndConfirm = false;
                            this.endFlow(true);
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
        return "Focus";
    }
}
registerNamedRoute(() => new Focus(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Focus", pageFullPath: "entry/src/main/ets/pages/Focus", integratedHsp: "false", moduleType: "followWithHap" });
