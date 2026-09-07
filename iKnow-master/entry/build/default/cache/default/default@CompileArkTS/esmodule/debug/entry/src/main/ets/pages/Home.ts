if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Home_Params {
    nickname?: string;
    todayFocus?: number;
    focusRate?: number;
    dataVersion?: number;
    plan?: Task[];
    showProactive?: boolean;
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import type { Task } from '../models/Task';
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
import { TaskCard } from "@normalized:N&&&entry/src/main/ets/components/TaskCard&";
import { CircularProgress } from "@normalized:N&&&entry/src/main/ets/components/CircularProgress&";
export class Home extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__nickname = this.createStorageProp(StorageKey.USER_NICKNAME, '刘灿', "nickname");
        this.__todayFocus = this.createStorageProp(StorageKey.TODAY_FOCUS_SEC, 0, "todayFocus");
        this.__focusRate = this.createStorageProp(StorageKey.FOCUS_RATE, 0, "focusRate");
        this.__dataVersion = this.createStorageProp(StorageKey.DATA_VERSION, 0, "dataVersion");
        this.__plan = new ObservedPropertyObjectPU([], this, "plan");
        this.__showProactive = new ObservedPropertySimplePU(true, this, "showProactive");
        this.setInitiallyProvidedValue(params);
        this.declareWatch("dataVersion", this.refreshPlan);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Home_Params) {
        if (params.plan !== undefined) {
            this.plan = params.plan;
        }
        if (params.showProactive !== undefined) {
            this.showProactive = params.showProactive;
        }
    }
    updateStateVars(params: Home_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__nickname.purgeDependencyOnElmtId(rmElmtId);
        this.__todayFocus.purgeDependencyOnElmtId(rmElmtId);
        this.__focusRate.purgeDependencyOnElmtId(rmElmtId);
        this.__dataVersion.purgeDependencyOnElmtId(rmElmtId);
        this.__plan.purgeDependencyOnElmtId(rmElmtId);
        this.__showProactive.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__nickname.aboutToBeDeleted();
        this.__todayFocus.aboutToBeDeleted();
        this.__focusRate.aboutToBeDeleted();
        this.__dataVersion.aboutToBeDeleted();
        this.__plan.aboutToBeDeleted();
        this.__showProactive.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __nickname: ObservedPropertyAbstractPU<string>;
    get nickname() {
        return this.__nickname.get();
    }
    set nickname(newValue: string) {
        this.__nickname.set(newValue);
    }
    private __todayFocus: ObservedPropertyAbstractPU<number>;
    get todayFocus() {
        return this.__todayFocus.get();
    }
    set todayFocus(newValue: number) {
        this.__todayFocus.set(newValue);
    }
    private __focusRate: ObservedPropertyAbstractPU<number>;
    get focusRate() {
        return this.__focusRate.get();
    }
    set focusRate(newValue: number) {
        this.__focusRate.set(newValue);
    }
    private __dataVersion: ObservedPropertyAbstractPU<number>;
    get dataVersion() {
        return this.__dataVersion.get();
    }
    set dataVersion(newValue: number) {
        this.__dataVersion.set(newValue);
    }
    private __plan: ObservedPropertyObjectPU<Task[]>;
    get plan() {
        return this.__plan.get();
    }
    set plan(newValue: Task[]) {
        this.__plan.set(newValue);
    }
    private __showProactive: ObservedPropertySimplePU<boolean>;
    get showProactive() {
        return this.__showProactive.get();
    }
    set showProactive(newValue: boolean) {
        this.__showProactive.set(newValue);
    }
    aboutToAppear(): void {
        this.refreshPlan();
    }
    refreshPlan(): void {
        this.plan = AppStore.getInstance().getCurrentPlan();
    }
    private deltaText(): string {
        const trend = AppStore.getInstance().getDashboard().weekTrend;
        if (trend.length < 2) {
            return '新的一天，慢慢来';
        }
        const today = trend[trend.length - 1];
        const yest = trend[trend.length - 2];
        if (yest <= 0) {
            return '新的一天，慢慢来';
        }
        const d = Math.round((today - yest) / yest * 100);
        if (d > 0) {
            return `↑ 比昨天提升 ${d}%`;
        }
        if (d < 0) {
            return '比昨天稍少一点，没关系';
        }
        return '和昨天持平，很稳';
    }
    private startFocus(): void {
        if (this.plan.length === 0) {
            router.pushUrl({ url: 'pages/TaskPlanning' });
        }
        else {
            router.pushUrl({ url: 'pages/Focus' });
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.backgroundColor(Colors.BG);
            Scroll.width('100%');
            Scroll.height('100%');
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.LG });
            Column.padding(20);
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部问候
            Row.create();
            // 顶部问候
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${TimeUtils.greeting(Date.now())}，${this.nickname}`);
            Text.fontSize(26);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今天也一起慢慢进入状态吧');
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('🧑‍🎓');
            Text.fontSize(26);
            Text.width(48);
            Text.height(48);
            Text.textAlign(TextAlign.Center);
            Text.backgroundColor(Colors.CARD);
            Text.borderRadius(24);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(10);
            Circle.height(10);
            Circle.fill(Colors.CAMERA_RED);
            Circle.position({ x: 36, y: 2 });
        }, Circle);
        Stack.pop();
        // 顶部问候
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 今日专注数据
            Column.create();
            // 今日专注数据
            Column.width('100%');
            // 今日专注数据
            Column.backgroundColor(Colors.CARD);
            // 今日专注数据
            Column.borderRadius(Radius.LG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(20);
        }, Row);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new CircularProgress(this, { percent: this.focusRate, boxSize: 132, label: '净专注率' }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Home.ets", line: 95, col: 13 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            percent: this.focusRate,
                            boxSize: 132,
                            label: '净专注率'
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        percent: this.focusRate, boxSize: 132, label: '净专注率'
                    });
                }
            }, { name: "CircularProgress" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.margin({ left: 24 });
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今日已专注');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(TimeUtils.formatHMin(this.todayFocus));
            Text.fontSize(28);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.deltaText());
            Text.fontSize(12);
            Text.fontColor(Colors.PRIMARY_DARK);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        Column.pop();
        Row.pop();
        // 今日专注数据
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 当前学习任务
            Column.create();
            // 当前学习任务
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('当前学习任务');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.margin({ bottom: 12 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.plan.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('还没有今日计划，去规划一个吧');
                        Text.fontSize(14);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.width('100%');
                        Text.padding(20);
                        Text.backgroundColor(Colors.CARD);
                        Text.borderRadius(Radius.MD);
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const task = _item;
                            {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    if (isInitialRender) {
                                        let componentCall = new TaskCard(this, {
                                            title: task.title,
                                            subject: task.subject,
                                            minutes: task.estimatedDuration,
                                            done: task.done,
                                            showCheckbox: true,
                                            onToggle: () => {
                                                AppStore.getInstance().togglePlanTask(task.id);
                                                this.plan = AppStore.getInstance().getCurrentPlan();
                                            }
                                        }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Home.ets", line: 138, col: 15 });
                                        ViewPU.create(componentCall);
                                        let paramsLambda = () => {
                                            return {
                                                title: task.title,
                                                subject: task.subject,
                                                minutes: task.estimatedDuration,
                                                done: task.done,
                                                showCheckbox: true,
                                                onToggle: () => {
                                                    AppStore.getInstance().togglePlanTask(task.id);
                                                    this.plan = AppStore.getInstance().getCurrentPlan();
                                                }
                                            };
                                        };
                                        componentCall.paramsGenerator_ = paramsLambda;
                                    }
                                    else {
                                        this.updateStateVarsOfChildByElmtId(elmtId, {
                                            title: task.title,
                                            subject: task.subject,
                                            minutes: task.estimatedDuration,
                                            done: task.done,
                                            showCheckbox: true
                                        });
                                    }
                                }, { name: "TaskCard" });
                            }
                        };
                        this.forEachUpdateFunction(elmtId, this.plan.slice(0, 3), forEachItemGenFunction, (task: Task) => task.id, false, false);
                    }, ForEach);
                    ForEach.pop();
                });
            }
        }, If);
        If.pop();
        // 当前学习任务
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 主操作按钮
            Button.createWithLabel('开始专注');
            // 主操作按钮
            Button.width('100%');
            // 主操作按钮
            Button.height(52);
            // 主操作按钮
            Button.fontSize(17);
            // 主操作按钮
            Button.fontWeight(FontWeight.Medium);
            // 主操作按钮
            Button.fontColor(Color.White);
            // 主操作按钮
            Button.backgroundColor(Colors.PRIMARY);
            // 主操作按钮
            Button.borderRadius(Radius.LG);
            // 主操作按钮
            Button.onClick(() => {
                this.startFocus();
            });
        }, Button);
        // 主操作按钮
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // AI 主动建议
            if (this.showProactive) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.padding(16);
                        Column.backgroundColor(Colors.PRIMARY_SOFT);
                        Column.borderRadius(Radius.MD);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.width('100%');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('💡 小伴发现');
                        Text.fontSize(13);
                        Text.fontColor(Colors.PRIMARY_DARK);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                    }, Blank);
                    Blank.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('稍后');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_TERTIARY);
                        Text.onClick(() => {
                            this.showProactive = false;
                        });
                    }, Text);
                    Text.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(AIService.getInstance().proactive(AppStore.getInstance().getProfile().bestFocusTime));
                        Text.fontSize(15);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.lineHeight(22);
                        Text.margin({ top: 10 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.margin({ top: 12 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('开始');
                        Button.fontSize(14);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.height(36);
                        Button.borderRadius(18);
                        Button.onClick(() => {
                            this.showProactive = false;
                            router.pushUrl({ url: 'pages/TaskPlanning' });
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('稍后');
                        Button.fontSize(14);
                        Button.fontColor(Colors.TEXT_SECONDARY);
                        Button.backgroundColor(Colors.CARD);
                        Button.height(36);
                        Button.borderRadius(18);
                        Button.margin({ left: 12 });
                        Button.onClick(() => {
                            this.showProactive = false;
                        });
                    }, Button);
                    Button.pop();
                    Row.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.height(20);
        }, Blank);
        Blank.pop();
        Column.pop();
        Scroll.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
