if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Mine_Params {
    nickname?: string;
    avatar?: string;
}
import router from "@ohos:router";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
export class Mine extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__nickname = this.createStorageProp(StorageKey.USER_NICKNAME, '刘灿', "nickname");
        this.__avatar = this.createStorageProp(StorageKey.USER_AVATAR, '🧑‍🎓', "avatar");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Mine_Params) {
    }
    updateStateVars(params: Mine_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__nickname.purgeDependencyOnElmtId(rmElmtId);
        this.__avatar.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__nickname.aboutToBeDeleted();
        this.__avatar.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __nickname: ObservedPropertyAbstractPU<string>;
    get nickname() {
        return this.__nickname.get();
    }
    set nickname(newValue: string) {
        this.__nickname.set(newValue);
    }
    private __avatar: ObservedPropertyAbstractPU<string>;
    get avatar() {
        return this.__avatar.get();
    }
    set avatar(newValue: string) {
        this.__avatar.set(newValue);
    }
    menuItem(icon: string, title: string, subtitle: string, url: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(16);
            Row.backgroundColor(Colors.CARD);
            Row.borderRadius(Radius.MD);
            Row.onClick(() => {
                router.pushUrl({ url: url });
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(icon);
            Text.fontSize(22);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.margin({ left: 14 });
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(subtitle);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('›');
            Text.fontSize(20);
            Text.fontColor(Colors.TEXT_TERTIARY);
        }, Text);
        Text.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.backgroundColor(Colors.BG);
            Scroll.width('100%');
            Scroll.height('100%');
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.MD });
            Column.padding(20);
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 用户信息
            Row.create();
            // 用户信息
            Row.width('100%');
            // 用户信息
            Row.padding(20);
            // 用户信息
            Row.backgroundColor(Colors.CARD);
            // 用户信息
            Row.borderRadius(Radius.LG);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.avatar);
            Text.fontSize(30);
            Text.width(60);
            Text.height(60);
            Text.textAlign(TextAlign.Center);
            Text.backgroundColor(Colors.CARD);
            Text.borderRadius(30);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.margin({ left: 16 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.nickname);
            Text.fontSize(22);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('专注感知智能学伴');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        Column.pop();
        // 用户信息
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 菜单
            Column.create({ space: Spacing.SM });
            // 菜单
            Column.width('100%');
        }, Column);
        this.menuItem.bind(this)('🕐', '个人专注画像', '五维雷达 · 成长趋势', 'pages/FocusProfile');
        this.menuItem.bind(this)('💡', 'AI 学伴人格', '选择适合你的陪伴方式', 'pages/Settings');
        this.menuItem.bind(this)('⌚', '设备连接', '摄像头 · 智能手表', 'pages/Device');
        this.menuItem.bind(this)('🔒', '隐私与数据', '数据授权与管理', 'pages/Privacy');
        this.menuItem.bind(this)('⚙️', '设置', '通用设置 · 数据清除', 'pages/Settings');
        // 菜单
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
}
