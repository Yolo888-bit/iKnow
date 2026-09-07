if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface FocusBreak_Params {
    restRemain?: number;
    finished?: boolean;
    timerId?: number;
}
import router from "@ohos:router";
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { FocusController } from "@normalized:N&&&entry/src/main/ets/services/FocusController&";
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
export class FocusBreak extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__restRemain = new ObservedPropertySimplePU(300, this, "restRemain");
        this.__finished = new ObservedPropertySimplePU(false, this, "finished");
        this.timerId = -1;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: FocusBreak_Params) {
        if (params.restRemain !== undefined) {
            this.restRemain = params.restRemain;
        }
        if (params.finished !== undefined) {
            this.finished = params.finished;
        }
        if (params.timerId !== undefined) {
            this.timerId = params.timerId;
        }
    }
    updateStateVars(params: FocusBreak_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__restRemain.purgeDependencyOnElmtId(rmElmtId);
        this.__finished.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__restRemain.aboutToBeDeleted();
        this.__finished.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __restRemain: ObservedPropertySimplePU<number>;
    get restRemain() {
        return this.__restRemain.get();
    }
    set restRemain(newValue: number) {
        this.__restRemain.set(newValue);
    }
    private __finished: ObservedPropertySimplePU<boolean>;
    get finished() {
        return this.__finished.get();
    }
    set finished(newValue: boolean) {
        this.__finished.set(newValue);
    }
    private timerId: number;
    aboutToAppear(): void {
        this.timerId = setInterval(() => {
            if (this.restRemain > 0) {
                this.restRemain--;
                if (this.restRemain === 0) {
                    this.finished = true;
                }
            }
        }, 1000);
    }
    aboutToDisappear(): void {
        if (this.timerId >= 0) {
            clearInterval(this.timerId);
            this.timerId = -1;
        }
    }
    private continueFocus(): void {
        FocusController.getInstance().endBreak();
        router.back();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.justifyContent(FlexAlign.Center);
            Column.backgroundColor(Colors.BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.finished ? '休息结束啦' : '休息一下吧');
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(TimeUtils.formatClock(this.restRemain));
            Text.fontSize(60);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ top: 24 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.finished ? '准备继续了吗？' : '让眼睛和肩膀放松一下');
            Text.fontSize(14);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 12 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('继续专注');
            Button.width('70%');
            Button.height(48);
            Button.fontSize(16);
            Button.fontColor(Color.White);
            Button.backgroundColor(Colors.PRIMARY);
            Button.borderRadius(Radius.LG);
            Button.margin({ top: 48 });
            Button.onClick(() => {
                this.continueFocus();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('再休息 5 分钟');
            Button.width('70%');
            Button.height(48);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_SECONDARY);
            Button.backgroundColor(Colors.CARD);
            Button.borderRadius(Radius.LG);
            Button.margin({ top: 12 });
            Button.onClick(() => {
                this.restRemain = 300;
                this.finished = false;
            });
        }, Button);
        Button.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "FocusBreak";
    }
}
registerNamedRoute(() => new FocusBreak(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/FocusBreak", pageFullPath: "entry/src/main/ets/pages/FocusBreak", integratedHsp: "false", moduleType: "followWithHap" });
