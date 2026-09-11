if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Dashboard_Params {
    examDays?: number;
    todayDone?: number;
    todayTotal?: number;
    weekFocus?: number;
    focusRate?: number;
    dataVersion?: number;
    weekTrend?: number[];
    subjects?: SubjectProgress[];
    examType?: string;
    hardestSubject?: string;
    aiInsight?: string;
    weekLabels?: string[];
}
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { BarChart } from "@normalized:N&&&entry/src/main/ets/components/BarChart&";
import type { SubjectProgress } from '../models/Dashboard';
import { AITag } from "@normalized:N&&&entry/src/main/ets/components/AITag&";
export class Dashboard extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__examDays = this.createStorageProp(StorageKey.EXAM_DAYS, 0, "examDays");
        this.__todayDone = this.createStorageProp(StorageKey.TODAY_DONE_TASKS, 0, "todayDone");
        this.__todayTotal = this.createStorageProp(StorageKey.TODAY_TOTAL_TASKS, 0, "todayTotal");
        this.__weekFocus = this.createStorageProp(StorageKey.WEEK_FOCUS_SEC, 0, "weekFocus");
        this.__focusRate = this.createStorageProp(StorageKey.FOCUS_RATE, 0, "focusRate");
        this.__dataVersion = this.createStorageProp(StorageKey.DATA_VERSION, 0, "dataVersion");
        this.__weekTrend = new ObservedPropertyObjectPU([], this, "weekTrend");
        this.__subjects = new ObservedPropertyObjectPU([], this, "subjects");
        this.__examType = new ObservedPropertySimplePU('考研', this, "examType");
        this.__hardestSubject = new ObservedPropertySimplePU('综合', this, "hardestSubject");
        this.__aiInsight = new ObservedPropertySimplePU('', this, "aiInsight");
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
        if (params.hardestSubject !== undefined) {
            this.hardestSubject = params.hardestSubject;
        }
        if (params.aiInsight !== undefined) {
            this.aiInsight = params.aiInsight;
        }
        if (params.weekLabels !== undefined) {
            this.weekLabels = params.weekLabels;
        }
    }
    updateStateVars(params: Dashboard_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__examDays.purgeDependencyOnElmtId(rmElmtId);
        this.__todayDone.purgeDependencyOnElmtId(rmElmtId);
        this.__todayTotal.purgeDependencyOnElmtId(rmElmtId);
        this.__weekFocus.purgeDependencyOnElmtId(rmElmtId);
        this.__focusRate.purgeDependencyOnElmtId(rmElmtId);
        this.__dataVersion.purgeDependencyOnElmtId(rmElmtId);
        this.__weekTrend.purgeDependencyOnElmtId(rmElmtId);
        this.__subjects.purgeDependencyOnElmtId(rmElmtId);
        this.__examType.purgeDependencyOnElmtId(rmElmtId);
        this.__hardestSubject.purgeDependencyOnElmtId(rmElmtId);
        this.__aiInsight.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__examDays.aboutToBeDeleted();
        this.__todayDone.aboutToBeDeleted();
        this.__todayTotal.aboutToBeDeleted();
        this.__weekFocus.aboutToBeDeleted();
        this.__focusRate.aboutToBeDeleted();
        this.__dataVersion.aboutToBeDeleted();
        this.__weekTrend.aboutToBeDeleted();
        this.__subjects.aboutToBeDeleted();
        this.__examType.aboutToBeDeleted();
        this.__hardestSubject.aboutToBeDeleted();
        this.__aiInsight.aboutToBeDeleted();
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
    private __hardestSubject: ObservedPropertySimplePU<string>;
    get hardestSubject() {
        return this.__hardestSubject.get();
    }
    set hardestSubject(newValue: string) {
        this.__hardestSubject.set(newValue);
    }
    private __aiInsight: ObservedPropertySimplePU<string>;
    get aiInsight() {
        return this.__aiInsight.get();
    }
    set aiInsight(newValue: string) {
        this.__aiInsight.set(newValue);
    }
    private weekLabels: string[];
    aboutToAppear(): void {
        this.refresh();
    }
    refresh(): void {
        const store = AppStore.getInstance();
        const d = store.getDashboard();
        this.weekTrend = d.weekTrend;
        this.subjects = d.subjectProgress;
        this.examType = store.getGoal().examType;
        // 最薄弱学科 = 进度最低者，供 AI 洞察引用（指标统一走 AppStore 聚合）
        let minP = 101;
        let hard = '综合';
        for (const sp of this.subjects) {
            if (sp.percent < minP) {
                minP = sp.percent;
                hard = sp.subject;
            }
        }
        this.hardestSubject = hard;
        // 动态 AI 内容必须经 AI 服务返回（硬规则 §1）
        this.aiInsight = AIService.getInstance().longTermAnalysis(store.getProfile(), this.hardestSubject);
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
            // 顶部标题
            Column.create();
            // 顶部标题
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('我的工作台');
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('全局学习看板 · 数据每日更新');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 6 });
            Text.width('100%');
        }, Text);
        Text.pop();
        // 顶部标题
        Column.pop();
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
                    let componentCall = new BarChart(this, { values: this.weekTrend, labels: this.weekLabels }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Dashboard.ets", line: 189, col: 11 });
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
            // AI 洞察
            Column.create();
            __Column__dashCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.margin({ bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 洞察');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new AITag(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Dashboard.ets", line: 207, col: 13 });
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
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.aiInsight);
            Text.fontSize(14);
            Text.lineHeight(22);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        // AI 洞察
        Column.pop();
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
function __Column__dashCard(): void {
    Column.width('100%');
    Column.padding(18);
    Column.backgroundColor(Colors.CARD);
    Column.borderRadius(Radius.LG);
    Column.alignItems(HorizontalAlign.Start);
}
