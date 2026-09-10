if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface StudyReport_Params {
    hasData?: boolean;
    totalStr?: string;
    netStr?: string;
    focusRate?: number;
    completionRate?: number;
    taskDone?: number;
    taskTotal?: number;
    qaCount?: number;
    insights?: string;
    suggestions?: string[];
    questions?: QuestionRecord[];
    levels?: number[];
    states?: string[];
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import type { QuestionRecord } from '../models/QuestionRecord';
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
import { FocusChart } from "@normalized:N&&&entry/src/main/ets/components/FocusChart&";
import { AITag } from "@normalized:N&&&entry/src/main/ets/components/AITag&";
export class StudyReport extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__hasData = new ObservedPropertySimplePU(false, this, "hasData");
        this.__totalStr = new ObservedPropertySimplePU('', this, "totalStr");
        this.__netStr = new ObservedPropertySimplePU('', this, "netStr");
        this.__focusRate = new ObservedPropertySimplePU(0, this, "focusRate");
        this.__completionRate = new ObservedPropertySimplePU(0, this, "completionRate");
        this.__taskDone = new ObservedPropertySimplePU(0, this, "taskDone");
        this.__taskTotal = new ObservedPropertySimplePU(0, this, "taskTotal");
        this.__qaCount = new ObservedPropertySimplePU(0, this, "qaCount");
        this.__insights = new ObservedPropertySimplePU('', this, "insights");
        this.__suggestions = new ObservedPropertyObjectPU([], this, "suggestions");
        this.__questions = new ObservedPropertyObjectPU([], this, "questions");
        this.__levels = new ObservedPropertyObjectPU([], this, "levels");
        this.__states = new ObservedPropertyObjectPU([], this, "states");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: StudyReport_Params) {
        if (params.hasData !== undefined) {
            this.hasData = params.hasData;
        }
        if (params.totalStr !== undefined) {
            this.totalStr = params.totalStr;
        }
        if (params.netStr !== undefined) {
            this.netStr = params.netStr;
        }
        if (params.focusRate !== undefined) {
            this.focusRate = params.focusRate;
        }
        if (params.completionRate !== undefined) {
            this.completionRate = params.completionRate;
        }
        if (params.taskDone !== undefined) {
            this.taskDone = params.taskDone;
        }
        if (params.taskTotal !== undefined) {
            this.taskTotal = params.taskTotal;
        }
        if (params.qaCount !== undefined) {
            this.qaCount = params.qaCount;
        }
        if (params.insights !== undefined) {
            this.insights = params.insights;
        }
        if (params.suggestions !== undefined) {
            this.suggestions = params.suggestions;
        }
        if (params.questions !== undefined) {
            this.questions = params.questions;
        }
        if (params.levels !== undefined) {
            this.levels = params.levels;
        }
        if (params.states !== undefined) {
            this.states = params.states;
        }
    }
    updateStateVars(params: StudyReport_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__hasData.purgeDependencyOnElmtId(rmElmtId);
        this.__totalStr.purgeDependencyOnElmtId(rmElmtId);
        this.__netStr.purgeDependencyOnElmtId(rmElmtId);
        this.__focusRate.purgeDependencyOnElmtId(rmElmtId);
        this.__completionRate.purgeDependencyOnElmtId(rmElmtId);
        this.__taskDone.purgeDependencyOnElmtId(rmElmtId);
        this.__taskTotal.purgeDependencyOnElmtId(rmElmtId);
        this.__qaCount.purgeDependencyOnElmtId(rmElmtId);
        this.__insights.purgeDependencyOnElmtId(rmElmtId);
        this.__suggestions.purgeDependencyOnElmtId(rmElmtId);
        this.__questions.purgeDependencyOnElmtId(rmElmtId);
        this.__levels.purgeDependencyOnElmtId(rmElmtId);
        this.__states.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__hasData.aboutToBeDeleted();
        this.__totalStr.aboutToBeDeleted();
        this.__netStr.aboutToBeDeleted();
        this.__focusRate.aboutToBeDeleted();
        this.__completionRate.aboutToBeDeleted();
        this.__taskDone.aboutToBeDeleted();
        this.__taskTotal.aboutToBeDeleted();
        this.__qaCount.aboutToBeDeleted();
        this.__insights.aboutToBeDeleted();
        this.__suggestions.aboutToBeDeleted();
        this.__questions.aboutToBeDeleted();
        this.__levels.aboutToBeDeleted();
        this.__states.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __hasData: ObservedPropertySimplePU<boolean>;
    get hasData() {
        return this.__hasData.get();
    }
    set hasData(newValue: boolean) {
        this.__hasData.set(newValue);
    }
    private __totalStr: ObservedPropertySimplePU<string>;
    get totalStr() {
        return this.__totalStr.get();
    }
    set totalStr(newValue: string) {
        this.__totalStr.set(newValue);
    }
    private __netStr: ObservedPropertySimplePU<string>;
    get netStr() {
        return this.__netStr.get();
    }
    set netStr(newValue: string) {
        this.__netStr.set(newValue);
    }
    private __focusRate: ObservedPropertySimplePU<number>;
    get focusRate() {
        return this.__focusRate.get();
    }
    set focusRate(newValue: number) {
        this.__focusRate.set(newValue);
    }
    private __completionRate: ObservedPropertySimplePU<number>;
    get completionRate() {
        return this.__completionRate.get();
    }
    set completionRate(newValue: number) {
        this.__completionRate.set(newValue);
    }
    private __taskDone: ObservedPropertySimplePU<number>;
    get taskDone() {
        return this.__taskDone.get();
    }
    set taskDone(newValue: number) {
        this.__taskDone.set(newValue);
    }
    private __taskTotal: ObservedPropertySimplePU<number>;
    get taskTotal() {
        return this.__taskTotal.get();
    }
    set taskTotal(newValue: number) {
        this.__taskTotal.set(newValue);
    }
    private __qaCount: ObservedPropertySimplePU<number>;
    get qaCount() {
        return this.__qaCount.get();
    }
    set qaCount(newValue: number) {
        this.__qaCount.set(newValue);
    }
    private __insights: ObservedPropertySimplePU<string>;
    get insights() {
        return this.__insights.get();
    }
    set insights(newValue: string) {
        this.__insights.set(newValue);
    }
    private __suggestions: ObservedPropertyObjectPU<string[]>;
    get suggestions() {
        return this.__suggestions.get();
    }
    set suggestions(newValue: string[]) {
        this.__suggestions.set(newValue);
    }
    private __questions: ObservedPropertyObjectPU<QuestionRecord[]>;
    get questions() {
        return this.__questions.get();
    }
    set questions(newValue: QuestionRecord[]) {
        this.__questions.set(newValue);
    }
    private __levels: ObservedPropertyObjectPU<number[]>;
    get levels() {
        return this.__levels.get();
    }
    set levels(newValue: number[]) {
        this.__levels.set(newValue);
    }
    private __states: ObservedPropertyObjectPU<string[]>;
    get states() {
        return this.__states.get();
    }
    set states(newValue: string[]) {
        this.__states.set(newValue);
    }
    aboutToAppear(): void {
        const report = AppStore.getInstance().getCurrentReport();
        const session = AppStore.getInstance().getCurrentSession();
        if (report === null || session === null) {
            this.hasData = false;
            return;
        }
        this.hasData = true;
        this.totalStr = TimeUtils.formatDuration(session.totalDuration);
        this.netStr = TimeUtils.formatDuration(session.focusDuration);
        this.focusRate = report.focusRate;
        this.completionRate = report.completionRate;
        this.taskDone = session.completedTaskIds.length;
        this.taskTotal = session.taskIds.length;
        this.qaCount = report.questions.length;
        this.insights = report.insights;
        this.suggestions = report.suggestions;
        this.questions = report.questions;
        for (const p of session.timeline) {
            this.levels.push(p.level);
            this.states.push(p.state);
        }
    }
    private finish(): void {
        router.back();
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
            If.create();
            if (!this.hasData) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('还没有可展示的复盘');
                        Text.fontSize(16);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 60 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('返回');
                        Button.fontSize(15);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.height(44);
                        Button.margin({ top: 16 });
                        Button.onClick(() => {
                            this.finish();
                        });
                    }, Button);
                    Button.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.alignItems(HorizontalAlign.Start);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('今天这一段学习完成了 ✨');
                        Text.fontSize(22);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('小伴帮你整理好了这次的学习情况');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 6 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // ① 专注数据总览
                        Column.create();
                        __Column__reportCard();
                    }, Column);
                    this.sectionTitle.bind(this)('专注数据总览');
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 12 });
                    }, Row);
                    this.stat.bind(this)('总学习时长', this.totalStr);
                    this.stat.bind(this)('净专注时长', this.netStr);
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 12 });
                    }, Row);
                    this.stat.bind(this)('净专注率', `${this.focusRate}%`);
                    this.stat.bind(this)('完成率', `${this.completionRate}%`);
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 12 });
                    }, Row);
                    this.stat.bind(this)('完成任务', `${this.taskDone} / ${this.taskTotal}`);
                    this.stat.bind(this)('AI 答疑', `${this.qaCount} 个问题`);
                    Row.pop();
                    // ① 专注数据总览
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // ② 专注曲线
                        Column.create();
                        __Column__reportCard();
                    }, Column);
                    this.sectionTitle.bind(this)('专注曲线');
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new FocusChart(this, { levels: this.levels, states: this.states }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/StudyReport.ets", line: 107, col: 13 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        levels: this.levels,
                                        states: this.states
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    levels: this.levels, states: this.states
                                });
                            }
                        }, { name: "FocusChart" });
                    }
                    // ② 专注曲线
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // ③ AI 学习洞察
                        Column.create();
                        __Column__reportCard();
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                    }, Row);
                    this.sectionTitle.bind(this)('AI 学习洞察');
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                    }, Blank);
                    Blank.pop();
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new AITag(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/StudyReport.ets", line: 116, col: 15 });
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
                        Text.create(this.insights);
                        Text.fontSize(15);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.lineHeight(24);
                        Text.margin({ top: 8 });
                    }, Text);
                    Text.pop();
                    // ③ AI 学习洞察
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // ④ 优化建议
                        Column.create();
                        __Column__reportCard();
                    }, Column);
                    this.sectionTitle.bind(this)('💡 下一次可以这样试试');
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const s = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Row.create();
                                Row.width('100%');
                                Row.margin({ top: 8 });
                            }, Row);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('•');
                                Text.fontSize(15);
                                Text.fontColor(Colors.PRIMARY_DARK);
                            }, Text);
                            Text.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(s);
                                Text.fontSize(14);
                                Text.fontColor(Colors.TEXT_PRIMARY);
                                Text.margin({ left: 8 });
                            }, Text);
                            Text.pop();
                            Row.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.suggestions, forEachItemGenFunction, (s: string) => s, false, false);
                    }, ForEach);
                    ForEach.pop();
                    // ④ 优化建议
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        // ⑤ 今日问题记录
                        if (this.questions.length > 0) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Column.create();
                                    __Column__reportCard();
                                }, Column);
                                this.sectionTitle.bind(this)(`今天你问了 ${this.qaCount} 个问题`);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    ForEach.create();
                                    const forEachItemGenFunction = _item => {
                                        const q = _item;
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Column.create();
                                            Column.width('100%');
                                            Column.alignItems(HorizontalAlign.Start);
                                            Column.padding(12);
                                            Column.backgroundColor(Colors.BG);
                                            Column.borderRadius(Radius.MD);
                                            Column.margin({ top: 8 });
                                        }, Column);
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create(q.question);
                                            Text.fontSize(14);
                                            Text.fontColor(Colors.TEXT_PRIMARY);
                                        }, Text);
                                        Text.pop();
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create('→ 查看答案');
                                            Text.fontSize(12);
                                            Text.fontColor(Colors.PRIMARY_DARK);
                                            Text.margin({ top: 6 });
                                        }, Text);
                                        Text.pop();
                                        Column.pop();
                                    };
                                    this.forEachUpdateFunction(elmtId, this.questions, forEachItemGenFunction, (q: QuestionRecord) => q.id, false, false);
                                }, ForEach);
                                ForEach.pop();
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
                        Button.createWithLabel('完成');
                        Button.width('100%');
                        Button.height(50);
                        Button.fontSize(16);
                        Button.fontWeight(FontWeight.Medium);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.borderRadius(Radius.LG);
                        Button.margin({ top: 8 });
                        Button.onClick(() => {
                            this.finish();
                        });
                    }, Button);
                    Button.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                        Blank.height(24);
                    }, Blank);
                    Blank.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
        Scroll.pop();
    }
    sectionTitle(title: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
    }
    stat(label: string, value: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.layoutWeight(1);
            Column.padding(14);
            Column.backgroundColor(Colors.BG);
            Column.borderRadius(Radius.MD);
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "StudyReport";
    }
}
function __Column__reportCard(): void {
    Column.width('100%');
    Column.padding(18);
    Column.backgroundColor(Colors.CARD);
    Column.borderRadius(Radius.LG);
    Column.alignItems(HorizontalAlign.Start);
}
registerNamedRoute(() => new StudyReport(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/StudyReport", pageFullPath: "entry/src/main/ets/pages/StudyReport", integratedHsp: "false", moduleType: "followWithHap" });
