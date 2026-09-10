import { DeviceInfo } from "@normalized:N&&&entry/src/main/ets/services/ServiceTypes&";
import { FocusDetectionService } from "@normalized:N&&&entry/src/main/ets/services/FocusDetectionService&";
import { SensorService } from "@normalized:N&&&entry/src/main/ets/services/SensorService&";
import { FocusState } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
/**
 * 设备服务 —— 管理手机 / 摄像头 / 手表连接状态与模拟设备模式
 */
export class DeviceService {
    private static inst: DeviceService | null = null;
    private cameraOn: boolean = true;
    private simulateMode: boolean = true;
    static getInstance(): DeviceService {
        if (DeviceService.inst === null) {
            DeviceService.inst = new DeviceService();
        }
        return DeviceService.inst;
    }
    getDevices(): DeviceInfo[] {
        const list: DeviceInfo[] = [];
        const phone = new DeviceInfo();
        phone.type = 'PHONE';
        phone.name = '本机';
        phone.connected = true;
        phone.statusText = '已连接';
        list.push(phone);
        const camera = new DeviceInfo();
        camera.type = 'CAMERA';
        camera.name = '摄像头';
        camera.connected = this.cameraOn;
        camera.statusText = this.cameraOn ? '感知中' : '已关闭';
        list.push(camera);
        const watch = new DeviceInfo();
        watch.type = 'WATCH';
        watch.name = '华为 WATCH';
        watch.connected = SensorService.getInstance().isConnected();
        watch.statusText = watch.connected ? SensorService.getInstance().getStatusText() : '未连接';
        list.push(watch);
        return list;
    }
    isCameraOn(): boolean {
        return this.cameraOn;
    }
    setCamera(on: boolean): void {
        this.cameraOn = on;
    }
    isSimulateMode(): boolean {
        return this.simulateMode;
    }
    setSimulateMode(on: boolean): void {
        this.simulateMode = on;
    }
    /** 模拟一次分心（供模拟设备模式演示） */
    simulateDistraction(heavy: boolean): void {
        if (heavy) {
            FocusDetectionService.getInstance().simulate(FocusState.DISTRACTED);
        }
        else {
            FocusDetectionService.getInstance().simulate(FocusState.SLIGHTLY_DISTRACTED);
        }
    }
    /** 恢复专注（清除模拟覆盖） */
    resumeFocus(): void {
        FocusDetectionService.getInstance().resume();
    }
}
