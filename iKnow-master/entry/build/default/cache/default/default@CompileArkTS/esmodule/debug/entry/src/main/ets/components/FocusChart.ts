if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface FocusChart_Params {
    settings?: RenderingContextSettings;
    ctx?: CanvasRenderingContext2D;
    levels?: number[];
    states?: string[];
    chartH?: number;
}
import { Colors } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { FocusStateUi } from "@normalized:N&&&entry/src/main/ets/common/FocusStateUi&";
export class FocusChart extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.settings = new RenderingContextSettings(true);
        this.ctx = new CanvasRenderingContext2D(this.settings);
        this.__levels = new SynchedPropertyObjectOneWayPU(params.levels, this, "levels");
        this.__states = new SynchedPropertyObjectOneWayPU(params.states, this, "states");
        this.chartH = 180;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: FocusChart_Params) {
        if (params.settings !== undefined) {
            this.settings = params.settings;
        }
        if (params.ctx !== undefined) {
            this.ctx = params.ctx;
        }
        if (params.levels === undefined) {
            this.__levels.set([]);
        }
        if (params.states === undefined) {
            this.__states.set([]);
        }
        if (params.chartH !== undefined) {
            this.chartH = params.chartH;
        }
    }
    updateStateVars(params: FocusChart_Params) {
        this.__levels.reset(params.levels);
        this.__states.reset(params.states);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__levels.purgeDependencyOnElmtId(rmElmtId);
        this.__states.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__levels.aboutToBeDeleted();
        this.__states.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private settings: RenderingContextSettings;
    private ctx: CanvasRenderingContext2D;
    private __levels: SynchedPropertySimpleOneWayPU<number[]>;
    get levels() {
        return this.__levels.get();
    }
    set levels(newValue: number[]) {
        this.__levels.set(newValue);
    }
    private __states: SynchedPropertySimpleOneWayPU<string[]>;
    get states() {
        return this.__states.get();
    }
    set states(newValue: string[]) {
        this.__states.set(newValue);
    }
    private chartH: number;
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Canvas.create(this.ctx);
            Canvas.width('100%');
            Canvas.height(this.chartH);
            Canvas.onReady(() => {
                this.draw();
            });
        }, Canvas);
        Canvas.pop();
    }
    private yFor(level: number, h: number, pad: number): number {
        const ratio = Math.max(0, Math.min(100, level)) / 100;
        return h - pad - ratio * (h - pad * 2);
    }
    private draw(): void {
        const c = this.ctx;
        const w = c.width;
        const h = c.height;
        c.clearRect(0, 0, w, h);
        if (this.levels.length === 0) {
            return;
        }
        const pad = 16;
        const n = this.levels.length;
        const stepX = (w - pad * 2) / Math.max(1, n - 1);
        // 基线
        c.strokeStyle = Colors.LINE;
        c.lineWidth = 1;
        c.beginPath();
        c.moveTo(pad, h - pad);
        c.lineTo(w - pad, h - pad);
        c.stroke();
        // 分段折线
        for (let i = 0; i < n - 1; i++) {
            const x1 = pad + i * stepX;
            const x2 = pad + (i + 1) * stepX;
            const y1 = this.yFor(this.levels[i], h, pad);
            const y2 = this.yFor(this.levels[i + 1], h, pad);
            const color = i < this.states.length ? FocusStateUi.color(this.states[i]) : Colors.GREEN;
            c.strokeStyle = color;
            c.lineWidth = 3;
            c.beginPath();
            c.moveTo(x1, y1);
            c.lineTo(x2, y2);
            c.stroke();
        }
        // 首末数据点
        c.fillStyle = Colors.PRIMARY;
        c.beginPath();
        c.arc(pad, this.yFor(this.levels[0], h, pad), 3, 0, Math.PI * 2);
        c.fill();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
