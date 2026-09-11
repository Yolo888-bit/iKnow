import { FocusState, FocusSource } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import { FocusDetectionResult, MotionData } from "@normalized:N&&&entry/src/main/ets/services/ServiceTypes&";
import type { FocusSensor } from "@normalized:N&&&entry/src/main/ets/services/ServiceTypes&";
import { DemoFlag } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { PermissionService } from "@normalized:N&&&entry/src/main/ets/services/PermissionService&";
/**
 * 专注检测服务 —— Mock 摄像头视觉
 * 未来替换为真实摄像头视觉检测时，仅需替换本类实现。
 */
export class FocusDetectionService implements FocusSensor {
    private static inst: FocusDetectionService | null = null;
    private timerId: number = -1;
    private callback: ((r: FocusDetectionResult) => void) | null = null;
    private startTs: number = 0;
    private manualOverride: FocusState | null = null;
    private manualDetail: string = '';
    static getInstance(): FocusDetectionService {
        if (FocusDetectionService.inst === null) {
            FocusDetectionService.inst = new FocusDetectionService();
        }
        return FocusDetectionService.inst;
    }
    getVisualState(): FocusDetectionResult {
        return this.current();
    }
    getHeartRate(): number {
        return 68 + Math.round(Math.random() * 6);
    }
    getHRV(): number {
        return 44 + Math.round(Math.random() * 14);
    }
    getMotionData(): MotionData {
        const m = new MotionData();
        m.motionLevel = Math.round(Math.random() * 20);
        m.wristMotion = Math.round(Math.random() * 6);
        return m;
    }
    /** 启动自动检测：每 DETECT_INTERVAL 回调一次 */
    start(cb: (r: FocusDetectionResult) => void): void {
        this.callback = cb;
        // 硬规则 §4：未授权摄像头则不启动视觉检测，由调用方降级为"仅计时模式"
        if (!PermissionService.getInstance().snapshot().camera) {
            return;
        }
        this.startTs = Date.now();
        if (this.timerId >= 0) {
            clearInterval(this.timerId);
        }
        this.timerId = setInterval(() => {
            if (this.callback !== null) {
                this.callback(this.current());
            }
        }, DemoFlag.DETECT_INTERVAL);
        if (this.callback !== null) {
            this.callback(this.current());
        }
    }
    /** 由 PermissionService 在授权变化时调用：关闭则立即停止检测 */
    setEnabled(enabled: boolean): void {
        if (!enabled) {
            this.stop();
        }
    }
    stop(): void {
        if (this.timerId >= 0) {
            clearInterval(this.timerId);
            this.timerId = -1;
        }
        this.callback = null;
        this.manualOverride = null;
    }
    /** 手动注入状态（演示用 / Device 模拟设备模式） */
    simulate(state: FocusState): void {
        if (state === FocusState.DISTRACTED) {
            this.manualOverride = state;
            this.manualDetail = '长时间离开屏幕';
        }
        else if (state === FocusState.SLIGHTLY_DISTRACTED) {
            this.manualOverride = state;
            this.manualDetail = '频繁低头';
        }
        else {
            this.manualOverride = null;
            this.manualDetail = '视线正常';
        }
        if (this.callback !== null) {
            this.callback(this.current());
        }
    }
    resume(): void {
        this.manualOverride = null;
        this.manualDetail = '';
        this.startTs = Date.now();
        if (this.callback !== null) {
            this.callback(this.current());
        }
    }
    private current(): FocusDetectionResult {
        const r = new FocusDetectionResult();
        r.timestamp = Date.now();
        r.source = FocusSource.CAMERA;
        if (this.manualOverride !== null) {
            r.state = this.manualOverride;
            r.detail = this.manualDetail;
            r.confidence = 88;
            return r;
        }
        const elapsed = (Date.now() - this.startTs) / 1000;
        const cycle = elapsed % 160;
        if (cycle < 45) {
            r.state = FocusState.FOCUSED;
            r.detail = '视线正常';
            r.confidence = 90 + Math.round(Math.random() * 8);
        }
        else if (cycle < 62) {
            r.state = FocusState.SLIGHTLY_DISTRACTED;
            r.detail = '频繁低头';
            r.confidence = 70 + Math.round(Math.random() * 10);
        }
        else if (cycle < 78) {
            r.state = FocusState.FOCUSED;
            r.detail = '视线回到屏幕';
            r.confidence = 85 + Math.round(Math.random() * 8);
        }
        else if (cycle < 100) {
            r.state = FocusState.SLIGHTLY_DISTRACTED;
            r.detail = '视线长时间离开';
            r.confidence = 66 + Math.round(Math.random() * 10);
        }
        else if (cycle < 122) {
            r.state = FocusState.DISTRACTED;
            r.detail = '长时间离席';
            r.confidence = 80 + Math.round(Math.random() * 8);
        }
        else {
            r.state = FocusState.FOCUSED;
            r.detail = '重新进入状态';
            r.confidence = 85 + Math.round(Math.random() * 10);
        }
        return r;
    }
}
