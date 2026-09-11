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
    dimLabels?: string[];
    chartSettings?: RenderingContextSettings;
    lineCtx?: CanvasRenderingContext2D;
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { Metrics } from "@normalized:N&&&entry/src/main/ets/services/Metrics&";
import type { Last30DaysSummary, PracticeSummaryItem, HabitInsight } from "@normalized:N&&&entry/src/main/ets/services/Metrics&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { FocusProfile } from "@normalized:N&&&entry/src/main/ets/models/FocusProfile&";
import { RadarChart } from "@normalized:N&&&entry/src/main/ets/components/RadarChart&";
import type { FocusSession } from '../models/FocusSession';
import type { Task } from '../models/Task';
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
        this.__canShowRadar = new ObservedPropertySimplePU(false, this, "canShowRadar");
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
    }
    aboutToBeDeleted() {
        this.__summary.aboutToBeDeleted();
        this.__practice.aboutToBeDeleted();
        this.__habit.aboutToBeDeleted();
        this.__aiAdvice.aboutToBeDeleted();
        this.__profile.aboutToBeDeleted();
        this.__dimValues.aboutToBeDeleted();
        this.__canShowRadar.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
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
        // 渐变填充区域
        c.beginPath();
        c.moveTo(points[0][0], padTop + chartH);
        for (const p of points) {
            c.lineTo(p[0], p[1]);
        }
        c.lineTo(points[points.length - 1][0], padTop + chartH);
        c.closePath();
        const grad = c.createLinearGradient(0, padTop, 0, padTop + chartH);
        grad.addColorStop(0, 'rgba(127,191,151,0.35)');
        grad.addColorStop(1, 'rgba(127,191,151,0.02)');
        c.fillStyle = grad;
        c.fill();
        // 折线
        c.beginPath();
        for (let i = 0; i < points.length; i++) {
            const p = points[i];
            if (i === 0) {
                c.moveTo(p[0], p[1]);
            }
            else {
                c.lineTo(p[0], p[1]);
            }
        }
        c.strokeStyle = '#7FBF97';
        c.lineWidth = 3;
        c.lineJoin = 'round';
        c.lineCap = 'round';
        c.stroke();
        // 顶点
        for (const p of points) {
            c.beginPath();
            c.arc(p[0], p[1], 4, 0, Math.PI * 2);
            c.fillStyle = '#FFFFFF';
            c.fill();
            c.lineWidth = 2;
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
    initialRender() {
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
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部标题栏
            Row.create();
            // 顶部标题栏
            Row.width('100%');
            // 顶部标题栏
            Row.padding({ top: 8, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('iKnow');
            Text.fontSize(22);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('长期学习总结');
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
            Text.create('📅');
            Text.fontSize(22);
        }, Text);
        Text.pop();
        // 顶部标题栏
        Row.pop();
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
            Canvas.create(this.lineCtx);
            Canvas.width('100%');
            Canvas.height(150);
            Canvas.margin({ top: 8, bottom: 8 });
            Canvas.onReady(() => {
                this.onLineChartReady();
            });
        }, Canvas);
        Canvas.pop();
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
            // 个人专注画像
            Column.create({ space: Spacing.SM });
            // 个人专注画像
            Column.layoutWeight(1);
            // 个人专注画像
            Column.padding(14);
            // 个人专注画像
            Column.backgroundColor(Colors.CARD);
            // 个人专注画像
            Column.borderRadius(Radius.LG);
            // 个人专注画像
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
                                let componentCall = new RadarChart(this, { values: this.dimValues, labels: this.dimLabels, chartSize: 150 }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Review.ets", line: 251, col: 15 });
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
        // 个人专注画像
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 练习内容总结
            Column.create({ space: Spacing.SM });
            // 练习内容总结
            Column.layoutWeight(1);
            // 练习内容总结
            Column.padding(14);
            // 练习内容总结
            Column.backgroundColor(Colors.CARD);
            // 练习内容总结
            Column.borderRadius(Radius.LG);
            // 练习内容总结
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
        // 练习内容总结
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
    static getEntryName(): string {
        return "Review";
    }
}
registerNamedRoute(() => new Review(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Review", pageFullPath: "entry/src/main/ets/pages/Review", integratedHsp: "false", moduleType: "followWithHap" });
