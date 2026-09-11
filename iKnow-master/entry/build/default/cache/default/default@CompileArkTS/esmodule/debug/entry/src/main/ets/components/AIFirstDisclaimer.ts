if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface AIFirstDisclaimer_Params {
    shown?: boolean;
}
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
export class AIFirstDisclaimer extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__shown = this.createStorageProp(StorageKey.AI_DISCLAIMER_SHOWN, false, "shown");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: AIFirstDisclaimer_Params) {
    }
    updateStateVars(params: AIFirstDisclaimer_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__shown.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__shown.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __shown: ObservedPropertyAbstractPU<boolean>;
    get shown() {
        return this.__shown.get();
    }
    set shown(newValue: boolean) {
        this.__shown.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.shown) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                    }, Column);
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                        Column.height('100%');
                        Column.backgroundColor('#66000000');
                        Column.justifyContent(FlexAlign.Center);
                        Column.alignItems(HorizontalAlign.Center);
                        Column.position({ x: 0, y: 0 });
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('82%');
                        Column.padding(24);
                        Column.backgroundColor(Colors.CARD);
                        Column.borderRadius(Radius.LG);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('关于小伴');
                        Text.fontSize(18);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontColor(Colors.TEXT_PRIMARY);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('我是 AI 智能体，不是真人。我会陪你专注、答疑、复盘，' +
                            '但不能替代老师、医生或心理咨询师。所有内容仅供参考。');
                        Text.fontSize(14);
                        Text.fontColor(Colors.TEXT_SECONDARY);
                        Text.lineHeight(22);
                        Text.margin({ top: 12 });
                        Text.width('100%');
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('我知道了');
                        Button.width('100%');
                        Button.height(44);
                        Button.fontSize(15);
                        Button.fontColor(Color.White);
                        Button.backgroundColor(Colors.PRIMARY);
                        Button.borderRadius(Radius.MD);
                        Button.margin({ top: 20 });
                        Button.onClick(() => {
                            AppStorage.setOrCreate<boolean>(StorageKey.AI_DISCLAIMER_SHOWN, true);
                        });
                    }, Button);
                    Button.pop();
                    Column.pop();
                    Column.pop();
                });
            }
        }, If);
        If.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
