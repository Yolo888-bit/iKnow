if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface TaskPlanning_Params {
    messages?: AIMessage[];
    turns?: number;
    showComposer?: boolean;
    tasks?: Task[];
    confirmedIds?: string[];
    thinking?: boolean;
    inputValue?: string;
    editId?: string;
    draftTitle?: string;
    draftSubject?: string;
    draftMinutes?: number;
    avatar?: string;
    scroller?: Scroller;
    history?: string[];
    userTexts?: string[];
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import type { PlanningInput, PlanningDialogInput } from '../services/ai/PlanningService';
import type { PlanTask } from '../models/StudyPlan';
import { AIMessage } from "@normalized:N&&&entry/src/main/ets/models/AIMessage&";
import { Task } from "@normalized:N&&&entry/src/main/ets/models/Task&";
import { MessageRole } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
import { AIFirstDisclaimer } from "@normalized:N&&&entry/src/main/ets/components/AIFirstDisclaimer&";
import { UserAvatar } from "@normalized:N&&&entry/src/main/ets/components/UserAvatar&";
export class TaskPlanning extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__messages = new ObservedPropertyObjectPU([]
        /** 用户已发言轮数（兜底用：聊太多轮还没出计划就直接生成） */
        , this, "messages");
        this.__turns = new ObservedPropertySimplePU(0
        /** 出计划后是否仍显示输入框（用户点「继续调整」时置 true） */
        , this, "turns");
        this.__showComposer = new ObservedPropertySimplePU(false, this, "showComposer");
        this.__tasks = new ObservedPropertyObjectPU([]
        /** 已点击确认（圆圈变实心）的任务 id */
        , this, "tasks");
        this.__confirmedIds = new ObservedPropertyObjectPU([], this, "confirmedIds");
        this.__thinking = new ObservedPropertySimplePU(false, this, "thinking");
        this.__inputValue = new ObservedPropertySimplePU(''
        /** 正在编辑的任务 id（空串表示未编辑） */
        , this, "inputValue");
        this.__editId = new ObservedPropertySimplePU('', this, "editId");
        this.__draftTitle = new ObservedPropertySimplePU('', this, "draftTitle");
        this.__draftSubject = new ObservedPropertySimplePU('', this, "draftSubject");
        this.__draftMinutes = new ObservedPropertySimplePU(30, this, "draftMinutes");
        this.__avatar = this.createStorageProp(StorageKey.USER_AVATAR, '🧑‍🎓', "avatar");
        this.scroller = new Scroller();
        this.history = [];
        this.userTexts = [];
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: TaskPlanning_Params) {
        if (params.messages !== undefined) {
            this.messages = params.messages;
        }
        if (params.turns !== undefined) {
            this.turns = params.turns;
        }
        if (params.showComposer !== undefined) {
            this.showComposer = params.showComposer;
        }
        if (params.tasks !== undefined) {
            this.tasks = params.tasks;
        }
        if (params.confirmedIds !== undefined) {
            this.confirmedIds = params.confirmedIds;
        }
        if (params.thinking !== undefined) {
            this.thinking = params.thinking;
        }
        if (params.inputValue !== undefined) {
            this.inputValue = params.inputValue;
        }
        if (params.editId !== undefined) {
            this.editId = params.editId;
        }
        if (params.draftTitle !== undefined) {
            this.draftTitle = params.draftTitle;
        }
        if (params.draftSubject !== undefined) {
            this.draftSubject = params.draftSubject;
        }
        if (params.draftMinutes !== undefined) {
            this.draftMinutes = params.draftMinutes;
        }
        if (params.scroller !== undefined) {
            this.scroller = params.scroller;
        }
        if (params.history !== undefined) {
            this.history = params.history;
        }
        if (params.userTexts !== undefined) {
            this.userTexts = params.userTexts;
        }
    }
    updateStateVars(params: TaskPlanning_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__messages.purgeDependencyOnElmtId(rmElmtId);
        this.__turns.purgeDependencyOnElmtId(rmElmtId);
        this.__showComposer.purgeDependencyOnElmtId(rmElmtId);
        this.__tasks.purgeDependencyOnElmtId(rmElmtId);
        this.__confirmedIds.purgeDependencyOnElmtId(rmElmtId);
        this.__thinking.purgeDependencyOnElmtId(rmElmtId);
        this.__inputValue.purgeDependencyOnElmtId(rmElmtId);
        this.__editId.purgeDependencyOnElmtId(rmElmtId);
        this.__draftTitle.purgeDependencyOnElmtId(rmElmtId);
        this.__draftSubject.purgeDependencyOnElmtId(rmElmtId);
        this.__draftMinutes.purgeDependencyOnElmtId(rmElmtId);
        this.__avatar.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__messages.aboutToBeDeleted();
        this.__turns.aboutToBeDeleted();
        this.__showComposer.aboutToBeDeleted();
        this.__tasks.aboutToBeDeleted();
        this.__confirmedIds.aboutToBeDeleted();
        this.__thinking.aboutToBeDeleted();
        this.__inputValue.aboutToBeDeleted();
        this.__editId.aboutToBeDeleted();
        this.__draftTitle.aboutToBeDeleted();
        this.__draftSubject.aboutToBeDeleted();
        this.__draftMinutes.aboutToBeDeleted();
        this.__avatar.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __messages: ObservedPropertyObjectPU<AIMessage[]>;
    get messages() {
        return this.__messages.get();
    }
    set messages(newValue: AIMessage[]) {
        this.__messages.set(newValue);
    }
    /** 用户已发言轮数（兜底用：聊太多轮还没出计划就直接生成） */
    private __turns: ObservedPropertySimplePU<number>;
    get turns() {
        return this.__turns.get();
    }
    set turns(newValue: number) {
        this.__turns.set(newValue);
    }
    /** 出计划后是否仍显示输入框（用户点「继续调整」时置 true） */
    private __showComposer: ObservedPropertySimplePU<boolean>;
    get showComposer() {
        return this.__showComposer.get();
    }
    set showComposer(newValue: boolean) {
        this.__showComposer.set(newValue);
    }
    private __tasks: ObservedPropertyObjectPU<Task[]>;
    get tasks() {
        return this.__tasks.get();
    }
    set tasks(newValue: Task[]) {
        this.__tasks.set(newValue);
    }
    /** 已点击确认（圆圈变实心）的任务 id */
    private __confirmedIds: ObservedPropertyObjectPU<string[]>;
    get confirmedIds() {
        return this.__confirmedIds.get();
    }
    set confirmedIds(newValue: string[]) {
        this.__confirmedIds.set(newValue);
    }
    private __thinking: ObservedPropertySimplePU<boolean>;
    get thinking() {
        return this.__thinking.get();
    }
    set thinking(newValue: boolean) {
        this.__thinking.set(newValue);
    }
    private __inputValue: ObservedPropertySimplePU<string>;
    get inputValue() {
        return this.__inputValue.get();
    }
    set inputValue(newValue: string) {
        this.__inputValue.set(newValue);
    }
    /** 正在编辑的任务 id（空串表示未编辑） */
    private __editId: ObservedPropertySimplePU<string>;
    get editId() {
        return this.__editId.get();
    }
    set editId(newValue: string) {
        this.__editId.set(newValue);
    }
    private __draftTitle: ObservedPropertySimplePU<string>;
    get draftTitle() {
        return this.__draftTitle.get();
    }
    set draftTitle(newValue: string) {
        this.__draftTitle.set(newValue);
    }
    private __draftSubject: ObservedPropertySimplePU<string>;
    get draftSubject() {
        return this.__draftSubject.get();
    }
    set draftSubject(newValue: string) {
        this.__draftSubject.set(newValue);
    }
    private __draftMinutes: ObservedPropertySimplePU<number>;
    get draftMinutes() {
        return this.__draftMinutes.get();
    }
    set draftMinutes(newValue: number) {
        this.__draftMinutes.set(newValue);
    }
    private __avatar: ObservedPropertyAbstractPU<string>;
    get avatar() {
        return this.__avatar.get();
    }
    set avatar(newValue: string) {
        this.__avatar.set(newValue);
    }
    private scroller: Scroller;
    /** 传给 AI 的历史对话，按 [user, ai, user, ai, ...] 交替存放 */
    private history: string[];
    /** 用户说过的原话，兜底生成计划时拼成目标 */
    private userTexts: string[];
    aboutToAppear(): void {
        this.pushAI(AIService.getInstance().planningIntro());
    }
    // ---------- 消息 ----------
    private pushAI(content: string): void {
        const m = new AIMessage();
        m.id = IdUtils.uuid();
        m.role = MessageRole.AI;
        m.content = content;
        m.timestamp = Date.now();
        this.messages.push(m);
        this.scrollToBottom();
    }
    private pushUser(content: string): void {
        const m = new AIMessage();
        m.id = IdUtils.uuid();
        m.role = MessageRole.USER;
        m.content = content;
        m.timestamp = Date.now();
        this.messages.push(m);
        this.scrollToBottom();
    }
    /** 新消息后滚到底部，保持「聊天跟手」 */
    private scrollToBottom(): void {
        setTimeout(() => {
            this.scroller.scrollEdge(Edge.Bottom);
        }, 80);
    }
    // ---------- 对话流程（AI 驱动，不再固定轮数）----------
    /**
     * 每次发言都带完整历史调用 task_dialog：
     *  - 模型正常聊天、按需追问；
     *  - 一旦判断信息够了，直接返回 done=true + tasks → 立刻出计划；
     *  - 聊满 4 轮仍未给计划 → 兜底走 task_plan 直接拆任务。
     */
    private async send(): Promise<void> {
        const text = this.inputValue.trim();
        if (text.length === 0 || this.thinking) {
            return;
        }
        this.inputValue = '';
        this.pushUser(text);
        this.userTexts.push(text);
        this.turns += 1;
        this.thinking = true;
        const input: PlanningDialogInput = { step: this.turns, userInput: text, history: this.history };
        const r = await AIService.getInstance().dialogByScene(input);
        this.thinking = false;
        const reply: string = r.reply.length > 0 ? r.reply : AIService.getInstance().planningHold();
        this.pushAI(reply);
        this.history.push(text);
        this.history.push(reply);
        // 模型判断信息足够：reply 里已含时间安排建议，直接落到待确认列表
        const got: PlanTask[] | undefined = r.tasks;
        if (r.done && got !== undefined && got.length > 0) {
            this.applyPlan(got);
            return;
        }
        // 兜底：聊满 4 轮还没出计划，就按已收集的信息直接生成
        if (this.turns >= 4) {
            await this.generatePlan();
        }
    }
    /** 把 AI 给出的结构化任务落到「待确认任务」列表 */
    private applyPlan(list: PlanTask[]): void {
        const out: Task[] = [];
        for (const p of list) {
            out.push(this.toTask(p));
        }
        if (out.length === 0) {
            return;
        }
        this.tasks = out;
        this.confirmedIds = [];
        this.showComposer = false;
    }
    private composeGoal(): string {
        return this.userTexts.join('；');
    }
    /** 兜底路径：直接按已收集的目标生成结构化任务（task_plan 场景） */
    private async generatePlan(): Promise<void> {
        this.thinking = true;
        const input: PlanningInput = { goal: this.composeGoal() };
        const result = await AIService.getInstance().planByScene(input);
        this.thinking = false;
        if (result.tasks.length === 0) {
            this.pushAI(AIService.getInstance().planningHold());
            return;
        }
        if (result.summary.length > 0) {
            this.pushAI(result.summary);
        }
        this.applyPlan(result.tasks);
    }
    private toTask(p: PlanTask): Task {
        const t = new Task();
        t.id = p.id.length > 0 ? p.id : IdUtils.uuid();
        t.title = p.title;
        t.subject = p.subject;
        t.estimatedDuration = p.estimatedDuration;
        t.sortOrder = p.sortOrder;
        t.createdAt = Date.now();
        return t;
    }
    // ---------- 待确认任务：确认 / 编辑 ----------
    private isConfirmed(id: string): boolean {
        return this.confirmedIds.indexOf(id) >= 0;
    }
    private toggleConfirm(id: string): void {
        const next: string[] = [];
        let found = false;
        for (const x of this.confirmedIds) {
            if (x === id) {
                found = true;
            }
            else {
                next.push(x);
            }
        }
        if (!found) {
            next.push(id);
        }
        this.confirmedIds = next;
    }
    private startEdit(t: Task): void {
        this.editId = t.id;
        this.draftTitle = t.title;
        this.draftSubject = t.subject;
        this.draftMinutes = t.estimatedDuration;
    }
    private saveEdit(): void {
        const title = this.draftTitle.trim();
        const subject = this.draftSubject.trim();
        const next: Task[] = [];
        for (const t of this.tasks) {
            const c = t.copy();
            if (c.id === this.editId) {
                c.title = title.length > 0 ? title : c.title;
                c.subject = subject.length > 0 ? subject : c.subject;
                c.estimatedDuration = this.draftMinutes;
            }
            next.push(c);
        }
        this.tasks = next;
        this.editId = '';
    }
    private deleteTask(): void {
        const next: Task[] = [];
        for (const t of this.tasks) {
            if (t.id !== this.editId) {
                next.push(t);
            }
        }
        this.tasks = next;
        this.editId = '';
    }
    // ---------- 底部：预计时长 / 开始专注 ----------
    private selectedTasks(): Task[] {
        if (this.confirmedIds.length === 0) {
            return this.tasks;
        }
        const out: Task[] = [];
        for (const t of this.tasks) {
            if (this.isConfirmed(t.id)) {
                out.push(t);
            }
        }
        return out;
    }
    private plannedMinutes(): number {
        let sum = 0;
        for (const t of this.selectedTasks()) {
            sum += t.estimatedDuration;
        }
        return sum;
    }
    private confirmStart(): void {
        const selected = this.selectedTasks();
        if (selected.length === 0) {
            promptAction.showToast({ message: '至少保留一个任务' });
            return;
        }
        AppStore.getInstance().setCurrentPlan(selected);
        router.replaceUrl({ url: 'pages/Focus' });
    }
    // ---------- 视图 ----------
    header(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.alignItems(VerticalAlign.Center);
            Row.padding({ left: 18, right: 16, top: 14, bottom: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 左：品牌（固定占位，保证中间标题真正居中）
            Row.create();
            // 左：品牌（固定占位，保证中间标题真正居中）
            Row.width(58);
            // 左：品牌（固定占位，保证中间标题真正居中）
            Row.justifyContent(FlexAlign.Start);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('iKnow');
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.PRIMARY);
            Text.fontStyle(FontStyle.Italic);
        }, Text);
        Text.pop();
        // 左：品牌（固定占位，保证中间标题真正居中）
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 中：标题 + 在线徽标
            Column.create();
            // 中：标题 + 在线徽标
            Column.layoutWeight(1);
            // 中：标题 + 在线徽标
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 任务规划');
            Text.fontSize(19);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.padding({ left: 10, right: 12, top: 3, bottom: 3 });
            Row.backgroundColor(Colors.ONLINE_SOFT);
            Row.borderRadius(10);
            Row.margin({ top: 5 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(6);
            Circle.height(6);
            Circle.fill(Colors.ONLINE_DOT);
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 助手在线');
            Text.fontSize(11);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ left: 5 });
        }, Text);
        Text.pop();
        Row.pop();
        // 中：标题 + 在线徽标
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 右：用户头像
            Row.create();
            // 右：用户头像
            Row.width(58);
            // 右：用户头像
            Row.justifyContent(FlexAlign.End);
        }, Row);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new UserAvatar(this, { avatar: this.avatar, diameter: 38, radius: 10, bg: Colors.PRIMARY_SOFT }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/TaskPlanning.ets", line: 298, col: 9 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            avatar: this.avatar,
                            diameter: 38,
                            radius: 10,
                            bg: Colors.PRIMARY_SOFT
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        avatar: this.avatar, diameter: 38, radius: 10, bg: Colors.PRIMARY_SOFT
                    });
                }
            }, { name: "UserAvatar" });
        }
        // 右：用户头像
        Row.pop();
        Row.pop();
    }
    aiBubble(content: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.width('100%');
            Row.alignItems(VerticalAlign.Top);
            Row.justifyContent(FlexAlign.Start);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // AI 头像：深色圆 + "AI"
            Stack.create();
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(34);
            Circle.height(34);
            Circle.fill(Colors.AI_AVATAR_BG);
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI');
            Text.fontSize(13);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        // AI 头像：深色圆 + "AI"
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(content);
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.lineHeight(23);
            Text.backgroundColor(Colors.BUBBLE_AI);
            Text.padding({ left: 14, right: 14, top: 11, bottom: 11 });
            Text.borderRadius(14);
            Text.constraintSize({ maxWidth: '74%' });
        }, Text);
        Text.pop();
        Row.pop();
    }
    userBubble(content: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.width('100%');
            Row.alignItems(VerticalAlign.Top);
            Row.justifyContent(FlexAlign.End);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(content);
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.lineHeight(23);
            Text.backgroundColor(Colors.BUBBLE_USER);
            Text.padding({ left: 14, right: 14, top: 11, bottom: 11 });
            Text.borderRadius(14);
            Text.constraintSize({ maxWidth: '74%' });
        }, Text);
        Text.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 用户头像（emoji 或相册照片，右上角与工作台一致）
                    UserAvatar(this, { avatar: this.avatar, diameter: 34, radius: 10, bg: Colors.PRIMARY_SOFT }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/TaskPlanning.ets", line: 348, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            avatar: this.avatar,
                            diameter: 34,
                            radius: 10,
                            bg: Colors.PRIMARY_SOFT
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        avatar: this.avatar, diameter: 34, radius: 10, bg: Colors.PRIMARY_SOFT
                    });
                }
            }, { name: "UserAvatar" });
        }
        Row.pop();
    }
    planRow(t: Task, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 12 });
            Row.width('100%');
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 圆圈确认：点击后变实心
            Stack.create();
            // 圆圈确认：点击后变实心
            Stack.onClick(() => {
                this.toggleConfirm(t.id);
            });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(20);
            Circle.height(20);
            Circle.fill(this.isConfirmed(t.id) ? Colors.CHAT_ACTION : Color.Transparent);
            Circle.stroke(this.isConfirmed(t.id) ? Colors.CHAT_ACTION : Colors.TEXT_TERTIARY);
            Circle.strokeWidth(1.5);
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isConfirmed(t.id)) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('✓');
                        Text.fontSize(12);
                        Text.fontColor(Color.White);
                        Text.fontWeight(FontWeight.Bold);
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
        // 圆圈确认：点击后变实心
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 点文字进入编辑（截图里不额外显示按钮，保持简洁）
            Text.create(t.title);
            // 点文字进入编辑（截图里不额外显示按钮，保持简洁）
            Text.fontSize(15);
            // 点文字进入编辑（截图里不额外显示按钮，保持简洁）
            Text.fontColor(Colors.TEXT_PRIMARY);
            // 点文字进入编辑（截图里不额外显示按钮，保持简洁）
            Text.layoutWeight(1);
            // 点文字进入编辑（截图里不额外显示按钮，保持简洁）
            Text.onClick(() => {
                this.startEdit(t);
            });
        }, Text);
        // 点文字进入编辑（截图里不额外显示按钮，保持简洁）
        Text.pop();
        Row.pop();
    }
    planSection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('待确认任务');
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.textAlign(TextAlign.Center);
            Text.margin({ top: 6, bottom: 16 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 16 });
            Column.width('100%');
            Column.padding({ left: 12, right: 12 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const t = _item;
                this.planRow.bind(this)(t);
            };
            this.forEachUpdateFunction(elmtId, this.tasks, forEachItemGenFunction, (t: Task) => t.id, false, false);
        }, ForEach);
        ForEach.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 出计划后仍可回到对话，继续让 AI 调整安排
            if (!this.showComposer) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('💬 继续和 AI 考伴调整');
                        Text.fontSize(12);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.width('100%');
                        Text.textAlign(TextAlign.Center);
                        Text.margin({ top: 16 });
                        Text.onClick(() => {
                            this.showComposer = true;
                        });
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
        Column.pop();
    }
    editPanel(parent = null) {
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
            Column.width('86%');
            Column.padding(24);
            Column.backgroundColor(Colors.CARD);
            Column.borderRadius(Radius.LG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('编辑任务');
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '任务名称', text: this.draftTitle });
            TextInput.fontSize(15);
            TextInput.height(46);
            TextInput.margin({ top: 16 });
            TextInput.backgroundColor(Colors.BG);
            TextInput.borderRadius(Radius.MD);
            TextInput.onChange((v: string) => {
                this.draftTitle = v;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '科目', text: this.draftSubject });
            TextInput.fontSize(15);
            TextInput.height(46);
            TextInput.margin({ top: 10 });
            TextInput.backgroundColor(Colors.BG);
            TextInput.borderRadius(Radius.MD);
            TextInput.onChange((v: string) => {
                this.draftSubject = v;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.margin({ top: 16 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('预计时长');
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('−');
            Button.width(34);
            Button.height(34);
            Button.fontSize(16);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.BG);
            Button.borderRadius(17);
            Button.onClick(() => {
                if (this.draftMinutes > 5) {
                    this.draftMinutes -= 5;
                }
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.draftMinutes} 分钟`);
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width(76);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('＋');
            Button.width(34);
            Button.height(34);
            Button.fontSize(16);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.BG);
            Button.borderRadius(17);
            Button.onClick(() => {
                if (this.draftMinutes < 240) {
                    this.draftMinutes += 5;
                }
            });
        }, Button);
        Button.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 12 });
            Row.width('100%');
            Row.margin({ top: 22 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('删除');
            Button.layoutWeight(1);
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Colors.CAMERA_RED);
            Button.backgroundColor(Colors.BG);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                this.deleteTask();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('取消');
            Button.layoutWeight(1);
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_SECONDARY);
            Button.backgroundColor(Colors.BG);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                this.editId = '';
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('保存');
            Button.layoutWeight(1);
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.CHAT_ACTION);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                this.saveEdit();
            });
        }, Button);
        Button.pop();
        Row.pop();
        Column.pop();
        Column.pop();
    }
    inputBar(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.width('100%');
            Row.padding({ left: 16, right: 16, top: 10, bottom: 16 });
            Row.backgroundColor(Colors.BG);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '说说你今天想学什么…', text: this.inputValue });
            TextInput.fontSize(15);
            TextInput.height(44);
            TextInput.layoutWeight(1);
            TextInput.backgroundColor(Colors.CARD);
            TextInput.borderRadius(22);
            TextInput.onChange((v: string) => {
                this.inputValue = v;
            });
            TextInput.onSubmit(() => {
                this.send();
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('发送');
            Button.height(44);
            Button.fontSize(15);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.CHAT_ACTION);
            Button.borderRadius(22);
            Button.padding({ left: 18, right: 18 });
            Button.onClick(() => {
                this.send();
            });
        }, Button);
        Button.pop();
        Row.pop();
    }
    startBar(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding({ left: 22, right: 22, top: 12, bottom: 16 });
            Column.backgroundColor(Colors.BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.margin({ bottom: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(18);
            Circle.height(18);
            Circle.fill(Colors.CHAT_ACTION);
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('✓');
            Text.fontSize(11);
            Text.fontColor(Color.White);
            Text.fontWeight(FontWeight.Bold);
        }, Text);
        Text.pop();
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`进入 ${this.plannedMinutes()} 分钟专注学习`);
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('确认并开始专注学习');
            Button.width('100%');
            Button.height(52);
            Button.fontSize(17);
            Button.fontWeight(FontWeight.Medium);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.CHAT_ACTION);
            Button.borderRadius(26);
            Button.onClick(() => {
                this.confirmStart();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 将在学习过程中提醒你节奏与复盘节点');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.margin({ top: 10 });
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
            Column.create();
            Column.width('100%');
            Column.height('100%');
        }, Column);
        this.header.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 对话 + 待确认任务
            Scroll.create(this.scroller);
            // 对话 + 待确认任务
            Scroll.layoutWeight(1);
            // 对话 + 待确认任务
            Scroll.align(Alignment.Top);
            // 对话 + 待确认任务
            Scroll.scrollBar(BarState.Off);
            // 对话 + 待确认任务
            Scroll.edgeEffect(EdgeEffect.Spring);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 18 });
            Column.width('100%');
            Column.padding({ left: 16, right: 16, top: 10, bottom: 18 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const m = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (m.role === MessageRole.AI) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.aiBubble.bind(this)(m.content);
                        });
                    }
                    else {
                        this.ifElseBranchUpdateFunction(1, () => {
                            this.userBubble.bind(this)(m.content);
                        });
                    }
                }, If);
                If.pop();
            };
            this.forEachUpdateFunction(elmtId, this.messages, forEachItemGenFunction, (m: AIMessage) => m.id, false, false);
        }, ForEach);
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.thinking) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.aiBubble.bind(this)('正在思考…');
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.tasks.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.planSection.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
        // 对话 + 待确认任务
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 底部：出计划后固定「开始专注」，否则为输入栏
            if (this.tasks.length > 0 && !this.showComposer) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.startBar.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.inputBar.bind(this)();
                });
            }
        }, If);
        If.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.editId.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.editPanel.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new AIFirstDisclaimer(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/TaskPlanning.ets", line: 660, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {};
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {});
                }
            }, { name: "AIFirstDisclaimer" });
        }
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "TaskPlanning";
    }
}
registerNamedRoute(() => new TaskPlanning(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/TaskPlanning", pageFullPath: "entry/src/main/ets/pages/TaskPlanning", integratedHsp: "false", moduleType: "followWithHap" });
