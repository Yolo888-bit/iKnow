if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Dashboard_Params {
    examDays?: number;
    nickname?: string;
    avatar?: string;
    todayDone?: number;
    todayTotal?: number;
    weekFocus?: number;
    focusRate?: number;
    dataVersion?: number;
    weekTrend?: number[];
    subjects?: SubjectProgress[];
    examType?: string;
    greeting?: string;
    showAvatarSheet?: boolean;
    weekLabels?: string[];
}
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
import { BarChart } from "@normalized:N&&&entry/src/main/ets/components/BarChart&";
import type { SubjectProgress } from '../models/Dashboard';
import { UserAvatar } from "@normalized:N&&&entry/src/main/ets/components/UserAvatar&";
import { AvatarPicker } from "@normalized:N&&&entry/src/main/ets/components/AvatarPicker&";
export class Dashboard extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__examDays = this.createStorageProp(StorageKey.EXAM_DAYS, 0, "examDays");
        this.__nickname = this.createStorageProp(StorageKey.USER_NICKNAME, '', "nickname");
        this.__avatar = this.createStorageProp(StorageKey.USER_AVATAR, '🧑‍🎓', "avatar");
        this.__todayDone = this.createStorageProp(StorageKey.TODAY_DONE_TASKS, 0, "todayDone");
        this.__todayTotal = this.createStorageProp(StorageKey.TODAY_TOTAL_TASKS, 0, "todayTotal");
        this.__weekFocus = this.createStorageProp(StorageKey.WEEK_FOCUS_SEC, 0, "weekFocus");
        this.__focusRate = this.createStorageProp(StorageKey.FOCUS_RATE, 0, "focusRate");
        this.__dataVersion = this.createStorageProp(StorageKey.DATA_VERSION, 0, "dataVersion");
        this.__weekTrend = new ObservedPropertyObjectPU([], this, "weekTrend");
        this.__subjects = new ObservedPropertyObjectPU([], this, "subjects");
        this.__examType = new ObservedPropertySimplePU('考研', this, "examType");
        this.__greeting = new ObservedPropertySimplePU('', this, "greeting");
        this.__showAvatarSheet = new ObservedPropertySimplePU(false, this, "showAvatarSheet");
        this.weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
        this.setInitiallyProvidedValue(params);
        this.declareWatch("dataVersion", this.refresh);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Dashboard_Params) {
        if (params.weekTrend !== undefined) {
            this.weekTrend = params.weekTrend;
        }
        if (params.subjects !== undefined) {
            this.subjects = params.subjects;
        }
        if (params.examType !== undefined) {
            this.examType = params.examType;
        }
        if (params.greeting !== undefined) {
            this.greeting = params.greeting;
        }
        if (params.showAvatarSheet !== undefined) {
            this.showAvatarSheet = params.showAvatarSheet;
        }
        if (params.weekLabels !== undefined) {
            this.weekLabels = params.weekLabels;
        }
    }
    updateStateVars(params: Dashboard_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__examDays.purgeDependencyOnElmtId(rmElmtId);
        this.__nickname.purgeDependencyOnElmtId(rmElmtId);
        this.__avatar.purgeDependencyOnElmtId(rmElmtId);
        this.__todayDone.purgeDependencyOnElmtId(rmElmtId);
        this.__todayTotal.purgeDependencyOnElmtId(rmElmtId);
        this.__weekFocus.purgeDependencyOnElmtId(rmElmtId);
        this.__focusRate.purgeDependencyOnElmtId(rmElmtId);
        this.__dataVersion.purgeDependencyOnElmtId(rmElmtId);
        this.__weekTrend.purgeDependencyOnElmtId(rmElmtId);
        this.__subjects.purgeDependencyOnElmtId(rmElmtId);
        this.__examType.purgeDependencyOnElmtId(rmElmtId);
        this.__greeting.purgeDependencyOnElmtId(rmElmtId);
        this.__showAvatarSheet.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__examDays.aboutToBeDeleted();
        this.__nickname.aboutToBeDeleted();
        this.__avatar.aboutToBeDeleted();
        this.__todayDone.aboutToBeDeleted();
        this.__todayTotal.aboutToBeDeleted();
        this.__weekFocus.aboutToBeDeleted();
        this.__focusRate.aboutToBeDeleted();
        this.__dataVersion.aboutToBeDeleted();
        this.__weekTrend.aboutToBeDeleted();
        this.__subjects.aboutToBeDeleted();
        this.__examType.aboutToBeDeleted();
        this.__greeting.aboutToBeDeleted();
        this.__showAvatarSheet.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __examDays: ObservedPropertyAbstractPU<number>;
    get examDays() {
        return this.__examDays.get();
    }
    set examDays(newValue: number) {
        this.__examDays.set(newValue);
    }
    private __nickname: ObservedPropertyAbstractPU<string>;
    get nickname() {
        return this.__nickname.get();
    }
    set nickname(newValue: string) {
        this.__nickname.set(newValue);
    }
    private __avatar: ObservedPropertyAbstractPU<string>;
    get avatar() {
        return this.__avatar.get();
    }
    set avatar(newValue: string) {
        this.__avatar.set(newValue);
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
    private __weekFocus: ObservedPropertyAbstractPU<number>;
    get weekFocus() {
        return this.__weekFocus.get();
    }
    set weekFocus(newValue: number) {
        this.__weekFocus.set(newValue);
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
    private __weekTrend: ObservedPropertyObjectPU<number[]>;
    get weekTrend() {
        return this.__weekTrend.get();
    }
    set weekTrend(newValue: number[]) {
        this.__weekTrend.set(newValue);
    }
    private __subjects: ObservedPropertyObjectPU<SubjectProgress[]>;
    get subjects() {
        return this.__subjects.get();
    }
    set subjects(newValue: SubjectProgress[]) {
        this.__subjects.set(newValue);
    }
    private __examType: ObservedPropertySimplePU<string>;
    get examType() {
        return this.__examType.get();
    }
    set examType(newValue: string) {
        this.__examType.set(newValue);
    }
    private __greeting: ObservedPropertySimplePU<string>;
    get greeting() {
        return this.__greeting.get();
    }
    set greeting(newValue: string) {
        this.__greeting.set(newValue);
    }
    private __showAvatarSheet: ObservedPropertySimplePU<boolean>;
    get showAvatarSheet() {
        return this.__showAvatarSheet.get();
    }
    set showAvatarSheet(newValue: boolean) {
        this.__showAvatarSheet.set(newValue);
    }
    private weekLabels: string[];
    aboutToAppear(): void {
        this.refresh();
    }
    /** 顶部问候语（按当前时间）+ 登录用户名 */
    private displayName(): string {
        const n = this.nickname.length > 0 ? this.nickname : AppStore.getInstance().getUser().nickname;
        return n.length > 0 ? n : '同学';
    }
    refresh(): void {
        this.greeting = TimeUtils.greeting(Date.now());
        const store = AppStore.getInstance();
        const d = store.getDashboard();
        this.weekTrend = d.weekTrend;
        this.subjects = d.subjectProgress;
        this.examType = store.getGoal().examType;
    }
    sectionTitle(title: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.margin({ bottom: 12 });
        }, Text);
        Text.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.TopStart });
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
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
            // 顶部问候（按当前时间生成 + 登录用户名）+ 右上角头像
            Row.create();
            // 顶部问候（按当前时间生成 + 登录用户名）+ 右上角头像
            Row.width('100%');
            // 顶部问候（按当前时间生成 + 登录用户名）+ 右上角头像
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.layoutWeight(1);
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.greeting}，${this.displayName()}`);
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今天也一起稳稳推进吧');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 6 });
            Text.width('100%');
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 右上角头像：点击即可更换
            Column.create();
            // 右上角头像：点击即可更换
            Column.onClick(() => {
                this.showAvatarSheet = true;
            });
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new UserAvatar(this, { avatar: this.avatar, diameter: 52, bg: Colors.PRIMARY_SOFT }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Dashboard.ets", line: 80, col: 13 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            avatar: this.avatar,
                            diameter: 52,
                            bg: Colors.PRIMARY_SOFT
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        avatar: this.avatar, diameter: 52, bg: Colors.PRIMARY_SOFT
                    });
                }
            }, { name: "UserAvatar" });
        }
        // 右上角头像：点击即可更换
        Column.pop();
        // 顶部问候（按当前时间生成 + 登录用户名）+ 右上角头像
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 考试总览
            Column.create();
            __Column__dashCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('考试总览');
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.examType);
            Text.fontSize(22);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.PRIMARY_DARK);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.examDays}`);
            Text.fontSize(34);
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
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`距离 ${this.examType} 还有 ${this.examDays} 天，按节奏稳步推进`);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.margin({ top: 10 });
            Text.width('100%');
        }, Text);
        Text.pop();
        // 考试总览
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 总体进度
            Column.create();
            __Column__dashCard();
        }, Column);
        this.sectionTitle.bind(this)('总体进度');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.margin({ bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.todayDone} / ${this.todayTotal}`);
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.todayTotal > 0 ? `${Math.round(this.todayDone / this.todayTotal * 100)}%` : '—');
            Text.fontSize(18);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.PRIMARY_DARK);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Progress.create({
                value: this.todayDone,
                total: Math.max(1, this.todayTotal),
                type: ProgressType.Linear
            });
            Progress.color(Colors.PRIMARY);
            Progress.backgroundColor(Colors.LINE);
            Progress.width('100%');
        }, Progress);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今日任务完成进度');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.margin({ top: 8 });
            Text.width('100%');
        }, Text);
        Text.pop();
        // 总体进度
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 科目进度
            Column.create();
            __Column__dashCard();
        }, Column);
        this.sectionTitle.bind(this)('科目进度');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.subjects.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('开始学习后，这里会显示各学科的完成进度');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.width('100%');
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const sp = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Column.create();
                                Column.width('100%');
                                Column.margin({ top: 14 });
                            }, Column);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Row.create();
                                Row.width('100%');
                            }, Row);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(sp.subject);
                                Text.fontSize(14);
                                Text.fontColor(Colors.TEXT_PRIMARY);
                            }, Text);
                            Text.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Blank.create();
                            }, Blank);
                            Blank.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(`${sp.percent}%`);
                                Text.fontSize(14);
                                Text.fontColor(Colors.PRIMARY_DARK);
                            }, Text);
                            Text.pop();
                            Row.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Progress.create({ value: sp.percent, total: 100, type: ProgressType.Linear });
                                Progress.color(Colors.PRIMARY);
                                Progress.backgroundColor(Colors.LINE);
                                Progress.width('100%');
                                Progress.margin({ top: 8 });
                            }, Progress);
                            Column.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.subjects, forEachItemGenFunction, (sp: SubjectProgress) => sp.subject, false, false);
                    }, ForEach);
                    ForEach.pop();
                });
            }
        }, If);
        If.pop();
        // 科目进度
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 长期趋势
            Column.create();
            __Column__dashCard();
        }, Column);
        this.sectionTitle.bind(this)('长期趋势');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('近 7 天净专注时长（分钟）');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.width('100%');
            Text.margin({ bottom: 10 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.width('100%');
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new BarChart(this, { values: this.weekTrend, labels: this.weekLabels }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Dashboard.ets", line: 198, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            values: this.weekTrend,
                            labels: this.weekLabels
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        values: this.weekTrend, labels: this.weekLabels
                    });
                }
            }, { name: "BarChart" });
        }
        __Common__.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`本周累计净专注 ${TimeUtils.formatHMin(this.weekFocus)}`);
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 10 });
            Text.width('100%');
        }, Text);
        Text.pop();
        // 长期趋势
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.height(20);
        }, Blank);
        Blank.pop();
        Column.pop();
        Scroll.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 头像选择器（右上角头像点击后弹出）
                    AvatarPicker(this, {
                        show: this.showAvatarSheet,
                        onClose: () => {
                            this.showAvatarSheet = false;
                        }
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Dashboard.ets", line: 218, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            show: this.showAvatarSheet,
                            onClose: () => {
                                this.showAvatarSheet = false;
                            }
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        show: this.showAvatarSheet
                    });
                }
            }, { name: "AvatarPicker" });
        }
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
function __Column__dashCard(): void {
    Column.width('100%');
    Column.padding(18);
    Column.backgroundColor(Colors.CARD);
    Column.borderRadius(Radius.LG);
    Column.alignItems(HorizontalAlign.Start);
}
