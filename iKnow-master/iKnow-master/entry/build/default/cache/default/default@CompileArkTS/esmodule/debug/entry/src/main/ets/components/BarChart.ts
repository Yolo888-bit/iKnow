if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface BarChart_Params {
    settings?: RenderingContextSettings;
    ctx?: CanvasRenderingContext2D;
    values?: number[];
    labels?: string[];
    chartH?: number;
}
import { Colors } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class BarChart extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.settings = new RenderingContextSettings(true);
        this.ctx = new CanvasRenderingContext2D(this.settings);
        this.__values = new SynchedPropertyObjectOneWayPU(params.values, this, "values");
        this.__labels = new SynchedPropertyObjectOneWayPU(params.labels, this, "labels");
        this.chartH = 160;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: BarChart_Params) {
        if (params.settings !== undefined) {
            this.settings = params.settings;
        }
        if (params.ctx !== undefined) {
            this.ctx = params.ctx;
        }
        if (params.values === undefined) {
            this.__values.set([]);
        }
        if (params.labels === undefined) {
            this.__labels.set([]);
        }
        if (params.chartH !== undefined) {
            this.chartH = params.chartH;
        }
    }
    updateStateVars(params: BarChart_Params) {
        this.__values.reset(params.values);
        this.__labels.reset(params.labels);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__values.purgeDependencyOnElmtId(rmElmtId);
        this.__labels.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__values.aboutToBeDeleted();
        this.__labels.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private settings: RenderingContextSettings;
    private ctx: CanvasRenderingContext2D;
    private __values: SynchedPropertySimpleOneWayPU<number[]>;
    get values() {
        return this.__values.get();
    }
    set values(newValue: number[]) {
        this.__values.set(newValue);
    }
    private __labels: SynchedPropertySimpleOneWayPU<string[]>;
    get labels() {
        return this.__labels.get();
    }
    set labels(newValue: string[]) {
        this.__labels.set(newValue);
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
    private draw(): void {
        const c = this.ctx;
        const w = c.width;
        const h = c.height;
        c.clearRect(0, 0, w, h);
        if (this.values.length === 0) {
            return;
        }
        let maxV = 1;
        for (const v of this.values) {
            if (v > maxV) {
                maxV = v;
            }
        }
        const pad = 16;
        const n = this.values.length;
        const slot = (w - pad * 2) / n;
        const barW = slot * 0.55;
        const bottom = h - pad - 20;
        const topH = h - pad * 2 - 20;
        for (let i = 0; i < n; i++) {
            const v = this.values[i];
            const bh = topH * (v / maxV);
            const x = pad + i * slot + (slot - barW) / 2;
            const y = bottom - bh;
            c.fillStyle = Colors.PRIMARY;
            c.fillRect(x, y, barW, bh);
            c.fillStyle = Colors.TEXT_SECONDARY;
            c.font = '10px sans-serif';
            c.textAlign = 'center';
            const label = i < this.labels.length ? this.labels[i] : '';
            c.fillText(label, pad + i * slot + slot / 2, h - 6);
        }
    }
    rerender() {
        this.updateDirtyElements();
    }
}
