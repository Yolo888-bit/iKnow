if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface AIChat_Params {
    qaElapsed?: number;
    messages?: AIMessage[];
    inputValue?: string;
    answering?: boolean;
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { FocusController } from "@normalized:N&&&entry/src/main/ets/services/FocusController&";
import { AIMessage } from "@normalized:N&&&entry/src/main/ets/models/AIMessage&";
import { QuestionRecord } from "@normalized:N&&&entry/src/main/ets/models/QuestionRecord&";
import { MessageRole } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
import { AITag } from "@normalized:N&&&entry/src/main/ets/components/AITag&";
import { AIFirstDisclaimer } from "@normalized:N&&&entry/src/main/ets/components/AIFirstDisclaimer&";
export class AIChat extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__qaElapsed = this.createStorageProp(StorageKey.FOCUS_QA_ELAPSED, 0, "qaElapsed");
        this.__messages = new ObservedPropertyObjectPU([], this, "messages");
        this.__inputValue = new ObservedPropertySimplePU('', this, "inputValue");
        this.__answering = new ObservedPropertySimplePU(false, this, "answering");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: AIChat_Params) {
        if (params.messages !== undefined) {
            this.messages = params.messages;
        }
        if (params.inputValue !== undefined) {
            this.inputValue = params.inputValue;
        }
        if (params.answering !== undefined) {
            this.answering = params.answering;
        }
    }
    updateStateVars(params: AIChat_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__qaElapsed.purgeDependencyOnElmtId(rmElmtId);
        this.__messages.purgeDependencyOnElmtId(rmElmtId);
        this.__inputValue.purgeDependencyOnElmtId(rmElmtId);
        this.__answering.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__qaElapsed.aboutToBeDeleted();
        this.__messages.aboutToBeDeleted();
        this.__inputValue.aboutToBeDeleted();
        this.__answering.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __qaElapsed: ObservedPropertyAbstractPU<number>;
    get qaElapsed() {
        return this.__qaElapsed.get();
    }
    set qaElapsed(newValue: number) {
        this.__qaElapsed.set(newValue);
    }
    private __messages: ObservedPropertyObjectPU<AIMessage[]>;
    get messages() {
        return this.__messages.get();
    }
    set messages(newValue: AIMessage[]) {
        this.__messages.set(newValue);
    }
    private __inputValue: ObservedPropertySimplePU<string>;
    get inputValue() {
        return this.__inputValue.get();
    }
    set inputValue(newValue: string) {
        this.__inputValue.set(newValue);
    }
    private __answering: ObservedPropertySimplePU<boolean>;
    get answering() {
        return this.__answering.get();
    }
    set answering(newValue: boolean) {
        this.__answering.set(newValue);
    }
    aboutToAppear(): void {
        this.pushAI('我在答疑模式，想问什么都可以。计时还在继续，安心问。');
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
        if (text.length === 0 || this.answering) {
            return;
        }
        this.inputValue = '';
        this.pushUser(text);
        this.answering = true;
        const answer = await AIService.getInstance().answerQuestion(text);
        this.answering = false;
        this.pushAI(answer);
        const q = new QuestionRecord();
        q.id = IdUtils.uuid();
        q.sessionId = FocusController.getInstance().getSession().id;
        q.question = text;
        q.answer = answer;
        q.createdAt = Date.now();
        FocusController.getInstance().addQuestion(q);
    }
    private backToFocus(): void {
        FocusController.getInstance().endQA();
        router.back();
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
            // 顶部：答疑计时 + 返回
            Row.create();
            // 顶部：答疑计时 + 返回
            Row.width('100%');
            // 顶部：答疑计时 + 返回
            Row.padding({ left: 20, right: 20, top: 14, bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('正在答疑');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`本次答疑时间 ${TimeUtils.formatClock(this.qaElapsed)}`);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        Column.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new AITag(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/AIChat.ets", line: 119, col: 9 });
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
        // 顶部：答疑计时 + 返回
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.layoutWeight(1);
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
            if (this.answering) {
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
        Column.pop();
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('返回专注');
            Button.width('100%');
            Button.height(44);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.CARD);
            Button.borderRadius(Radius.MD);
            Button.margin({ left: 20, right: 20, bottom: 8 });
            Button.onClick(() => {
                this.backToFocus();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ left: 16, right: 16, top: 8, bottom: 16 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '输入你的问题…' });
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
        Row.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new AIFirstDisclaimer(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/AIChat.ets", line: 182, col: 5 });
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
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "AIChat";
    }
}
registerNamedRoute(() => new AIChat(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/AIChat", pageFullPath: "entry/src/main/ets/pages/AIChat", integratedHsp: "false", moduleType: "followWithHap" });
