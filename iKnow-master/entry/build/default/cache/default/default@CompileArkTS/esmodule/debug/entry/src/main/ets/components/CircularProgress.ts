if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CircularProgress_Params {
    settings?: RenderingContextSettings;
    ctx?: CanvasRenderingContext2D;
    percent?: number;
    boxSize?: number;
    label?: string;
}
import { Colors } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class CircularProgress extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.settings = new RenderingContextSettings(true);
        this.ctx = new CanvasRenderingContext2D(this.settings);
        this.__percent = new SynchedPropertySimpleOneWayPU(params.percent, this, "percent");
        this.__boxSize = new SynchedPropertySimpleOneWayPU(params.boxSize, this, "boxSize");
        this.__label = new SynchedPropertySimpleOneWayPU(params.label, this, "label");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CircularProgress_Params) {
        if (params.settings !== undefined) {
            this.settings = params.settings;
        }
        if (params.ctx !== undefined) {
            this.ctx = params.ctx;
        }
        if (params.percent === undefined) {
            this.__percent.set(0);
        }
        if (params.boxSize === undefined) {
            this.__boxSize.set(140);
        }
        if (params.label === undefined) {
            this.__label.set('净专注率');
        }
    }
    updateStateVars(params: CircularProgress_Params) {
        this.__percent.reset(params.percent);
        this.__boxSize.reset(params.boxSize);
        this.__label.reset(params.label);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__percent.purgeDependencyOnElmtId(rmElmtId);
        this.__boxSize.purgeDependencyOnElmtId(rmElmtId);
        this.__label.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__percent.aboutToBeDeleted();
        this.__boxSize.aboutToBeDeleted();
        this.__label.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private settings: RenderingContextSettings;
    private ctx: CanvasRenderingContext2D;
    private __percent: SynchedPropertySimpleOneWayPU<number>;
    get percent() {
        return this.__percent.get();
    }
    set percent(newValue: number) {
        this.__percent.set(newValue);
    }
    private __boxSize: SynchedPropertySimpleOneWayPU<number>;
    get boxSize() {
        return this.__boxSize.get();
    }
    set boxSize(newValue: number) {
        this.__boxSize.set(newValue);
    }
    private __label: SynchedPropertySimpleOneWayPU<string>;
    get label() {
        return this.__label.get();
    }
    set label(newValue: string) {
        this.__label.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(this.boxSize);
            Stack.height(this.boxSize);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Canvas.create(this.ctx);
            Canvas.width(this.boxSize);
            Canvas.height(this.boxSize);
            Canvas.onReady(() => {
                this.draw();
            });
        }, Canvas);
        Canvas.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.label);
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.percent}%`);
            Text.fontSize(30);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        Column.pop();
        Stack.pop();
    }
    private draw(): void {
        const c = this.ctx;
        const cx = this.boxSize / 2;
        const cy = this.boxSize / 2;
        const r = this.boxSize / 2 - 8;
        c.clearRect(0, 0, this.boxSize, this.boxSize);
        c.lineWidth = 8;
        c.lineCap = 'round';
        c.strokeStyle = Colors.LINE;
        c.beginPath();
        c.arc(cx, cy, r, 0, Math.PI * 2);
        c.stroke();
        const start = -Math.PI / 2;
        const end = start + Math.PI * 2 * this.percent / 100;
        c.strokeStyle = Colors.PRIMARY;
        c.beginPath();
        c.arc(cx, cy, r, start, end);
        c.stroke();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
