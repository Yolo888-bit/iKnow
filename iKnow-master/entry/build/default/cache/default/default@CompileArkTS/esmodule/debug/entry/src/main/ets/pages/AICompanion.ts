if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface AICompanion_Params {
    messages?: AIMessage[];
    inputValue?: string;
    answering?: boolean;
    quickPrompts?: string[];
}
import { Colors, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { AIMessage } from "@normalized:N&&&entry/src/main/ets/models/AIMessage&";
import { MessageRole } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
import { AITag } from "@normalized:N&&&entry/src/main/ets/components/AITag&";
export class AICompanion extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__messages = new ObservedPropertyObjectPU([], this, "messages");
        this.__inputValue = new ObservedPropertySimplePU('', this, "inputValue");
        this.__answering = new ObservedPropertySimplePU(false, this, "answering");
        this.quickPrompts = ['帮我规划今天的学习', '我今天状态不好', '为什么我最近总是容易分心？', '帮我调整下周学习计划'];
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: AICompanion_Params) {
        if (params.messages !== undefined) {
            this.messages = params.messages;
        }
        if (params.inputValue !== undefined) {
            this.inputValue = params.inputValue;
        }
        if (params.answering !== undefined) {
            this.answering = params.answering;
        }
        if (params.quickPrompts !== undefined) {
            this.quickPrompts = params.quickPrompts;
        }
    }
    updateStateVars(params: AICompanion_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__messages.purgeDependencyOnElmtId(rmElmtId);
        this.__inputValue.purgeDependencyOnElmtId(rmElmtId);
        this.__answering.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__messages.aboutToBeDeleted();
        this.__inputValue.aboutToBeDeleted();
        this.__answering.aboutToBeDeleted();
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
    private quickPrompts: string[];
    aboutToAppear(): void {
        this.pushAI(AIService.getInstance().companionIntro());
    }
    private pushAI(content: string): void {
        const m = new AIMessage();
        m.id = IdUtils.uuid();
        m.role = MessageRole.AI;
        m.content = content;
        m.timestamp = Date.now();
        this.messages.push(m);
    }
    private async send(text?: string): Promise<void> {
        const content = text !== undefined ? text : this.inputValue.trim();
        if (content.length === 0 || this.answering) {
            return;
        }
        this.inputValue = '';
        const um = new AIMessage();
        um.id = IdUtils.uuid();
        um.role = MessageRole.USER;
        um.content = content;
        um.timestamp = Date.now();
        this.messages.push(um);
        this.answering = true;
        const reply = await AIService.getInstance().chat(content);
        this.answering = false;
        this.pushAI(reply);
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
            Row.create();
            Row.width('100%');
            Row.padding({ left: 20, right: 20, top: 16, bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 学伴');
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
                    let componentCall = new AITag(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/AICompanion.ets", line: 87, col: 9 });
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
            // 快捷提问
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 快捷提问
            Column.create();
            // 快捷提问
            Column.width('100%');
            // 快捷提问
            Column.alignItems(HorizontalAlign.Start);
            // 快捷提问
            Column.margin({ top: 16 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('可以试试问我');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const p = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(p);
                    Text.fontSize(13);
                    Text.fontColor(Colors.PRIMARY_DARK);
                    Text.padding({ left: 12, right: 12, top: 8, bottom: 8 });
                    Text.backgroundColor(Colors.PRIMARY_SOFT);
                    Text.borderRadius(16);
                    Text.margin({ right: 8, top: 8 });
                    Text.onClick(() => {
                        this.send(p);
                    });
                }, Text);
                Text.pop();
            };
            this.forEachUpdateFunction(elmtId, this.quickPrompts, forEachItemGenFunction, (p: string) => p, false, false);
        }, ForEach);
        ForEach.pop();
        // 快捷提问
        Column.pop();
        Column.pop();
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ left: 16, right: 16, top: 8, bottom: 16 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '和小伴说点什么…' });
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
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
