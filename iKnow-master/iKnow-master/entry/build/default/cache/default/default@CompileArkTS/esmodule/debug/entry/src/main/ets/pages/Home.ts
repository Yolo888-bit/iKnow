if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Home_Params {
    nickname?: string;
    examDays?: number;
    todayFocus?: number;
    focusRate?: number;
    todayDone?: number;
    todayTotal?: number;
    dataVersion?: number;
    goalTitle?: string;
    examType?: string;
    completionRate?: number;
    plan?: Task[];
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { PermissionService } from "@normalized:N&&&entry/src/main/ets/services/PermissionService&";
import type { Task } from '../models/Task';
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
import { TaskCard } from "@normalized:N&&&entry/src/main/ets/components/TaskCard&";
export class Home extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__nickname = this.createStorageProp(StorageKey.USER_NICKNAME, '刘灿', "nickname");
        this.__examDays = this.createStorageProp(StorageKey.EXAM_DAYS, 0, "examDays");
        this.__todayFocus = this.createStorageProp(StorageKey.TODAY_FOCUS_SEC, 0, "todayFocus");
        this.__focusRate = this.createStorageProp(StorageKey.FOCUS_RATE, 0, "focusRate");
        this.__todayDone = this.createStorageProp(StorageKey.TODAY_DONE_TASKS, 0, "todayDone");
        this.__todayTotal = this.createStorageProp(StorageKey.TODAY_TOTAL_TASKS, 0, "todayTotal");
        this.__dataVersion = this.createStorageProp(StorageKey.DATA_VERSION, 0, "dataVersion");
        this.__goalTitle = new ObservedPropertySimplePU('考研上岸', this, "goalTitle");
        this.__examType = new ObservedPropertySimplePU('考研', this, "examType");
        this.__completionRate = new ObservedPropertySimplePU(0, this, "completionRate");
        this.__plan = new ObservedPropertyObjectPU([], this, "plan");
        this.setInitiallyProvidedValue(params);
        this.declareWatch("dataVersion", this.refreshPlan);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Home_Params) {
        if (params.goalTitle !== undefined) {
            this.goalTitle = params.goalTitle;
        }
        if (params.examType !== undefined) {
            this.examType = params.examType;
        }
        if (params.completionRate !== undefined) {
            this.completionRate = params.completionRate;
        }
        if (params.plan !== undefined) {
            this.plan = params.plan;
        }
    }
    updateStateVars(params: Home_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__nickname.purgeDependencyOnElmtId(rmElmtId);
        this.__examDays.purgeDependencyOnElmtId(rmElmtId);
        this.__todayFocus.purgeDependencyOnElmtId(rmElmtId);
        this.__focusRate.purgeDependencyOnElmtId(rmElmtId);
        this.__todayDone.purgeDependencyOnElmtId(rmElmtId);
        this.__todayTotal.purgeDependencyOnElmtId(rmElmtId);
        this.__dataVersion.purgeDependencyOnElmtId(rmElmtId);
        this.__goalTitle.purgeDependencyOnElmtId(rmElmtId);
        this.__examType.purgeDependencyOnElmtId(rmElmtId);
        this.__completionRate.purgeDependencyOnElmtId(rmElmtId);
        this.__plan.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__nickname.aboutToBeDeleted();
        this.__examDays.aboutToBeDeleted();
        this.__todayFocus.aboutToBeDeleted();
        this.__focusRate.aboutToBeDeleted();
        this.__todayDone.aboutToBeDeleted();
        this.__todayTotal.aboutToBeDeleted();
        this.__dataVersion.aboutToBeDeleted();
        this.__goalTitle.aboutToBeDeleted();
        this.__examType.aboutToBeDeleted();
        this.__completionRate.aboutToBeDeleted();
        this.__plan.aboutToBeDeleted();
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
    private __examDays: ObservedPropertyAbstractPU<number>;
    get examDays() {
        return this.__examDays.get();
    }
    set examDays(newValue: number) {
        this.__examDays.set(newValue);
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
    private __todayDone: ObservedPropertyAbstractPU<number>;
    get todayDone() {
        return this.__todayDone.get();
    }
    set todayDone(newValue: number) {
        this.__todayDone.set(newValue);
    }
    private __todayTotal: ObservedPropertyAbstractPU<number>;
    get todayTotal() {
        return this.__todayTotal.get();
    }
    set todayTotal(newValue: number) {
        this.__todayTotal.set(newValue);
    }
    private __dataVersion: ObservedPropertyAbstractPU<number>;
    get dataVersion() {
        return this.__dataVersion.get();
    }
    set dataVersion(newValue: number) {
        this.__dataVersion.set(newValue);
    }
    private __goalTitle: ObservedPropertySimplePU<string>;
    get goalTitle() {
        return this.__goalTitle.get();
    }
    set goalTitle(newValue: string) {
        this.__goalTitle.set(newValue);
    }
    private __examType: ObservedPropertySimplePU<string>;
    get examType() {
        return this.__examType.get();
    }
    set examType(newValue: string) {
        this.__examType.set(newValue);
    }
    private __completionRate: ObservedPropertySimplePU<number>;
    get completionRate() {
        return this.__completionRate.get();
    }
    set completionRate(newValue: number) {
        this.__completionRate.set(newValue);
    }
    private __plan: ObservedPropertyObjectPU<Task[]>;
    get plan() {
        return this.__plan.get();
    }
    set plan(newValue: Task[]) {
        this.__plan.set(newValue);
    }
    aboutToAppear(): void {
        this.refreshPlan();
    }
    refreshPlan(): void {
        this.plan = AppStore.getInstance().getCurrentPlan();
        const goal = AppStore.getInstance().getGoal();
        this.goalTitle = goal.title;
        this.examType = goal.examType;
        this.completionRate = this.todayTotal > 0 ? Math.round(this.todayDone / this.todayTotal * 100) : 0;
    }
    private startFocus(): void {
        if (this.plan.length === 0) {
            router.pushUrl({ url: 'pages/TaskPlanning' });
            return;
        }
        // 摄像头感知授权前置：已授权直接使用；未授权弹出选择，拒绝则降级仅计时模式
        if (PermissionService.getInstance().isCameraOn()) {
            router.pushUrl({ url: 'pages/Focus' });
            return;
        }
        AlertDialog.show({
            title: '开启摄像头感知？',
            message: '开启后，我会用前置摄像头在本地感知你的专注状态，全程不出端、不上传。你也可以选择仅计时模式。',
            primaryButton: {
                value: '开启感知',
                action: () => {
                    PermissionService.getInstance().grant('camera');
                    router.pushUrl({ url: 'pages/Focus' });
                }
            },
            secondaryButton: {
                value: '仅计时开始',
                action: () => {
                    router.pushUrl({ url: 'pages/Focus' });
                }
            }
        });
    }
    statTile(value: string, label: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.layoutWeight(1);
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.fontSize(22);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        Column.pop();
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
            // 今日目标（点击进入目标编辑 / 规划）
            Column.create();
            // 今日目标（点击进入目标编辑 / 规划）
            Column.width('100%');
            // 今日目标（点击进入目标编辑 / 规划）
            Column.padding(20);
            // 今日目标（点击进入目标编辑 / 规划）
            Column.backgroundColor(Colors.CARD);
            // 今日目标（点击进入目标编辑 / 规划）
            Column.borderRadius(Radius.LG);
            // 今日目标（点击进入目标编辑 / 规划）
            Column.onClick(() => {
                router.pushUrl({ url: 'pages/TaskPlanning' });
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今日目标');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('编辑 ›');
            Text.fontSize(13);
            Text.fontColor(Colors.PRIMARY_DARK);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 16 });
            Row.width('100%');
            Row.margin({ top: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.examType);
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.PRIMARY_DARK);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.goalTitle);
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.examDays}`);
            Text.fontSize(28);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('天');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        Column.pop();
        Row.pop();
        // 今日目标（点击进入目标编辑 / 规划）
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 今日任务
            Column.create();
            // 今日任务
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.margin({ bottom: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今日任务');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.plan.length === 0 ? '待规划' : this.plan.length + ' 项'}`);
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.plan.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.padding(20);
                        Column.backgroundColor(Colors.CARD);
                        Column.borderRadius(Radius.MD);
                        Column.onClick(() => {
                            router.pushUrl({ url: 'pages/TaskPlanning' });
                        });
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('还没有今日计划');
                        Text.fontSize(15);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('点这里，让小伴帮你规划今天');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 6 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: Spacing.SM });
                        Column.width('100%');
                    }, Column);
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
                                        }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Home.ets", line: 202, col: 17 });
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
                        this.forEachUpdateFunction(elmtId, this.plan, forEachItemGenFunction, (task: Task) => task.id, false, false);
                    }, ForEach);
                    ForEach.pop();
                    Column.pop();
                });
            }
        }, If);
        If.pop();
        // 今日任务
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 今日数据
            Column.create();
            // 今日数据
            Column.width('100%');
            // 今日数据
            Column.padding(20);
            // 今日数据
            Column.backgroundColor(Colors.CARD);
            // 今日数据
            Column.borderRadius(Radius.LG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今日数据');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.margin({ bottom: 14 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.width('100%');
        }, Row);
        this.statTile.bind(this)(`${this.focusRate}%`, '净专注率');
        this.statTile.bind(this)(TimeUtils.formatHMin(this.todayFocus), '今日专注时长');
        this.statTile.bind(this)(`${this.completionRate}%`, '任务完成率');
        Row.pop();
        // 今日数据
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
