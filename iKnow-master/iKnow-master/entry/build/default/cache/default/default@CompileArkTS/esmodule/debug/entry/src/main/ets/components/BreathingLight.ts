if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface BreathingLight_Params {
    state?: string;
    breathe?: boolean;
    onTap?: () => void;
    timerId?: number;
}
import { FocusStateUi } from "@normalized:N&&&entry/src/main/ets/common/FocusStateUi&";
export class BreathingLight extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__state = new SynchedPropertySimpleOneWayPU(params.state, this, "state");
        this.__breathe = new ObservedPropertySimplePU(false, this, "breathe");
        this.onTap = () => {
        };
        this.timerId = -1;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: BreathingLight_Params) {
        if (params.state === undefined) {
            this.__state.set('FOCUSED');
        }
        if (params.breathe !== undefined) {
            this.breathe = params.breathe;
        }
        if (params.onTap !== undefined) {
            this.onTap = params.onTap;
        }
        if (params.timerId !== undefined) {
            this.timerId = params.timerId;
        }
    }
    updateStateVars(params: BreathingLight_Params) {
        this.__state.reset(params.state);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__state.purgeDependencyOnElmtId(rmElmtId);
        this.__breathe.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__state.aboutToBeDeleted();
        this.__breathe.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __state: SynchedPropertySimpleOneWayPU<string>;
    get state() {
        return this.__state.get();
    }
    set state(newValue: string) {
        this.__state.set(newValue);
    }
    private __breathe: ObservedPropertySimplePU<boolean>;
    get breathe() {
        return this.__breathe.get();
    }
    set breathe(newValue: boolean) {
        this.__breathe.set(newValue);
    }
    private onTap: () => void;
    private timerId: number;
    aboutToAppear(): void {
        this.timerId = setInterval(() => {
            this.breathe = !this.breathe;
        }, 1400);
    }
    aboutToDisappear(): void {
        if (this.timerId >= 0) {
            clearInterval(this.timerId);
            this.timerId = -1;
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(150);
            Stack.height(150);
            Stack.onClick(() => {
                this.onTap();
            });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            globalThis.Context.animation({ duration: 1400, curve: Curve.EaseInOut });
            Circle.width(150);
            Circle.height(150);
            Circle.fill(FocusStateUi.softColor(this.state));
            Circle.opacity(this.breathe ? 0.35 : 0.75);
            globalThis.Context.animation(null);
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(72);
            Circle.height(72);
            Circle.fill(FocusStateUi.color(this.state));
            Circle.shadow({ radius: 18, color: FocusStateUi.softColor(this.state), offsetX: 0, offsetY: 0 });
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(FocusStateUi.dot(this.state));
            Text.fontSize(22);
        }, Text);
        Text.pop();
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
