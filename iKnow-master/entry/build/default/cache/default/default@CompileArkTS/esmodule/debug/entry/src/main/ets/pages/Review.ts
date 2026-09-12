if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Review_Params {
    summary?: Last30DaysSummary;
    practice?: PracticeSummaryItem[];
    habit?: HabitInsight;
    aiAdvice?: string;
    profile?: FocusProfile;
    dimValues?: number[];
    canShowRadar?: boolean;
    mode?: number;
    dayStart?: number;
    day?: DaySummary;
    dayInsight?: string;
    daySuggestions?: string[];
    showPicker?: boolean;
    pickDayMode?: boolean;
    calYear?: number;
    calMonth?: number;
    todayY?: number;
    todayM?: number;
    todayD?: number;
    selY?: number;
    selM?: number;
    selD?: number;
    activeIndex?: number;
    bubbleX?: number;
    bubbleY?: number;
    geoL?: number;
    geoStep?: number;
    geoT?: number;
    geoChartH?: number;
    geoMaxV?: number;
    geoN?: number;
    geoW?: number;
    dimLabels?: string[];
    chartSettings?: RenderingContextSettings;
    lineCtx?: CanvasRenderingContext2D;
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { Metrics } from "@normalized:N&&&entry/src/main/ets/services/Metrics&";
import type { Last30DaysSummary, PracticeSummaryItem, HabitInsight, DaySummary } from "@normalized:N&&&entry/src/main/ets/services/Metrics&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { FocusProfile } from "@normalized:N&&&entry/src/main/ets/models/FocusProfile&";
import { RadarChart } from "@normalized:N&&&entry/src/main/ets/components/RadarChart&";
import { FocusChart } from "@normalized:N&&&entry/src/main/ets/components/FocusChart&";
import { CircularProgress } from "@normalized:N&&&entry/src/main/ets/components/CircularProgress&";
import type { FocusSession } from '../models/FocusSession';
import type { Task } from '../models/Task';
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
export class Review extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__summary = new ObservedPropertyObjectPU({ totalHours: 0, completedTasks: 0, focusRate: 0, trend: [] }, this, "summary");
        this.__practice = new ObservedPropertyObjectPU([], this, "practice");
        this.__habit = new ObservedPropertyObjectPU({ bestWindow: '08:00 - 10:00', bestRate: 0, lowWindow: '晚间 21 点后', lowNote: '容易分心', advice: '难题优先安排上午攻克。' }, this, "habit");
        this.__aiAdvice = new ObservedPropertySimplePU('', this, "aiAdvice");
        this.__profile = new ObservedPropertyObjectPU(new FocusProfile(), this, "profile");
        this.__dimValues = new ObservedPropertyObjectPU([], this, "dimValues");
        this.__canShowRadar = new ObservedPropertySimplePU(false
        // ---------- 单日复盘状态 ----------
        /** 0 = 长期学习总结；1 = 某天学习总结 */
        , this, "canShowRadar");
        this.__mode = new ObservedPropertySimplePU(0, this, "mode");
        this.__dayStart = new ObservedPropertySimplePU(0, this, "dayStart");
        this.__day = new ObservedPropertyObjectPU({
            hasData: false,
            studyMinutes: 0,
            focusRate: 0,
            completedTasks: 0,
            totalTasks: 0,
            qaSessions: 0,
            sessionCount: 0,
            bestPeriod: '',
            levels: [],
            states: []
        }, this, "day");
        this.__dayInsight = new ObservedPropertySimplePU('', this, "dayInsight");
        this.__daySuggestions = new ObservedPropertyObjectPU([]
        // 右上角下拉面板：切换「长期复盘 / 按天复盘」，按天时内嵌月历
        , this, "daySuggestions");
        this.__showPicker = new ObservedPropertySimplePU(false
        /** 下拉面板里是否已展开「按天复盘」的月历 */
        , this, "showPicker");
        this.__pickDayMode = new ObservedPropertySimplePU(false, this, "pickDayMode");
        this.__calYear = new ObservedPropertySimplePU(2026, this, "calYear");
        this.__calMonth = new ObservedPropertySimplePU(8, this, "calMonth");
        this.todayY = 2026;
        this.todayM = 8;
        this.todayD = 1;
        this.selY = 2026;
        this.selM = 8;
        this.selD = 1;
        this.__activeIndex = new ObservedPropertySimplePU(-1, this, "activeIndex");
        this.__bubbleX = new ObservedPropertySimplePU(0, this, "bubbleX");
        this.__bubbleY = new ObservedPropertySimplePU(0, this, "bubbleY");
        this.geoL = 0;
        this.geoStep = 0;
        this.geoT = 0;
        this.geoChartH = 0;
        this.geoMaxV = 1;
        this.geoN = 0;
        this.geoW = 0;
        this.dimLabels = ['效率', '专注度', '稳定性', '执行力', '抗干扰'];
        this.chartSettings = new RenderingContextSettings(true);
        this.lineCtx = new CanvasRenderingContext2D(this.chartSettings);
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Review_Params) {
        if (params.summary !== undefined) {
            this.summary = params.summary;
        }
        if (params.practice !== undefined) {
            this.practice = params.practice;
        }
        if (params.habit !== undefined) {
            this.habit = params.habit;
        }
        if (params.aiAdvice !== undefined) {
            this.aiAdvice = params.aiAdvice;
        }
        if (params.profile !== undefined) {
            this.profile = params.profile;
        }
        if (params.dimValues !== undefined) {
            this.dimValues = params.dimValues;
        }
        if (params.canShowRadar !== undefined) {
            this.canShowRadar = params.canShowRadar;
        }
        if (params.mode !== undefined) {
            this.mode = params.mode;
        }
        if (params.dayStart !== undefined) {
            this.dayStart = params.dayStart;
        }
        if (params.day !== undefined) {
            this.day = params.day;
        }
        if (params.dayInsight !== undefined) {
            this.dayInsight = params.dayInsight;
        }
        if (params.daySuggestions !== undefined) {
            this.daySuggestions = params.daySuggestions;
        }
        if (params.showPicker !== undefined) {
            this.showPicker = params.showPicker;
        }
        if (params.pickDayMode !== undefined) {
            this.pickDayMode = params.pickDayMode;
        }
        if (params.calYear !== undefined) {
            this.calYear = params.calYear;
        }
        if (params.calMonth !== undefined) {
            this.calMonth = params.calMonth;
        }
        if (params.todayY !== undefined) {
            this.todayY = params.todayY;
        }
        if (params.todayM !== undefined) {
            this.todayM = params.todayM;
        }
        if (params.todayD !== undefined) {
            this.todayD = params.todayD;
        }
        if (params.selY !== undefined) {
            this.selY = params.selY;
        }
        if (params.selM !== undefined) {
            this.selM = params.selM;
        }
        if (params.selD !== undefined) {
            this.selD = params.selD;
        }
        if (params.activeIndex !== undefined) {
            this.activeIndex = params.activeIndex;
        }
        if (params.bubbleX !== undefined) {
            this.bubbleX = params.bubbleX;
        }
        if (params.bubbleY !== undefined) {
            this.bubbleY = params.bubbleY;
        }
        if (params.geoL !== undefined) {
            this.geoL = params.geoL;
        }
        if (params.geoStep !== undefined) {
            this.geoStep = params.geoStep;
        }
        if (params.geoT !== undefined) {
            this.geoT = params.geoT;
        }
        if (params.geoChartH !== undefined) {
            this.geoChartH = params.geoChartH;
        }
        if (params.geoMaxV !== undefined) {
            this.geoMaxV = params.geoMaxV;
        }
        if (params.geoN !== undefined) {
            this.geoN = params.geoN;
        }
        if (params.geoW !== undefined) {
            this.geoW = params.geoW;
        }
        if (params.dimLabels !== undefined) {
            this.dimLabels = params.dimLabels;
        }
        if (params.chartSettings !== undefined) {
            this.chartSettings = params.chartSettings;
        }
        if (params.lineCtx !== undefined) {
            this.lineCtx = params.lineCtx;
        }
    }
    updateStateVars(params: Review_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__summary.purgeDependencyOnElmtId(rmElmtId);
        this.__practice.purgeDependencyOnElmtId(rmElmtId);
        this.__habit.purgeDependencyOnElmtId(rmElmtId);
        this.__aiAdvice.purgeDependencyOnElmtId(rmElmtId);
        this.__profile.purgeDependencyOnElmtId(rmElmtId);
        this.__dimValues.purgeDependencyOnElmtId(rmElmtId);
        this.__canShowRadar.purgeDependencyOnElmtId(rmElmtId);
        this.__mode.purgeDependencyOnElmtId(rmElmtId);
        this.__dayStart.purgeDependencyOnElmtId(rmElmtId);
        this.__day.purgeDependencyOnElmtId(rmElmtId);
        this.__dayInsight.purgeDependencyOnElmtId(rmElmtId);
        this.__daySuggestions.purgeDependencyOnElmtId(rmElmtId);
        this.__showPicker.purgeDependencyOnElmtId(rmElmtId);
        this.__pickDayMode.purgeDependencyOnElmtId(rmElmtId);
        this.__calYear.purgeDependencyOnElmtId(rmElmtId);
        this.__calMonth.purgeDependencyOnElmtId(rmElmtId);
        this.__activeIndex.purgeDependencyOnElmtId(rmElmtId);
        this.__bubbleX.purgeDependencyOnElmtId(rmElmtId);
        this.__bubbleY.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__summary.aboutToBeDeleted();
        this.__practice.aboutToBeDeleted();
        this.__habit.aboutToBeDeleted();
        this.__aiAdvice.aboutToBeDeleted();
        this.__profile.aboutToBeDeleted();
        this.__dimValues.aboutToBeDeleted();
        this.__canShowRadar.aboutToBeDeleted();
        this.__mode.aboutToBeDeleted();
        this.__dayStart.aboutToBeDeleted();
        this.__day.aboutToBeDeleted();
        this.__dayInsight.aboutToBeDeleted();
        this.__daySuggestions.aboutToBeDeleted();
        this.__showPicker.aboutToBeDeleted();
        this.__pickDayMode.aboutToBeDeleted();
        this.__calYear.aboutToBeDeleted();
        this.__calMonth.aboutToBeDeleted();
        this.__activeIndex.aboutToBeDeleted();
        this.__bubbleX.aboutToBeDeleted();
        this.__bubbleY.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    // ---------- 长期总结状态 ----------
    private __summary: ObservedPropertyObjectPU<Last30DaysSummary>;
    get summary() {
        return this.__summary.get();
    }
    set summary(newValue: Last30DaysSummary) {
        this.__summary.set(newValue);
    }
    private __practice: ObservedPropertyObjectPU<PracticeSummaryItem[]>;
    get practice() {
        return this.__practice.get();
    }
    set practice(newValue: PracticeSummaryItem[]) {
        this.__practice.set(newValue);
    }
    private __habit: ObservedPropertyObjectPU<HabitInsight>;
    get habit() {
        return this.__habit.get();
    }
    set habit(newValue: HabitInsight) {
        this.__habit.set(newValue);
    }
    private __aiAdvice: ObservedPropertySimplePU<string>;
    get aiAdvice() {
        return this.__aiAdvice.get();
    }
    set aiAdvice(newValue: string) {
        this.__aiAdvice.set(newValue);
    }
    private __profile: ObservedPropertyObjectPU<FocusProfile>;
    get profile() {
        return this.__profile.get();
    }
    set profile(newValue: FocusProfile) {
        this.__profile.set(newValue);
    }
    private __dimValues: ObservedPropertyObjectPU<number[]>;
    get dimValues() {
        return this.__dimValues.get();
    }
    set dimValues(newValue: number[]) {
        this.__dimValues.set(newValue);
    }
    private __canShowRadar: ObservedPropertySimplePU<boolean>;
    get canShowRadar() {
        return this.__canShowRadar.get();
    }
    set canShowRadar(newValue: boolean) {
        this.__canShowRadar.set(newValue);
    }
    // ---------- 单日复盘状态 ----------
    /** 0 = 长期学习总结；1 = 某天学习总结 */
    private __mode: ObservedPropertySimplePU<number>;
    get mode() {
        return this.__mode.get();
    }
    set mode(newValue: number) {
        this.__mode.set(newValue);
    }
    private __dayStart: ObservedPropertySimplePU<number>;
    get dayStart() {
        return this.__dayStart.get();
    }
    set dayStart(newValue: number) {
        this.__dayStart.set(newValue);
    }
    private __day: ObservedPropertyObjectPU<DaySummary>;
    get day() {
        return this.__day.get();
    }
    set day(newValue: DaySummary) {
        this.__day.set(newValue);
    }
    private __dayInsight: ObservedPropertySimplePU<string>;
    get dayInsight() {
        return this.__dayInsight.get();
    }
    set dayInsight(newValue: string) {
        this.__dayInsight.set(newValue);
    }
    private __daySuggestions: ObservedPropertyObjectPU<string[]>;
    get daySuggestions() {
        return this.__daySuggestions.get();
    }
    set daySuggestions(newValue: string[]) {
        this.__daySuggestions.set(newValue);
    }
    // 右上角下拉面板：切换「长期复盘 / 按天复盘」，按天时内嵌月历
    private __showPicker: ObservedPropertySimplePU<boolean>;
    get showPicker() {
        return this.__showPicker.get();
    }
    set showPicker(newValue: boolean) {
        this.__showPicker.set(newValue);
    }
    /** 下拉面板里是否已展开「按天复盘」的月历 */
    private __pickDayMode: ObservedPropertySimplePU<boolean>;
    get pickDayMode() {
        return this.__pickDayMode.get();
    }
    set pickDayMode(newValue: boolean) {
        this.__pickDayMode.set(newValue);
    }
    private __calYear: ObservedPropertySimplePU<number>;
    get calYear() {
        return this.__calYear.get();
    }
    set calYear(newValue: number) {
        this.__calYear.set(newValue);
    }
    private __calMonth: ObservedPropertySimplePU<number>;
    get calMonth() {
        return this.__calMonth.get();
    }
    set calMonth(newValue: number) {
        this.__calMonth.set(newValue);
    }
    private todayY: number;
    private todayM: number;
    private todayD: number;
    private selY: number;
    private selM: number;
    private selD: number;
    // 曲线交互：当前选中的数据点（-1 表示未选中，则不画任何点）
    private __activeIndex: ObservedPropertySimplePU<number>;
    get activeIndex() {
        return this.__activeIndex.get();
    }
    set activeIndex(newValue: number) {
        this.__activeIndex.set(newValue);
    }
    private __bubbleX: ObservedPropertySimplePU<number>;
    get bubbleX() {
        return this.__bubbleX.get();
    }
    set bubbleX(newValue: number) {
        this.__bubbleX.set(newValue);
    }
    private __bubbleY: ObservedPropertySimplePU<number>;
    get bubbleY() {
        return this.__bubbleY.get();
    }
    set bubbleY(newValue: number) {
        this.__bubbleY.set(newValue);
    }
    private geoL: number;
    private geoStep: number;
    private geoT: number;
    private geoChartH: number;
    private geoMaxV: number;
    private geoN: number;
    private geoW: number;
    private dimLabels: string[];
    private chartSettings: RenderingContextSettings;
    private lineCtx: CanvasRenderingContext2D;
    aboutToAppear(): void {
        const store = AppStore.getInstance();
        const sessions: FocusSession[] = store.getSessions();
        const tasks: Task[] = store.getTasks();
        const now = Date.now();
        this.summary = Metrics.last30DaysSummary(sessions, tasks, now);
        this.practice = Metrics.practiceSummary(sessions, tasks);
        this.habit = Metrics.habitInsights(sessions);
        this.profile = store.getProfile();
        this.dimValues = [
            this.profile.efficiency,
            this.profile.concentration,
            this.profile.stability,
            this.profile.execution,
            this.profile.antiDistraction
        ];
        this.canShowRadar = Metrics.canShowProfile(this.profile.sampleCount);
        const hardest = this.hardestSubject();
        this.aiAdvice = AIService.getInstance().longTermAnalysis(this.profile, hardest);
        // 默认选中「今天」
        this.dayStart = TimeUtils.dayStart(now);
        // 初始化日历弹层（选中日 = 今天，视图定位到当月）
        const sd = new Date(this.dayStart);
        this.selY = sd.getFullYear();
        this.selM = sd.getMonth();
        this.selD = sd.getDate();
        this.calYear = this.selY;
        this.calMonth = this.selM;
        const tnow = new Date(now);
        this.todayY = tnow.getFullYear();
        this.todayM = tnow.getMonth();
        this.todayD = tnow.getDate();
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
    // ===================== 单日复盘 =====================
    /** 右上角日期 chip：下拉出「长期复盘 / 按天复盘」切换面板 */
    private pickDay(): void {
        this.showPicker = !this.showPicker;
    }
    // ===================== 日历弹层（月历） =====================
    /** 当月网格：前导空格用 0 占位，之后是 1..daysInMonth */
    private calCells(): number[] {
        const first = new Date(this.calYear, this.calMonth, 1).getDay();
        const days = new Date(this.calYear, this.calMonth + 1, 0).getDate();
        const cells: number[] = [];
        for (let i = 0; i < first; i++) {
            cells.push(0);
        }
        for (let d = 1; d <= days; d++) {
            cells.push(d);
        }
        return cells;
    }
    private isFuture(y: number, m: number, d: number): boolean {
        const today = new Date(this.todayY, this.todayM, this.todayD);
        const sel = new Date(y, m, d);
        return sel.getTime() > today.getTime();
    }
    private isSameDay(y: number, m: number, d: number, sy: number, sm: number, sd: number): boolean {
        return y === sy && m === sm && d === sd;
    }
    private shiftMonth(delta: number): void {
        let m = this.calMonth + delta;
        let y = this.calYear;
        if (m < 0) {
            m = 11;
            y -= 1;
        }
        if (m > 11) {
            m = 0;
            y += 1;
        }
        this.calYear = y;
        this.calMonth = m;
    }
    private confirmDay(day: number): void {
        const ts = new Date(this.calYear, this.calMonth, day).getTime();
        this.dayStart = TimeUtils.dayStart(ts);
        this.selY = this.calYear;
        this.selM = this.calMonth;
        this.selD = day;
        this.loadDay();
        this.mode = 1;
        this.showPicker = false;
    }
    calDayCell(day: number, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height(34);
            Column.borderRadius(17);
            Column.backgroundColor(this.isSameDay(this.calYear, this.calMonth, day, this.selY, this.selM, this.selD)
                ? Colors.PRIMARY_SOFT
                : (this.isSameDay(this.calYear, this.calMonth, day, this.todayY, this.todayM, this.todayD)
                    ? Colors.GREEN_SOFT : Color.Transparent));
            Column.justifyContent(FlexAlign.Center);
            Column.onClick(() => {
                if (this.isFuture(this.calYear, this.calMonth, day)) {
                    return;
                }
                this.confirmDay(day);
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${day}`);
            Text.fontSize(14);
            Text.fontColor(this.isFuture(this.calYear, this.calMonth, day) ? Colors.TEXT_TERTIARY : Colors.TEXT_PRIMARY);
            Text.fontWeight(this.isSameDay(this.calYear, this.calMonth, day, this.selY, this.selM, this.selD)
                ? FontWeight.Bold : FontWeight.Normal);
        }, Text);
        Text.pop();
        Column.pop();
    }
    /** 下拉面板里的一个模式选项 */
    modeOption(icon: string, title: string, desc: string, m: number, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.width('100%');
            Row.padding(12);
            Row.borderRadius(Radius.MD);
            Row.backgroundColor(this.mode === m ? Colors.PRIMARY_SOFT : Color.Transparent);
            Row.onClick(() => {
                if (m === 0) {
                    // 切回长期复盘并收起面板
                    this.mode = 0;
                    this.pickDayMode = false;
                    this.showPicker = false;
                    this.onLineChartReady();
                }
                else {
                    // 展开月历，由用户挑具体某天
                    this.pickDayMode = true;
                }
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(icon);
            Text.fontSize(18);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(desc);
            Text.fontSize(11);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.mode === m) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('✓');
                        Text.fontSize(16);
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
    }
    /** 右上角下拉面板：长期复盘 / 按天复盘（按天时在面板里内嵌月历） */
    pickerPanel(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.SM });
            Column.width(300);
            Column.padding(12);
            Column.backgroundColor(Colors.CARD);
            Column.borderRadius(Radius.LG);
            Column.shadow({ radius: 24, color: '#26000000', offsetX: 0, offsetY: 8 });
        }, Column);
        this.modeOption.bind(this)('📈', '长期复盘', '近 30 天整体表现', 0);
        this.modeOption.bind(this)('📅', '按天复盘', '查看某一天的专注记录', 1);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.pickDayMode) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Divider.create();
                        Divider.color(Colors.LINE);
                        Divider.margin({ top: 4, bottom: 8 });
                    }, Divider);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 年月 + 上/下月切换
                        Row.create();
                        // 年月 + 上/下月切换
                        Row.width('100%');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('‹');
                        Text.fontSize(22);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.padding({ left: 6, right: 6 });
                        Text.onClick(() => {
                            this.shiftMonth(-1);
                        });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                    }, Blank);
                    Blank.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`${this.calYear}年${this.calMonth + 1}月`);
                        Text.fontSize(14);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                    }, Blank);
                    Blank.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('›');
                        Text.fontSize(22);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.padding({ left: 6, right: 6 });
                        Text.onClick(() => {
                            this.shiftMonth(1);
                        });
                    }, Text);
                    Text.pop();
                    // 年月 + 上/下月切换
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 星期表头
                        Row.create();
                        // 星期表头
                        Row.width('100%');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const w = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(w);
                                Text.fontSize(11);
                                Text.fontColor(Colors.TEXT_TERTIARY);
                                Text.textAlign(TextAlign.Center);
                                Text.layoutWeight(1);
                            }, Text);
                            Text.pop();
                        };
                        this.forEachUpdateFunction(elmtId, ['日', '一', '二', '三', '四', '五', '六'], forEachItemGenFunction, (w: string) => w, false, false);
                    }, ForEach);
                    ForEach.pop();
                    // 星期表头
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 日期网格
                        Grid.create();
                        // 日期网格
                        Grid.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr');
                        // 日期网格
                        Grid.rowsGap(2);
                        // 日期网格
                        Grid.columnsGap(2);
                        // 日期网格
                        Grid.height(210);
                        // 日期网格
                        Grid.width('100%');
                    }, Grid);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = (_item, idx: number) => {
                            const cell = _item;
                            {
                                const itemCreation2 = (elmtId, isInitialRender) => {
                                    GridItem.create(() => { }, false);
                                };
                                const observedDeepRender = () => {
                                    this.observeComponentCreation2(itemCreation2, GridItem);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        If.create();
                                        if (cell > 0) {
                                            this.ifElseBranchUpdateFunction(0, () => {
                                                this.calDayCell.bind(this)(cell);
                                            });
                                        }
                                        else {
                                            this.ifElseBranchUpdateFunction(1, () => {
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create('');
                                                    Text.width('100%');
                                                    Text.height(34);
                                                }, Text);
                                                Text.pop();
                                            });
                                        }
                                    }, If);
                                    If.pop();
                                    GridItem.pop();
                                };
                                observedDeepRender();
                            }
                        };
                        this.forEachUpdateFunction(elmtId, this.calCells(), forEachItemGenFunction, (cell: number, idx: number) => `${idx}_${cell}`, true, true);
                    }, ForEach);
                    ForEach.pop();
                    // 日期网格
                    Grid.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    private backToLong(): void {
        this.mode = 0;
        this.onLineChartReady();
    }
    private dayLabel(): string {
        const d = new Date(this.dayStart);
        return `${d.getMonth() + 1}月${d.getDate()}日`;
    }
    private loadDay(): void {
        const sessions: FocusSession[] = AppStore.getInstance().getSessions();
        this.day = Metrics.daySummary(sessions, this.dayStart);
        this.dayInsight = AIService.getInstance().dayInsight(this.dayLabel(), this.day.focusRate, this.day.bestPeriod, this.day.hasData);
        this.daySuggestions = AIService.getInstance().daySuggestions(this.day.studyMinutes, this.day.focusRate);
    }
    private dayStatusText(): string {
        if (!this.day.hasData) {
            return '这一天还没有学习记录';
        }
        if (this.day.focusRate >= 80) {
            return '状态不错，继续保持';
        }
        if (this.day.focusRate >= 60) {
            return '状态稳定，继续保持';
        }
        return '有提升空间，再接再厉';
    }
    private dayStatusTag(): string {
        if (this.day.focusRate >= 80) {
            return '专注度 高';
        }
        if (this.day.focusRate >= 60) {
            return '专注度 中';
        }
        return '专注度 低';
    }
    // ===================== 长期曲线（平滑） =====================
    /** 用「二次贝塞尔过中点」把折线变成平滑曲线（调用前需先把当前点移到首点） */
    private curveThrough(c: CanvasRenderingContext2D, pts: number[][]): void {
        const n = pts.length;
        if (n < 2) {
            return;
        }
        for (let i = 1; i < n - 1; i++) {
            const midX = (pts[i][0] + pts[i + 1][0]) / 2;
            const midY = (pts[i][1] + pts[i + 1][1]) / 2;
            c.quadraticCurveTo(pts[i][0], pts[i][1], midX, midY);
        }
        c.quadraticCurveTo(pts[n - 1][0], pts[n - 1][1], pts[n - 1][0], pts[n - 1][1]);
    }
    private onLineChartReady(): void {
        const c = this.lineCtx;
        const w = c.width;
        const h = c.height;
        c.clearRect(0, 0, w, h);
        const values = this.summary.trend;
        if (values.length === 0) {
            return;
        }
        const padLeft = 8;
        const padRight = 8;
        const padTop = 16;
        const padBottom = 24;
        const chartW = w - padLeft - padRight;
        const chartH = h - padTop - padBottom;
        const baseY = padTop + chartH;
        let maxV = 1;
        for (const v of values) {
            if (v > maxV) {
                maxV = v;
            }
        }
        const n = values.length;
        const stepX = n > 1 ? chartW / (n - 1) : chartW;
        const points: number[][] = [];
        for (let i = 0; i < n; i++) {
            const x = padLeft + i * stepX;
            const y = padTop + chartH - (values[i] / maxV) * chartH;
            points.push([x, y]);
        }
        // 缓存几何参数，供触摸时「按 x 定位最近数据点」
        this.geoL = padLeft;
        this.geoStep = stepX;
        this.geoT = padTop;
        this.geoChartH = chartH;
        this.geoMaxV = maxV;
        this.geoN = n;
        this.geoW = w;
        // 渐变填充区域（平滑上边）
        c.beginPath();
        c.moveTo(points[0][0], baseY);
        c.lineTo(points[0][0], points[0][1]);
        this.curveThrough(c, points);
        c.lineTo(points[n - 1][0], baseY);
        c.closePath();
        const grad = c.createLinearGradient(0, padTop, 0, baseY);
        grad.addColorStop(0, 'rgba(127,191,151,0.35)');
        grad.addColorStop(1, 'rgba(127,191,151,0.02)');
        c.fillStyle = grad;
        c.fill();
        // 平滑曲线
        c.beginPath();
        c.moveTo(points[0][0], points[0][1]);
        this.curveThrough(c, points);
        c.strokeStyle = '#7FBF97';
        c.lineWidth = 3;
        c.lineJoin = 'round';
        c.lineCap = 'round';
        c.stroke();
        // 默认不画任何数据点；只有用户点按 / 拖拽曲线时才高亮当前点
        if (this.activeIndex >= 0 && this.activeIndex < n) {
            const i = this.activeIndex;
            const px = points[i][0];
            const py = points[i][1];
            // 垂直参考线
            c.beginPath();
            c.moveTo(px, padTop);
            c.lineTo(px, baseY);
            c.strokeStyle = 'rgba(127,191,151,0.55)';
            c.lineWidth = 1;
            c.stroke();
            // 高亮点
            c.beginPath();
            c.arc(px, py, 5, 0, Math.PI * 2);
            c.fillStyle = '#FFFFFF';
            c.fill();
            c.lineWidth = 3;
            c.strokeStyle = '#7FBF97';
            c.stroke();
        }
        // 首尾标签
        c.fillStyle = Colors.TEXT_SECONDARY;
        c.font = '10px sans-serif';
        c.textAlign = 'left';
        c.fillText('30天前', padLeft, h - 6);
        c.textAlign = 'right';
        c.fillText('今天', w - padRight, h - 6);
    }
    /** 曲线触摸：按 x 定位最近的数据点（点按显示点、左右拖拽数值实时变化） */
    private onChartTouch(event: TouchEvent): void {
        if (this.geoN === 0 || event.touches.length === 0) {
            return;
        }
        const type = event.type;
        if (type === TouchType.Up || type === TouchType.Cancel) {
            // 松手后保留当前点，方便读数
            return;
        }
        const x = event.touches[0].x;
        let idx = 0;
        if (this.geoStep > 0) {
            idx = Math.round((x - this.geoL) / this.geoStep);
        }
        if (idx < 0) {
            idx = 0;
        }
        if (idx > this.geoN - 1) {
            idx = this.geoN - 1;
        }
        if (idx !== this.activeIndex) {
            this.activeIndex = idx;
            this.updateBubblePos();
            this.onLineChartReady();
        }
    }
    /** 数值气泡位置（跟随选中点，贴边自动收敛） */
    private updateBubblePos(): void {
        const values = this.summary.trend;
        const i = this.activeIndex;
        if (i < 0 || i >= values.length || this.geoMaxV <= 0) {
            return;
        }
        const px = this.geoL + i * this.geoStep;
        const py = this.geoT + this.geoChartH - (values[i] / this.geoMaxV) * this.geoChartH;
        let bx = px - 52;
        if (bx < 0) {
            bx = 0;
        }
        const maxBx = this.geoW - 104;
        if (bx > maxBx) {
            bx = maxBx > 0 ? maxBx : 0;
        }
        let by = py - 58;
        if (by < 0) {
            by = 0;
        }
        this.bubbleX = bx;
        this.bubbleY = by;
    }
    /** 选中点对应的日期（trend[0] = 29 天前，最后一格 = 今天） */
    private activeDateLabel(): string {
        const dayMs = 24 * 3600 * 1000;
        const ds = TimeUtils.dayStart(Date.now()) - (29 - this.activeIndex) * dayMs;
        const d = new Date(ds);
        return `${d.getMonth() + 1}月${d.getDate()}日`;
    }
    private activeMinutes(): number {
        const values = this.summary.trend;
        if (this.activeIndex < 0 || this.activeIndex >= values.length) {
            return 0;
        }
        return values[this.activeIndex];
    }
    /** 顶部日期 chip 文案：长期=今天，按天=所选日期 */
    private chipLabel(): string {
        if (this.mode === 0) {
            return `${this.todayM + 1}月${this.todayD}日`;
        }
        return this.dayLabel();
    }
    // ===================== View builders =====================
    statCard(label: string, value: string, unit: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.layoutWeight(1);
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.alignItems(VerticalAlign.Bottom);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.fontSize(28);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(unit);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ left: 4, bottom: 4 });
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
    }
    metricTile(label: string, value: string, unit: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.layoutWeight(1);
            Column.padding(14);
            Column.backgroundColor(Colors.CARD);
            Column.borderRadius(Radius.LG);
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.alignItems(VerticalAlign.Bottom);
            Row.margin({ top: 6 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.fontSize(22);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (unit.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(unit);
                        Text.fontSize(12);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ left: 3, bottom: 3 });
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
        Column.pop();
    }
    sectionHeader(icon: string, title: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(icon);
            Text.fontSize(18);
            Text.margin({ right: 6 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        Row.pop();
    }
    /** 单日学习总结视图 */
    dayView(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部状态卡
            Column.create({ space: Spacing.SM });
            // 顶部状态卡
            Column.width('100%');
            // 顶部状态卡
            Column.padding(18);
            // 顶部状态卡
            Column.backgroundColor(Colors.CARD);
            // 顶部状态卡
            Column.borderRadius(Radius.LG);
            // 顶部状态卡
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.alignItems(VerticalAlign.Top);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.dayStatusText());
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`本次学习 ${this.day.studyMinutes} 分钟，任务完成 ${this.day.completedTasks}/${this.day.totalTasks}`);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.dayStatusTag());
            Text.fontSize(11);
            Text.fontColor(Colors.GREEN);
            Text.padding({ top: 4, bottom: 4, left: 10, right: 10 });
            Text.backgroundColor(Colors.GREEN_SOFT);
            Text.borderRadius(10);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.day.hasData) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.width('100%');
                        Row.alignItems(VerticalAlign.Center);
                        Row.margin({ top: 4 });
                    }, Row);
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new CircularProgress(this, { percent: this.day.focusRate, boxSize: 96, label: '专注率' }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Review.ets", line: 669, col: 11 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        percent: this.day.focusRate,
                                        boxSize: 96,
                                        label: '专注率'
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    percent: this.day.focusRate, boxSize: 96, label: '专注率'
                                });
                            }
                        }, { name: "CircularProgress" });
                    }
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        __Common__.create();
                        __Common__.layoutWeight(1);
                        __Common__.height(90);
                        __Common__.margin({ left: 8 });
                    }, __Common__);
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new FocusChart(this, { levels: this.day.levels, states: this.day.states }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Review.ets", line: 670, col: 11 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        levels: this.day.levels,
                                        states: this.day.states
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    levels: this.day.levels, states: this.day.states
                                });
                            }
                        }, { name: "FocusChart" });
                    }
                    __Common__.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.height(110);
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('🌱');
                        Text.fontSize(30);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('这一天还没有专注记录');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 6 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
        }, If);
        If.pop();
        // 顶部状态卡
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 四项指标
            Row.create({ space: Spacing.MD });
            // 四项指标
            Row.width('100%');
        }, Row);
        this.metricTile.bind(this)('学习时长', `${this.day.studyMinutes}`, '分钟');
        this.metricTile.bind(this)('任务完成率', `${this.day.completedTasks}/${this.day.totalTasks}`, '');
        // 四项指标
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: Spacing.MD });
            Row.width('100%');
        }, Row);
        this.metricTile.bind(this)('专注分数', `${this.day.focusRate}`, '分');
        this.metricTile.bind(this)('答疑回顾', `${this.day.qaSessions}`, '次');
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // AI 洞察
            Column.create({ space: Spacing.SM });
            // AI 洞察
            Column.width('100%');
            // AI 洞察
            Column.padding(18);
            // AI 洞察
            Column.backgroundColor(Colors.CARD);
            // AI 洞察
            Column.borderRadius(Radius.LG);
            // AI 洞察
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.sectionHeader.bind(this)('⭐', 'AI 洞察');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.dayInsight.length > 0 ? this.dayInsight : '完成更多专注后，我会根据真实数据给出洞察。');
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.lineHeight(22);
            Text.margin({ top: 6 });
            Text.width('100%');
        }, Text);
        Text.pop();
        // AI 洞察
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 学习建议
            Column.create({ space: Spacing.SM });
            // 学习建议
            Column.width('100%');
            // 学习建议
            Column.padding(18);
            // 学习建议
            Column.backgroundColor(Colors.CARD);
            // 学习建议
            Column.borderRadius(Radius.LG);
            // 学习建议
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.sectionHeader.bind(this)('💡', '学习建议');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const s = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.width('100%');
                    Row.alignItems(VerticalAlign.Top);
                    Row.margin({ top: 8 });
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Circle.create();
                    Circle.width(6);
                    Circle.height(6);
                    Circle.fill(Colors.GREEN);
                    Circle.margin({ top: 7 });
                }, Circle);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(s);
                    Text.fontSize(14);
                    Text.fontColor(Colors.TEXT_PRIMARY);
                    Text.margin({ left: 10 });
                    Text.layoutWeight(1);
                }, Text);
                Text.pop();
                Row.pop();
            };
            this.forEachUpdateFunction(elmtId, this.daySuggestions, forEachItemGenFunction, (s: string) => s, false, false);
        }, ForEach);
        ForEach.pop();
        // 学习建议
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('返回长期总结');
            Button.type(ButtonType.Capsule);
            Button.fontSize(16);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.GREEN_SOFT);
            Button.width('70%');
            Button.margin({ top: 8, bottom: 24 });
            Button.onClick(() => {
                this.backToLong();
            });
        }, Button);
        Button.pop();
    }
    /** 长期学习总结视图 */
    longView(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 近30天学习表现
            Column.create({ space: Spacing.SM });
            // 近30天学习表现
            Column.width('100%');
            // 近30天学习表现
            Column.padding(18);
            // 近30天学习表现
            Column.backgroundColor(Colors.CARD);
            // 近30天学习表现
            Column.borderRadius(Radius.LG);
            // 近30天学习表现
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('近30天学习表现');
            Text.fontSize(18);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('你的专注稳定性正在提升');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 曲线默认无数据点；点按 / 左右拖拽时显示当前点的日期与数值
            Stack.create({ alignContent: Alignment.TopStart });
            // 曲线默认无数据点；点按 / 左右拖拽时显示当前点的日期与数值
            Stack.width('100%');
            // 曲线默认无数据点；点按 / 左右拖拽时显示当前点的日期与数值
            Stack.height(150);
            // 曲线默认无数据点；点按 / 左右拖拽时显示当前点的日期与数值
            Stack.margin({ top: 8, bottom: 8 });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Canvas.create(this.lineCtx);
            Canvas.width('100%');
            Canvas.height(150);
            Canvas.onReady(() => {
                this.onLineChartReady();
            });
            Canvas.onTouch((e: TouchEvent) => {
                this.onChartTouch(e);
            });
        }, Canvas);
        Canvas.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.activeIndex >= 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width(104);
                        Column.padding({ top: 6, bottom: 6 });
                        Column.backgroundColor('#CC2F2A26');
                        Column.borderRadius(10);
                        Column.alignItems(HorizontalAlign.Center);
                        Column.position({ x: this.bubbleX, y: this.bubbleY });
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.activeDateLabel());
                        Text.fontSize(10);
                        Text.fontColor('#FFFFFF');
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`${this.activeMinutes()} 分钟`);
                        Text.fontSize(13);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontColor('#FFFFFF');
                        Text.margin({ top: 2 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        // 曲线默认无数据点；点按 / 左右拖拽时显示当前点的日期与数值
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ top: 8 });
        }, Row);
        this.statCard.bind(this)('学习', `${this.summary.totalHours}`, '小时');
        this.statCard.bind(this)('完成', `${this.summary.completedTasks}`, '个任务');
        this.statCard.bind(this)('专注率', `${this.summary.focusRate}`, '%');
        Row.pop();
        // 近30天学习表现
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 第二行：个人专注画像 + 练习内容总结
            Row.create({ space: Spacing.MD });
            // 第二行：个人专注画像 + 练习内容总结
            Row.width('100%');
            // 第二行：个人专注画像 + 练习内容总结
            Row.alignItems(VerticalAlign.Top);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.SM });
            Column.layoutWeight(1);
            Column.padding(14);
            Column.backgroundColor(Colors.CARD);
            Column.borderRadius(Radius.LG);
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('个人专注画像');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.canShowRadar) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        __Common__.create();
                        __Common__.margin({ top: 4 });
                    }, __Common__);
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new RadarChart(this, { values: this.dimValues, labels: this.dimLabels, chartSize: 150 }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Review.ets", line: 840, col: 11 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        values: this.dimValues,
                                        labels: this.dimLabels,
                                        chartSize: 150
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    values: this.dimValues, labels: this.dimLabels, chartSize: 150
                                });
                            }
                        }, { name: "RadarChart" });
                    }
                    __Common__.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.height(150);
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('🌱');
                        Text.fontSize(32);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('还在了解你');
                        Text.fontSize(14);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 6 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.SM });
            Column.layoutWeight(1);
            Column.padding(14);
            Column.backgroundColor(Colors.CARD);
            Column.borderRadius(Radius.LG);
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('练习内容总结');
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
            Text.create('›');
            Text.fontSize(20);
            Text.fontColor(Colors.TEXT_TERTIARY);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.practice.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = (_item, index: number) => {
                            const item = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Row.create();
                                Row.width('100%');
                                Row.padding({ top: 6, bottom: 6 });
                            }, Row);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Column.create();
                                Column.alignItems(HorizontalAlign.Start);
                                Column.layoutWeight(1);
                            }, Column);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(`${item.subject}：${item.content}`);
                                Text.fontSize(13);
                                Text.fontColor(Colors.TEXT_PRIMARY);
                            }, Text);
                            Text.pop();
                            Column.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(`${item.count}次`);
                                Text.fontSize(13);
                                Text.fontColor(Colors.TEXT_SECONDARY);
                            }, Text);
                            Text.pop();
                            Row.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.practice, forEachItemGenFunction, (item: PracticeSummaryItem, index: number) => `${item.subject}_${index}`, true, true);
                    }, ForEach);
                    ForEach.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: Spacing.SM });
                        Row.margin({ top: 6 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('全科稳步提升');
                        Text.fontSize(11);
                        Text.fontColor('#7FBF97');
                        Text.padding({ top: 4, bottom: 4, left: 8, right: 8 });
                        Text.backgroundColor('#E4F1E9');
                        Text.borderRadius(10);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('数学进步明显');
                        Text.fontSize(11);
                        Text.fontColor('#7FBF97');
                        Text.padding({ top: 4, bottom: 4, left: 8, right: 8 });
                        Text.backgroundColor('#E4F1E9');
                        Text.borderRadius(10);
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('暂无练习记录');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.margin({ top: 20, bottom: 20 });
                        Text.width('100%');
                        Text.textAlign(TextAlign.Center);
                    }, Text);
                    Text.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
        // 第二行：个人专注画像 + 练习内容总结
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // AI 学习建议
            Column.create({ space: Spacing.SM });
            // AI 学习建议
            Column.width('100%');
            // AI 学习建议
            Column.padding(18);
            // AI 学习建议
            Column.backgroundColor(Colors.CARD);
            // AI 学习建议
            Column.borderRadius(Radius.LG);
            // AI 学习建议
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.sectionHeader.bind(this)('💡', 'AI 学习建议');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.aiAdvice.length > 0 ? this.aiAdvice : '完成更多专注后，我会根据你的真实数据给出学习建议。');
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.lineHeight(22);
            Text.margin({ top: 6 });
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('查看详细报告');
            Button.type(ButtonType.Capsule);
            Button.fontSize(14);
            Button.fontColor('#FFFFFF');
            Button.backgroundColor('#7FBF97');
            Button.width('60%');
            Button.margin({ top: 10 });
            Button.onClick(() => {
                router.pushUrl({ url: 'pages/StudyReport' });
            });
        }, Button);
        Button.pop();
        // AI 学习建议
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 学习习惯洞察
            Column.create({ space: Spacing.SM });
            // 学习习惯洞察
            Column.width('100%');
            // 学习习惯洞察
            Column.padding(18);
            // 学习习惯洞察
            Column.backgroundColor(Colors.CARD);
            // 学习习惯洞察
            Column.borderRadius(Radius.LG);
            // 学习习惯洞察
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.sectionHeader.bind(this)('🕐', '学习习惯洞察');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.XS });
            Column.margin({ top: 4 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('最佳学习时段：');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.habit.bestWindow}（专注率 ${this.habit.bestRate}%）`);
            Text.fontSize(13);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('低谷时段：');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.habit.lowWindow}（${this.habit.lowNote}）`);
            Text.fontSize(13);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('习惯建议：');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.habit.advice);
            Text.fontSize(13);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.layoutWeight(1);
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
        // 学习习惯洞察
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 规划提升方案
            Button.createWithLabel('规划提升方案');
            // 规划提升方案
            Button.type(ButtonType.Capsule);
            // 规划提升方案
            Button.fontSize(16);
            // 规划提升方案
            Button.fontColor(Colors.TEXT_PRIMARY);
            // 规划提升方案
            Button.backgroundColor('#E4F1E9');
            // 规划提升方案
            Button.width('70%');
            // 规划提升方案
            Button.margin({ top: 8, bottom: 24 });
            // 规划提升方案
            Button.onClick(() => {
                router.pushUrl({ url: 'pages/TaskPlanning' });
            });
        }, Button);
        // 规划提升方案
        Button.pop();
    }
    /** 顶部栏：左侧标题（不再显示 iKnow）+ 右上角「日历图标 + 日期」下拉触发 */
    topBar(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.alignItems(VerticalAlign.Center);
            Row.padding({ top: 8, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.mode === 0 ? '长期学习总结' : '学习复盘');
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 6 });
            Row.padding({ left: 12, right: 12, top: 7, bottom: 7 });
            Row.backgroundColor(Colors.CARD);
            Row.borderRadius(16);
            Row.onClick(() => {
                this.pickDay();
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('📅');
            Text.fontSize(15);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.chipLabel());
            Text.fontSize(13);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.showPicker ? '▴' : '▾');
            Text.fontSize(11);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        Row.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.TopEnd });
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
            Column.create({ space: Spacing.MD });
            Column.padding(20);
            Column.width('100%');
        }, Column);
        this.topBar.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.mode === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.longView.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.dayView.bind(this)();
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
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 右上角下拉面板：遮罩 + 贴着日期 chip 下方弹出的面板
            if (this.showPicker) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.height('100%');
                        Column.backgroundColor('#22000000');
                        Column.onClick(() => {
                            this.showPicker = false;
                        });
                    }, Column);
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.margin({ top: 62, right: 16 });
                    }, Column);
                    this.pickerPanel.bind(this)();
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
        return "Review";
    }
}
registerNamedRoute(() => new Review(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Review", pageFullPath: "entry/src/main/ets/pages/Review", integratedHsp: "false", moduleType: "followWithHap" });
