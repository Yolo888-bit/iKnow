if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface FocusProfile_Params {
    profile?: Profile;
    dimValues?: number[];
    trend?: number[];
    hardest?: string;
    dimLabels?: string[];
}
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { FocusProfile as Profile } from "@normalized:N&&&entry/src/main/ets/models/FocusProfile&";
import { RadarChart } from "@normalized:N&&&entry/src/main/ets/components/RadarChart&";
import { BarChart } from "@normalized:N&&&entry/src/main/ets/components/BarChart&";
import { AITag } from "@normalized:N&&&entry/src/main/ets/components/AITag&";
export class FocusProfile extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__profile = new ObservedPropertyObjectPU(new Profile(), this, "profile");
        this.__dimValues = new ObservedPropertyObjectPU([], this, "dimValues");
        this.__trend = new ObservedPropertyObjectPU([], this, "trend");
        this.__hardest = new ObservedPropertySimplePU('数学类任务', this, "hardest");
        this.dimLabels = ['效率', '专注度', '稳定性', '执行力', '抗干扰'];
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: FocusProfile_Params) {
        if (params.profile !== undefined) {
            this.profile = params.profile;
        }
        if (params.dimValues !== undefined) {
            this.dimValues = params.dimValues;
        }
        if (params.trend !== undefined) {
            this.trend = params.trend;
        }
        if (params.hardest !== undefined) {
            this.hardest = params.hardest;
        }
        if (params.dimLabels !== undefined) {
            this.dimLabels = params.dimLabels;
        }
    }
    updateStateVars(params: FocusProfile_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__profile.purgeDependencyOnElmtId(rmElmtId);
        this.__dimValues.purgeDependencyOnElmtId(rmElmtId);
        this.__trend.purgeDependencyOnElmtId(rmElmtId);
        this.__hardest.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__profile.aboutToBeDeleted();
        this.__dimValues.aboutToBeDeleted();
        this.__trend.aboutToBeDeleted();
        this.__hardest.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __profile: ObservedPropertyObjectPU<Profile>;
    get profile() {
        return this.__profile.get();
    }
    set profile(newValue: Profile) {
        this.__profile.set(newValue);
    }
    private __dimValues: ObservedPropertyObjectPU<number[]>;
    get dimValues() {
        return this.__dimValues.get();
    }
    set dimValues(newValue: number[]) {
        this.__dimValues.set(newValue);
    }
    private __trend: ObservedPropertyObjectPU<number[]>;
    get trend() {
        return this.__trend.get();
    }
    set trend(newValue: number[]) {
        this.__trend.set(newValue);
    }
    private __hardest: ObservedPropertySimplePU<string>;
    get hardest() {
        return this.__hardest.get();
    }
    set hardest(newValue: string) {
        this.__hardest.set(newValue);
    }
    private dimLabels: string[];
    aboutToAppear(): void {
        this.refresh();
    }
    private refresh(): void {
        const p = AppStore.getInstance().getProfile();
        this.profile = p;
        this.dimValues = [p.efficiency, p.concentration, p.stability, p.execution, p.antiDistraction];
        this.trend = p.monthlyTrend.slice(-14);
        this.hardest = this.hardestSubject();
    }
    private hardestSubject(): string {
        const subs = AppStore.getInstance().getDashboard().subjectProgress;
        if (subs.length === 0) {
            return '数学类任务';
        }
        let hardest = subs[0];
        for (const s of subs) {
            if (s.percent < hardest.percent) {
                hardest = s;
            }
        }
        return `${hardest.subject}类任务`;
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
            Text.create('你的专注成长画像');
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 五维雷达图
            Column.create();
            __Column__profileCard();
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new RadarChart(this, { values: this.dimValues, labels: this.dimLabels, chartSize: 280 }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/FocusProfile.ets", line: 56, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            values: this.dimValues,
                            labels: this.dimLabels,
                            chartSize: 280
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        values: this.dimValues, labels: this.dimLabels, chartSize: 280
                    });
                }
            }, { name: "RadarChart" });
        }
        // 五维雷达图
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 个人专注画像
            Column.create();
            __Column__profileCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('个人专注画像');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.margin({ bottom: 14 });
        }, Text);
        Text.pop();
        this.profileRow.bind(this)('黄金专注时段', this.profile.bestFocusTime);
        this.profileRow.bind(this)('最容易分心的任务', this.hardest);
        this.profileRow.bind(this)('当前专注阈值', `${this.profile.focusThreshold} min`);
        // 个人专注画像
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 专注成长趋势
            Column.create();
            __Column__profileCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('专注成长趋势');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`近 30 天平均专注时长  ${this.trendStart()} min → ${this.trendEnd()} min`);
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ top: 12 });
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.margin({ top: 12 });
            __Common__.width('100%');
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new BarChart(this, { values: this.trend, labels: [] }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/FocusProfile.ets", line: 89, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            values: this.trend,
                            labels: []
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        values: this.trend, labels: []
                    });
                }
            }, { name: "BarChart" });
        }
        __Common__.pop();
        // 专注成长趋势
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // AI 长期分析
            Column.create();
            __Column__profileCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 长期分析');
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
                    let componentCall = new AITag(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/FocusProfile.ets", line: 103, col: 13 });
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
            Text.create(AIService.getInstance().longTermAnalysis(ObservedObject.GetRawObject(this.profile), this.hardest));
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.lineHeight(24);
            Text.margin({ top: 10 });
        }, Text);
        Text.pop();
        // AI 长期分析
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.height(20);
        }, Blank);
        Blank.pop();
        Column.pop();
        Scroll.pop();
    }
    private trendStart(): number {
        if (this.profile.monthlyTrend.length === 0) {
            return 0;
        }
        return this.profile.monthlyTrend[0];
    }
    private trendEnd(): number {
        if (this.profile.monthlyTrend.length === 0) {
            return 0;
        }
        return this.profile.monthlyTrend[this.profile.monthlyTrend.length - 1];
    }
    profileRow(label: string, value: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ top: 10, bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "FocusProfile";
    }
}
function __Column__profileCard(): void {
    Column.width('100%');
    Column.padding(18);
    Column.backgroundColor(Colors.CARD);
    Column.borderRadius(Radius.LG);
    Column.alignItems(HorizontalAlign.Start);
}
registerNamedRoute(() => new FocusProfile(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/FocusProfile", pageFullPath: "entry/src/main/ets/pages/FocusProfile", integratedHsp: "false", moduleType: "followWithHap" });
