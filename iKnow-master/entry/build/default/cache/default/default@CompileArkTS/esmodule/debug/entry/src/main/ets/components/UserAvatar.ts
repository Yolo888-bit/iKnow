if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface UserAvatar_Params {
    avatar?: string;
    diameter?: number;
    radius?: number;
    bg?: string;
}
import { Colors } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class UserAvatar extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__avatar = new SynchedPropertySimpleOneWayPU(params.avatar, this, "avatar");
        this.__diameter = new SynchedPropertySimpleOneWayPU(params.diameter, this, "diameter");
        this.__radius = new SynchedPropertySimpleOneWayPU(params.radius, this, "radius");
        this.__bg = new SynchedPropertySimpleOneWayPU(params.bg, this, "bg");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: UserAvatar_Params) {
        if (params.avatar === undefined) {
            this.__avatar.set('🧑‍🎓'
            /** 直径（px）。注意不能命名为 size —— 会与 ArkUI 通用属性 size() 冲突 */
            );
        }
        if (params.diameter === undefined) {
            this.__diameter.set(40
            /** 圆角：<=0 时按圆形（diameter / 2），>0 时按给定圆角（截图里用户头像为圆角方形） */
            );
        }
        if (params.radius === undefined) {
            this.__radius.set(0);
        }
        if (params.bg === undefined) {
            this.__bg.set(Colors.PRIMARY_SOFT
            /** 判定是否为照片路径（兼容 file:// 与绝对路径） */
            );
        }
    }
    updateStateVars(params: UserAvatar_Params) {
        this.__avatar.reset(params.avatar);
        this.__diameter.reset(params.diameter);
        this.__radius.reset(params.radius);
        this.__bg.reset(params.bg);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__avatar.purgeDependencyOnElmtId(rmElmtId);
        this.__diameter.purgeDependencyOnElmtId(rmElmtId);
        this.__radius.purgeDependencyOnElmtId(rmElmtId);
        this.__bg.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__avatar.aboutToBeDeleted();
        this.__diameter.aboutToBeDeleted();
        this.__radius.aboutToBeDeleted();
        this.__bg.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __avatar: SynchedPropertySimpleOneWayPU<string>;
    get avatar() {
        return this.__avatar.get();
    }
    set avatar(newValue: string) {
        this.__avatar.set(newValue);
    }
    /** 直径（px）。注意不能命名为 size —— 会与 ArkUI 通用属性 size() 冲突 */
    private __diameter: SynchedPropertySimpleOneWayPU<number>;
    get diameter() {
        return this.__diameter.get();
    }
    set diameter(newValue: number) {
        this.__diameter.set(newValue);
    }
    /** 圆角：<=0 时按圆形（diameter / 2），>0 时按给定圆角（截图里用户头像为圆角方形） */
    private __radius: SynchedPropertySimpleOneWayPU<number>;
    get radius() {
        return this.__radius.get();
    }
    set radius(newValue: number) {
        this.__radius.set(newValue);
    }
    private __bg: SynchedPropertySimpleOneWayPU<string>;
    get bg() {
        return this.__bg.get();
    }
    set bg(newValue: string) {
        this.__bg.set(newValue);
    }
    /** 判定是否为照片路径（兼容 file:// 与绝对路径） */
    private isPhoto(): boolean {
        const a: string = this.avatar;
        return a.indexOf('file://') === 0 || a.indexOf('/') === 0 || a.indexOf('://') > 0;
    }
    private corner(): number {
        return this.radius > 0 ? this.radius : this.diameter / 2;
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isPhoto()) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create(this.avatar);
                        Image.width(this.diameter);
                        Image.height(this.diameter);
                        Image.objectFit(ImageFit.Cover);
                        Image.borderRadius(this.corner());
                        Image.backgroundColor(this.bg);
                    }, Image);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.avatar);
                        Text.fontSize(Math.round(this.diameter * 0.56));
                        Text.width(this.diameter);
                        Text.height(this.diameter);
                        Text.textAlign(TextAlign.Center);
                        Text.backgroundColor(this.bg);
                        Text.borderRadius(this.corner());
                    }, Text);
                    Text.pop();
                });
            }
        }, If);
        If.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
