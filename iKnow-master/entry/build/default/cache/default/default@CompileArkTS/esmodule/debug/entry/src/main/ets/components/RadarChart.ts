if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface RadarChart_Params {
    settings?: RenderingContextSettings;
    ctx?: CanvasRenderingContext2D;
    values?: number[];
    labels?: string[];
    chartSize?: number;
}
import { Colors } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class RadarChart extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.settings = new RenderingContextSettings(true);
        this.ctx = new CanvasRenderingContext2D(this.settings);
        this.__values = new SynchedPropertyObjectOneWayPU(params.values, this, "values");
        this.__labels = new SynchedPropertyObjectOneWayPU(params.labels, this, "labels");
        this.__chartSize = new SynchedPropertySimpleOneWayPU(params.chartSize, this, "chartSize");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: RadarChart_Params) {
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
        if (params.chartSize === undefined) {
            this.__chartSize.set(260);
        }
    }
    updateStateVars(params: RadarChart_Params) {
        this.__values.reset(params.values);
        this.__labels.reset(params.labels);
        this.__chartSize.reset(params.chartSize);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__values.purgeDependencyOnElmtId(rmElmtId);
        this.__labels.purgeDependencyOnElmtId(rmElmtId);
        this.__chartSize.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__values.aboutToBeDeleted();
        this.__labels.aboutToBeDeleted();
        this.__chartSize.aboutToBeDeleted();
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
    private __chartSize: SynchedPropertySimpleOneWayPU<number>;
    get chartSize() {
        return this.__chartSize.get();
    }
    set chartSize(newValue: number) {
        this.__chartSize.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Canvas.create(this.ctx);
            Canvas.width(this.chartSize);
            Canvas.height(this.chartSize);
            Canvas.onReady(() => {
                this.draw();
            });
        }, Canvas);
        Canvas.pop();
    }
    private angle(i: number, n: number): number {
        return -Math.PI / 2 + i * 2 * Math.PI / n;
    }
    private draw(): void {
        const c = this.ctx;
        const n = this.values.length;
        if (n === 0) {
            return;
        }
        const cx = this.chartSize / 2;
        const cy = this.chartSize / 2;
        const r = this.chartSize / 2 - 30;
        c.clearRect(0, 0, this.chartSize, this.chartSize);
        // 网格
        for (let g = 1; g <= 4; g++) {
            const rr = r * g / 4;
            c.beginPath();
            for (let i = 0; i < n; i++) {
                const ang = this.angle(i, n);
                const x = cx + rr * Math.cos(ang);
                const y = cy + rr * Math.sin(ang);
                if (i === 0) {
                    c.moveTo(x, y);
                }
                else {
                    c.lineTo(x, y);
                }
            }
            c.closePath();
            c.strokeStyle = Colors.LINE;
            c.lineWidth = 1;
            c.stroke();
        }
        // 轴线
        for (let i = 0; i < n; i++) {
            const ang = this.angle(i, n);
            c.beginPath();
            c.moveTo(cx, cy);
            c.lineTo(cx + r * Math.cos(ang), cy + r * Math.sin(ang));
            c.strokeStyle = Colors.LINE;
            c.lineWidth = 1;
            c.stroke();
        }
        // 数据多边形
        c.beginPath();
        for (let i = 0; i < n; i++) {
            const ang = this.angle(i, n);
            const rr = r * Math.max(0, Math.min(100, this.values[i])) / 100;
            const x = cx + rr * Math.cos(ang);
            const y = cy + rr * Math.sin(ang);
            if (i === 0) {
                c.moveTo(x, y);
            }
            else {
                c.lineTo(x, y);
            }
        }
        c.closePath();
        c.fillStyle = Colors.PRIMARY_SOFT;
        c.fill();
        c.strokeStyle = Colors.PRIMARY;
        c.lineWidth = 2;
        c.stroke();
        // 顶点
        for (let i = 0; i < n; i++) {
            const ang = this.angle(i, n);
            const rr = r * Math.max(0, Math.min(100, this.values[i])) / 100;
            c.fillStyle = Colors.PRIMARY;
            c.beginPath();
            c.arc(cx + rr * Math.cos(ang), cy + rr * Math.sin(ang), 3, 0, Math.PI * 2);
            c.fill();
        }
        // 标签
        c.fillStyle = Colors.TEXT_SECONDARY;
        c.font = '13px sans-serif';
        c.textAlign = 'center';
        for (let i = 0; i < n; i++) {
            const ang = this.angle(i, n);
            const lx = cx + (r + 20) * Math.cos(ang);
            const ly = cy + (r + 20) * Math.sin(ang);
            const value = `${this.labels[i]} ${Math.round(this.values[i])}`;
            c.fillText(value, lx, ly + 4);
        }
    }
    rerender() {
        this.updateDirtyElements();
    }
}
