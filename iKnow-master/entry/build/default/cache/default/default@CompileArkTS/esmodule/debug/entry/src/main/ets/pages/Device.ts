if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Device_Params {
    devices?: DeviceInfo[];
    simulateMode?: boolean;
}
import promptAction from "@ohos:promptAction";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { DeviceService } from "@normalized:N&&&entry/src/main/ets/services/DeviceService&";
import type { DeviceInfo } from '../services/ServiceTypes';
export class Device extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__devices = new ObservedPropertyObjectPU([], this, "devices");
        this.__simulateMode = new ObservedPropertySimplePU(true, this, "simulateMode");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Device_Params) {
        if (params.devices !== undefined) {
            this.devices = params.devices;
        }
        if (params.simulateMode !== undefined) {
            this.simulateMode = params.simulateMode;
        }
    }
    updateStateVars(params: Device_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__devices.purgeDependencyOnElmtId(rmElmtId);
        this.__simulateMode.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__devices.aboutToBeDeleted();
        this.__simulateMode.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __devices: ObservedPropertyObjectPU<DeviceInfo[]>;
    get devices() {
        return this.__devices.get();
    }
    set devices(newValue: DeviceInfo[]) {
        this.__devices.set(newValue);
    }
    private __simulateMode: ObservedPropertySimplePU<boolean>;
    get simulateMode() {
        return this.__simulateMode.get();
    }
    set simulateMode(newValue: boolean) {
        this.__simulateMode.set(newValue);
    }
    aboutToAppear(): void {
        this.refresh();
    }
    private refresh(): void {
        this.devices = DeviceService.getInstance().getDevices();
        this.simulateMode = DeviceService.getInstance().isSimulateMode();
    }
    private icon(type: string): string {
        if (type === 'CAMERA') {
            return '📷';
        }
        if (type === 'WATCH') {
            return '⌚';
        }
        return '📱';
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.backgroundColor(Colors.BG);
            Scroll.width('100%');
            Scroll.height('100%');
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.LG });
            Column.padding(20);
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('设备连接');
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.SM });
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const d = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.width('100%');
                    Row.padding(16);
                    Row.backgroundColor(Colors.CARD);
                    Row.borderRadius(Radius.MD);
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(this.icon(d.type));
                    Text.fontSize(26);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.alignItems(HorizontalAlign.Start);
                    Column.margin({ left: 14 });
                    Column.layoutWeight(1);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(d.name);
                    Text.fontSize(15);
                    Text.fontWeight(FontWeight.Medium);
                    Text.fontColor(Colors.TEXT_PRIMARY);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(d.statusText);
                    Text.fontSize(12);
                    Text.fontColor(Colors.TEXT_SECONDARY);
                    Text.margin({ top: 2 });
                }, Text);
                Text.pop();
                Column.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Circle.create();
                    Circle.width(8);
                    Circle.height(8);
                    Circle.fill(d.connected ? Colors.GREEN : Colors.TEXT_TERTIARY);
                }, Circle);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(d.connected ? '已连接' : '未连接');
                    Text.fontSize(12);
                    Text.fontColor(d.connected ? Colors.GREEN : Colors.TEXT_SECONDARY);
                    Text.margin({ left: 6 });
                }, Text);
                Text.pop();
                Row.pop();
                Row.pop();
            };
            this.forEachUpdateFunction(elmtId, this.devices, forEachItemGenFunction, (d: DeviceInfo) => d.type, false, false);
        }, ForEach);
        ForEach.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 模拟设备模式
            Column.create();
            __Column__deviceCard();
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('模拟设备模式');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('当前为 MVP 演示，摄像头/手表数据由模拟服务提供。可手动触发状态，验证专注页的绿/黄/红联动。');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.lineHeight(20);
            Text.width('100%');
            Text.margin({ top: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.width('100%');
            Row.margin({ top: 16 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('模拟轻度分心');
            Button.layoutWeight(1);
            Button.height(42);
            Button.fontSize(13);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.YELLOW_SOFT);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                DeviceService.getInstance().simulateDistraction(false);
                promptAction.showToast({ message: '已模拟轻度分心' });
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('模拟重度走神');
            Button.layoutWeight(1);
            Button.height(42);
            Button.fontSize(13);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.RED_SOFT);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                DeviceService.getInstance().simulateDistraction(true);
                promptAction.showToast({ message: '已模拟重度走神' });
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('恢复专注');
            Button.layoutWeight(1);
            Button.height(42);
            Button.fontSize(13);
            Button.fontColor(Colors.TEXT_PRIMARY);
            Button.backgroundColor(Colors.GREEN_SOFT);
            Button.borderRadius(Radius.MD);
            Button.onClick(() => {
                DeviceService.getInstance().resumeFocus();
                promptAction.showToast({ message: '已恢复专注' });
            });
        }, Button);
        Button.pop();
        Row.pop();
        // 模拟设备模式
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.height(20);
        }, Blank);
        Blank.pop();
        Column.pop();
        Scroll.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Device";
    }
}
function __Column__deviceCard(): void {
    Column.width('100%');
    Column.padding(18);
    Column.backgroundColor(Colors.CARD);
    Column.borderRadius(Radius.LG);
    Column.alignItems(HorizontalAlign.Start);
}
registerNamedRoute(() => new Device(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Device", pageFullPath: "entry/src/main/ets/pages/Device", integratedHsp: "false", moduleType: "followWithHap" });
