if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface TaskPlanning_Params {
    messages?: AIMessage[];
    plan?: Task[];
    step?: number;
    goalText?: string;
    inputValue?: string;
    planning?: boolean;
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { AIMessage } from "@normalized:N&&&entry/src/main/ets/models/AIMessage&";
import { Task } from "@normalized:N&&&entry/src/main/ets/models/Task&";
import { MessageRole, TaskStatus } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
import { AITag } from "@normalized:N&&&entry/src/main/ets/components/AITag&";
export class TaskPlanning extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__messages = new ObservedPropertyObjectPU([], this, "messages");
        this.__plan = new ObservedPropertyObjectPU([], this, "plan");
        this.__step = new ObservedPropertySimplePU(0, this, "step");
        this.__goalText = new ObservedPropertySimplePU('', this, "goalText");
        this.__inputValue = new ObservedPropertySimplePU('', this, "inputValue");
        this.__planning = new ObservedPropertySimplePU(false, this, "planning");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: TaskPlanning_Params) {
        if (params.messages !== undefined) {
            this.messages = params.messages;
        }
        if (params.plan !== undefined) {
            this.plan = params.plan;
        }
        if (params.step !== undefined) {
            this.step = params.step;
        }
        if (params.goalText !== undefined) {
            this.goalText = params.goalText;
        }
        if (params.inputValue !== undefined) {
            this.inputValue = params.inputValue;
        }
        if (params.planning !== undefined) {
            this.planning = params.planning;
        }
    }
    updateStateVars(params: TaskPlanning_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__messages.purgeDependencyOnElmtId(rmElmtId);
        this.__plan.purgeDependencyOnElmtId(rmElmtId);
        this.__step.purgeDependencyOnElmtId(rmElmtId);
        this.__goalText.purgeDependencyOnElmtId(rmElmtId);
        this.__inputValue.purgeDependencyOnElmtId(rmElmtId);
        this.__planning.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__messages.aboutToBeDeleted();
        this.__plan.aboutToBeDeleted();
        this.__step.aboutToBeDeleted();
        this.__goalText.aboutToBeDeleted();
        this.__inputValue.aboutToBeDeleted();
        this.__planning.aboutToBeDeleted();
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
    private __plan: ObservedPropertyObjectPU<Task[]>;
    get plan() {
        return this.__plan.get();
    }
    set plan(newValue: Task[]) {
        this.__plan.set(newValue);
    }
    private __step: ObservedPropertySimplePU<number>;
    get step() {
        return this.__step.get();
    }
    set step(newValue: number) {
        this.__step.set(newValue);
    }
    private __goalText: ObservedPropertySimplePU<string>;
    get goalText() {
        return this.__goalText.get();
    }
    set goalText(newValue: string) {
        this.__goalText.set(newValue);
    }
    private __inputValue: ObservedPropertySimplePU<string>;
    get inputValue() {
        return this.__inputValue.get();
    }
    set inputValue(newValue: string) {
        this.__inputValue.set(newValue);
    }
    private __planning: ObservedPropertySimplePU<boolean>;
    get planning() {
        return this.__planning.get();
    }
    set planning(newValue: boolean) {
        this.__planning.set(newValue);
    }
    aboutToAppear(): void {
        this.pushAI(AIService.getInstance().openPlanning());
    }
    private pushAI(content: string): void {
        const m = new AIMessage();
        m.id = IdUtils.uuid();
        m.role = MessageRole.AI;
        m.content = content;
        m.timestamp = Date.now();
        this.messages.push(m);
    }
    private pushUser(content: string): void {
        const m = new AIMessage();
        m.id = IdUtils.uuid();
        m.role = MessageRole.USER;
        m.content = content;
        m.timestamp = Date.now();
        this.messages.push(m);
    }
    private async send(): Promise<void> {
        const text = this.inputValue.trim();
        if (text.length === 0) {
            return;
        }
        this.inputValue = '';
        this.pushUser(text);
        if (this.step === 0) {
            this.goalText = text;
            this.step = 1;
            this.pushAI(AIService.getInstance().nextPlanningQuestion(0));
        }
        else {
            this.step = 2;
            this.pushAI('好的，我帮你安排一下。');
            this.planning = true;
            const tasks = await AppStore.getInstance().planTasks(this.goalText);
            this.plan = tasks;
            this.planning = false;
            this.pushAI(`我帮你拆成了 ${tasks.length} 个小任务，你可以勾选、删除或添加，确认后再开始。`);
        }
    }
    private toggle(id: string): void {
        const next: Task[] = [];
        for (const t of this.plan) {
            const c = t.copy();
            if (c.id === id) {
                c.done = !c.done;
                c.status = c.done ? TaskStatus.DONE : TaskStatus.TODO;
            }
            next.push(c);
        }
        this.plan = next;
    }
    private removeTask(id: string): void {
        const next: Task[] = [];
        for (const t of this.plan) {
            if (t.id !== id) {
                next.push(t);
            }
        }
        this.plan = next;
    }
    private addTask(): void {
        const t = new Task();
        t.id = IdUtils.uuid();
        t.title = '新任务';
        t.subject = '综合';
        t.estimatedDuration = 25;
        t.sortOrder = this.plan.length;
        t.createdAt = Date.now();
        this.plan.push(t);
    }
    private confirm(): void {
        AppStore.getInstance().setCurrentPlan(this.plan);
        router.replaceUrl({ url: 'pages/Focus' });
    }
    bubble(m: AIMessage, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (m.role === MessageRole.AI) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.width('100%');
                        Row.justifyContent(FlexAlign.Start);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('💡');
                        Text.fontSize(16);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(m.content);
                        Text.fontSize(15);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.backgroundColor(Colors.CARD);
                        Text.padding(12);
                        Text.borderRadius(16);
                        Text.constraintSize({ maxWidth: '78%' });
                        Text.margin({ left: 8 });
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.width('100%');
                        Row.justifyContent(FlexAlign.End);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(m.content);
                        Text.fontSize(15);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.backgroundColor(Colors.PRIMARY_SOFT);
                        Text.padding(12);
                        Text.borderRadius(16);
                        Text.constraintSize({ maxWidth: '78%' });
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
        }, If);
        If.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(Colors.BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部标题
            Row.create();
            // 顶部标题
            Row.width('100%');
            // 顶部标题
            Row.padding({ left: 20, right: 20, top: 16, bottom: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 任务规划');
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Bold);
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
                    let componentCall = new AITag(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/TaskPlanning.ets", line: 146, col: 9 });
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
        // 顶部标题
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 对话 + 计划
            Scroll.create();
            // 对话 + 计划
            Scroll.layoutWeight(1);
            // 对话 + 计划
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.MD });
            Column.padding(20);
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const m = _item;
                this.bubble.bind(this)(m);
            };
            this.forEachUpdateFunction(elmtId, this.messages, forEachItemGenFunction, (m: AIMessage) => m.id, false, false);
        }, ForEach);
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.planning) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('小伴思考中…');
                        Text.fontSize(13);
                        Text.fontColor(Colors.TEXT_TERTIARY);
                        Text.margin({ left: 24 });
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
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.plan.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.padding(16);
                        Column.backgroundColor(Colors.BG);
                        Column.borderRadius(Radius.LG);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('今日学习计划');
                        Text.fontSize(16);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                        Text.width('100%');
                        Text.margin({ top: 8, bottom: 12 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const task = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Row.create();
                                Row.width('100%');
                                Row.padding(14);
                                Row.backgroundColor(Colors.CARD);
                                Row.borderRadius(Radius.MD);
                            }, Row);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Checkbox.create();
                                Checkbox.select(task.done);
                                Checkbox.selectedColor(Colors.PRIMARY);
                                Checkbox.width(22);
                                Checkbox.height(22);
                                Checkbox.onChange((val: boolean) => {
                                    this.toggle(task.id);
                                });
                            }, Checkbox);
                            Checkbox.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Column.create();
                                Column.alignItems(HorizontalAlign.Start);
                                Column.margin({ left: 12 });
                                Column.layoutWeight(1);
                            }, Column);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(task.title);
                                Text.fontSize(15);
                                Text.fontColor(task.done ? Colors.TEXT_TERTIARY : Colors.TEXT_PRIMARY);
                            }, Text);
                            Text.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(`${task.subject} · ${task.estimatedDuration} min`);
                                Text.fontSize(12);
                                Text.fontColor(Colors.TEXT_SECONDARY);
                                Text.margin({ top: 4 });
                            }, Text);
                            Text.pop();
                            Column.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('×');
                                Text.fontSize(20);
                                Text.fontColor(Colors.TEXT_TERTIARY);
                                Text.padding(6);
                                Text.onClick(() => {
                                    this.removeTask(task.id);
                                });
                            }, Text);
                            Text.pop();
                            Row.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.plan, forEachItemGenFunction, (task: Task) => task.id, false, false);
                    }, ForEach);
                    ForEach.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.width('100%');
                        Row.padding({ top: 8, bottom: 8 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('+ 添加任务');
                        Text.fontSize(14);
                        Text.fontColor(Colors.PRIMARY_DARK);
                        Text.onClick(() => {
                            this.addTask();
                        });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                    }, Blank);
                    Blank.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('确认计划并开始专注');
                        Button.width('100%');
                        Button.height(50);
                        Button.fontSize(16);
                        Button.fontWeight(FontWeight.Medium);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.borderRadius(Radius.LG);
                        Button.margin({ top: 8 });
                        Button.onClick(() => {
                            this.confirm();
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
        Column.pop();
        // 对话 + 计划
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 输入栏
            Row.create();
            // 输入栏
            Row.width('100%');
            // 输入栏
            Row.padding({ left: 16, right: 16, top: 10, bottom: 16 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '说说你今天想学什么…' });
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
            Button.backgroundColor(Colors.PRIMARY);
            Button.borderRadius(22);
            Button.margin({ left: 10 });
            Button.onClick(() => {
                this.send();
            });
        }, Button);
        Button.pop();
        // 输入栏
        Row.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "TaskPlanning";
    }
}
registerNamedRoute(() => new TaskPlanning(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/TaskPlanning", pageFullPath: "entry/src/main/ets/pages/TaskPlanning", integratedHsp: "false", moduleType: "followWithHap" });
