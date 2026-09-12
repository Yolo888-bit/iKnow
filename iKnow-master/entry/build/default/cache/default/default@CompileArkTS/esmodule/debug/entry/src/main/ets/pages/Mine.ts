if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Mine_Params {
    nickname?: string;
    avatar?: string;
    personality?: AIPersonality;
    showAvatarSheet?: boolean;
    types?: CompanionType[];
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import { Colors, Radius, Spacing } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { NavParams } from "@normalized:N&&&entry/src/main/ets/models/NavParams&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { AuthService } from "@normalized:N&&&entry/src/main/ets/services/AuthService&";
import { AIPersonality } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import { UserAvatar } from "@normalized:N&&&entry/src/main/ets/components/UserAvatar&";
import { AvatarPicker } from "@normalized:N&&&entry/src/main/ets/components/AvatarPicker&";
/** AI 考伴类型（取自需求文档「页面 13：AI 考伴人格设置」的 3 种类型） */
interface CompanionType {
    key: AIPersonality;
    emoji: string;
    label: string;
    desc: string;
}
export class Mine extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__nickname = this.createStorageProp(StorageKey.USER_NICKNAME, '刘灿', "nickname");
        this.__avatar = this.createStorageProp(StorageKey.USER_AVATAR, '🧑‍🎓', "avatar");
        this.__personality = new ObservedPropertySimplePU(AIPersonality.GENTLE, this, "personality");
        this.__showAvatarSheet = new ObservedPropertySimplePU(false, this, "showAvatarSheet");
        this.types = [
            { key: AIPersonality.STRICT, emoji: '🎯', label: '严格教练型', desc: '直接 · 高执行力 · 适合拖延严重' },
            { key: AIPersonality.GENTLE, emoji: '🌤️', label: '温和陪伴型', desc: '鼓励 · 温和 · 低压力' },
            { key: AIPersonality.QUIET, emoji: '🌙', label: '极简安静型', desc: '尽量不主动说话 · 轻量提示' }
        ];
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Mine_Params) {
        if (params.personality !== undefined) {
            this.personality = params.personality;
        }
        if (params.showAvatarSheet !== undefined) {
            this.showAvatarSheet = params.showAvatarSheet;
        }
        if (params.types !== undefined) {
            this.types = params.types;
        }
    }
    updateStateVars(params: Mine_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__nickname.purgeDependencyOnElmtId(rmElmtId);
        this.__avatar.purgeDependencyOnElmtId(rmElmtId);
        this.__personality.purgeDependencyOnElmtId(rmElmtId);
        this.__showAvatarSheet.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__nickname.aboutToBeDeleted();
        this.__avatar.aboutToBeDeleted();
        this.__personality.aboutToBeDeleted();
        this.__showAvatarSheet.aboutToBeDeleted();
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
    private __personality: ObservedPropertySimplePU<AIPersonality>;
    get personality() {
        return this.__personality.get();
    }
    set personality(newValue: AIPersonality) {
        this.__personality.set(newValue);
    }
    private __showAvatarSheet: ObservedPropertySimplePU<boolean>;
    get showAvatarSheet() {
        return this.__showAvatarSheet.get();
    }
    set showAvatarSheet(newValue: boolean) {
        this.__showAvatarSheet.set(newValue);
    }
    private types: CompanionType[];
    aboutToAppear(): void {
        this.personality = AppStore.getInstance().getUser().aiPersonality;
    }
    private selectPersona(key: AIPersonality): void {
        this.personality = key;
        AppStore.getInstance().saveUserPersonality(key);
        promptAction.showToast({ message: '已切换考伴类型' });
    }
    private async doLogout(): Promise<void> {
        await AuthService.getInstance().logout();
        router.replaceUrl({ url: 'pages/Login' });
    }
    menuItem(icon: string, title: string, subtitle: string, url: string, paramTitle: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(16);
            Row.backgroundColor(Colors.CARD);
            Row.borderRadius(Radius.MD);
            Row.onClick(() => {
                if (paramTitle.length > 0) {
                    router.pushUrl({ url: url, params: new NavParams(paramTitle) });
                }
                else {
                    router.pushUrl({ url: url });
                }
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
    companionTypeCard(t: CompanionType, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(14);
            Row.backgroundColor(this.personality === t.key ? Colors.PRIMARY_SOFT : Colors.BG);
            Row.borderRadius(Radius.MD);
            Row.onClick(() => {
                this.selectPersona(t.key);
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(t.emoji);
            Text.fontSize(20);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.margin({ left: 12 });
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(t.label);
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(t.desc);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 3 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.personality === t.key) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('✓');
                        Text.fontSize(18);
                        Text.fontColor(Colors.PRIMARY);
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.TopStart });
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
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
            Stack.create({ alignContent: Alignment.BottomEnd });
            Stack.onClick(() => {
                this.showAvatarSheet = true;
            });
        }, Stack);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new UserAvatar(this, { avatar: this.avatar, diameter: 60, bg: Colors.CARD }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Mine.ets", line: 121, col: 13 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            avatar: this.avatar,
                            diameter: 60,
                            bg: Colors.CARD
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        avatar: this.avatar, diameter: 60, bg: Colors.CARD
                    });
                }
            }, { name: "UserAvatar" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 可点击编辑的提示角标
            Text.create('✎');
            // 可点击编辑的提示角标
            Text.fontSize(11);
            // 可点击编辑的提示角标
            Text.fontColor(Color.White);
            // 可点击编辑的提示角标
            Text.width(20);
            // 可点击编辑的提示角标
            Text.height(20);
            // 可点击编辑的提示角标
            Text.textAlign(TextAlign.Center);
            // 可点击编辑的提示角标
            Text.backgroundColor(Colors.PRIMARY);
            // 可点击编辑的提示角标
            Text.borderRadius(10);
        }, Text);
        // 可点击编辑的提示角标
        Text.pop();
        Stack.pop();
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
            Text.create('专注感知智能考伴');
            Text.fontSize(13);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        Column.pop();
        // 用户信息
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // AI 考伴：3 种类型
            Column.create();
            // AI 考伴：3 种类型
            Column.width('100%');
            // AI 考伴：3 种类型
            Column.padding(18);
            // AI 考伴：3 种类型
            Column.backgroundColor(Colors.CARD);
            // AI 考伴：3 种类型
            Column.borderRadius(Radius.LG);
            // AI 考伴：3 种类型
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 考伴');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('选择考伴类型，会影响提醒语气、干预方式与专注节奏');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.width('100%');
            Text.margin({ top: 6, bottom: 12 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: Spacing.SM });
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const t = _item;
                this.companionTypeCard.bind(this)(t);
            };
            this.forEachUpdateFunction(elmtId, this.types, forEachItemGenFunction, (t: CompanionType) => t.label, false, false);
        }, ForEach);
        ForEach.pop();
        Column.pop();
        // AI 考伴：3 种类型
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 菜单
            Column.create({ space: Spacing.SM });
            // 菜单
            Column.width('100%');
        }, Column);
        this.menuItem.bind(this)('💬', '和考伴聊聊', '长期陪伴 · 智能答疑', 'pages/AICompanion', '');
        this.menuItem.bind(this)('⌚', '设备', '摄像头 · 智能手表', 'pages/Device', '');
        this.menuItem.bind(this)('🔔', '通知', '专注提醒与消息', 'pages/Placeholder', '通知');
        this.menuItem.bind(this)('🔒', '隐私', '授权与数据权限', 'pages/Privacy', '');
        this.menuItem.bind(this)('🗂️', '数据管理', '导出 · 清除学习数据', 'pages/Privacy', '');
        this.menuItem.bind(this)('ℹ️', '关于', '版本与开发者信息', 'pages/Placeholder', '关于');
        // 菜单
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 退出登录
            Button.createWithLabel('退出登录');
            // 退出登录
            Button.width('100%');
            // 退出登录
            Button.height(48);
            // 退出登录
            Button.fontSize(15);
            // 退出登录
            Button.fontColor(Colors.TEXT_SECONDARY);
            // 退出登录
            Button.backgroundColor(Colors.CARD);
            // 退出登录
            Button.borderRadius(Radius.MD);
            // 退出登录
            Button.onClick(() => {
                this.doLogout();
            });
        }, Button);
        // 退出登录
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.height(20);
        }, Blank);
        Blank.pop();
        Column.pop();
        Scroll.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 头像选择器（自定义覆盖层，替代 bindSheet，Tab 子页面里更稳）
                    AvatarPicker(this, {
                        show: this.showAvatarSheet,
                        onClose: () => {
                            this.showAvatarSheet = false;
                        }
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Mine.ets", line: 212, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            show: this.showAvatarSheet,
                            onClose: () => {
                                this.showAvatarSheet = false;
                            }
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        show: this.showAvatarSheet
                    });
                }
            }, { name: "AvatarPicker" });
        }
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
