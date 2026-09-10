if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface FocusTimer_Params {
    seconds?: number;
    big?: boolean;
}
import { Colors } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
export class FocusTimer extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__seconds = new SynchedPropertySimpleOneWayPU(params.seconds, this, "seconds");
        this.__big = new SynchedPropertySimpleOneWayPU(params.big, this, "big");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: FocusTimer_Params) {
        if (params.seconds === undefined) {
            this.__seconds.set(0);
        }
        if (params.big === undefined) {
            this.__big.set(true);
        }
    }
    updateStateVars(params: FocusTimer_Params) {
        this.__seconds.reset(params.seconds);
        this.__big.reset(params.big);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__seconds.purgeDependencyOnElmtId(rmElmtId);
        this.__big.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__seconds.aboutToBeDeleted();
        this.__big.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __seconds: SynchedPropertySimpleOneWayPU<number>;
    get seconds() {
        return this.__seconds.get();
    }
    set seconds(newValue: number) {
        this.__seconds.set(newValue);
    }
    private __big: SynchedPropertySimpleOneWayPU<boolean>;
    get big() {
        return this.__big.get();
    }
    set big(newValue: boolean) {
        this.__big.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(TimeUtils.formatClock(this.seconds));
            Text.fontSize(this.big ? 68 : 44);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
