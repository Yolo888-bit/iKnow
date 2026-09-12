if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface AvatarPicker_Params {
    show?: boolean;
    /** 关闭回调（点遮罩 / 选完 / 取消时触发） */
    onClose?: () => void;
    avatar?: string;
    options?: string[];
}
import promptAction from "@ohos:promptAction";
import type common from "@ohos:app.ability.common";
import photoAccessHelper from "@ohos:file.photoAccessHelper";
import fileIo from "@ohos:file.fs";
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { AppStore } from "@normalized:N&&&entry/src/main/ets/store/AppStore&";
import { UserAvatar } from "@normalized:N&&&entry/src/main/ets/components/UserAvatar&";
export class AvatarPicker extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__show = new SynchedPropertySimpleOneWayPU(params.show, this, "show");
        this.onClose = () => {
        };
        this.__avatar = this.createStorageProp(StorageKey.USER_AVATAR, '🧑‍🎓', "avatar");
        this.options = [
            '🦊', '🐱', '🐼', '🐯', '🦁', '🐸', '🐵', '🐧',
            '🦄', '🐨', '🦉', '🐢', '🌟', '🍀', '🚀', '🎯'
        ];
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: AvatarPicker_Params) {
        if (params.show === undefined) {
            this.__show.set(false
            /** 关闭回调（点遮罩 / 选完 / 取消时触发） */
            );
        }
        if (params.onClose !== undefined) {
            this.onClose = params.onClose;
        }
        if (params.options !== undefined) {
            this.options = params.options;
        }
    }
    updateStateVars(params: AvatarPicker_Params) {
        this.__show.reset(params.show);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__show.purgeDependencyOnElmtId(rmElmtId);
        this.__avatar.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__show.aboutToBeDeleted();
        this.__avatar.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    /** 是否显示（由父页面 @State 单向传入） */
    private __show: SynchedPropertySimpleOneWayPU<boolean>;
    get show() {
        return this.__show.get();
    }
    set show(newValue: boolean) {
        this.__show.set(newValue);
    }
    /** 关闭回调（点遮罩 / 选完 / 取消时触发） */
    private onClose: () => void;
    private __avatar: ObservedPropertyAbstractPU<string>;
    get avatar() {
        return this.__avatar.get();
    }
    set avatar(newValue: string) {
        this.__avatar.set(newValue);
    }
    private options: string[];
    /** 选中 emoji 头像 */
    private async choose(a: string): Promise<void> {
        await AppStore.getInstance().saveUserAvatar(a);
        this.onClose();
        promptAction.showToast({ message: '头像已更新' });
    }
    /** 从相册选择照片 → 拷贝到应用沙箱持久化 */
    private async pickFromGallery(): Promise<void> {
        try {
            const options = new photoAccessHelper.PhotoSelectOptions();
            options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
            options.maxSelectNumber = 1;
            const picker = new photoAccessHelper.PhotoViewPicker();
            const result = await picker.select(options);
            const uris: string[] = result.photoUris;
            if (uris.length === 0) {
                return;
            }
            const ctx = getContext(this) as common.UIAbilityContext;
            const destPath: string = `${ctx.filesDir}/avatar_${Date.now()}.jpg`;
            const src = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
            const dest = fileIo.openSync(destPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
            fileIo.copyFileSync(src.fd, dest.fd);
            fileIo.closeSync(src);
            fileIo.closeSync(dest);
            await AppStore.getInstance().saveUserAvatar(`file://${destPath}`);
            this.onClose();
            promptAction.showToast({ message: '头像已更新' });
        }
        catch (err) {
            promptAction.showToast({ message: '已取消选择' });
        }
    }
    panel(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.backgroundColor(Colors.CARD);
            Column.borderRadius({ topLeft: 24, topRight: 24 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部拖拽提示条
            Column.create();
            // 顶部拖拽提示条
            Column.width(38);
            // 顶部拖拽提示条
            Column.height(4);
            // 顶部拖拽提示条
            Column.backgroundColor('#E2DCD5');
            // 顶部拖拽提示条
            Column.borderRadius(2);
            // 顶部拖拽提示条
            Column.margin({ top: 8, bottom: 14 });
        }, Column);
        // 顶部拖拽提示条
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('选择头像');
            Text.fontSize(18);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.width('100%');
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 从相册选择真实照片
            Row.create();
            // 从相册选择真实照片
            Row.width('100%');
            // 从相册选择真实照片
            Row.padding({ left: 16, right: 16, top: 14, bottom: 14 });
            // 从相册选择真实照片
            Row.backgroundColor(Colors.BG);
            // 从相册选择真实照片
            Row.borderRadius(Radius.MD);
            // 从相册选择真实照片
            Row.margin({ left: 20, right: 20, top: 16 });
            // 从相册选择真实照片
            Row.onClick(() => {
                this.pickFromGallery();
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('🖼️');
            Text.fontSize(20);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('从相册选择照片');
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_PRIMARY);
            Text.margin({ left: 12 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('›');
            Text.fontSize(18);
            Text.fontColor(Colors.TEXT_TERTIARY);
        }, Text);
        Text.pop();
        // 从相册选择真实照片
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('或选一个 emoji 头像');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.width('100%');
            Text.textAlign(TextAlign.Center);
            Text.margin({ top: 18, bottom: 12 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Grid.create();
            Grid.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr');
            Grid.rowsGap(12);
            Grid.columnsGap(12);
            Grid.height(196);
            Grid.width('100%');
            Grid.padding({ left: 20, right: 20 });
        }, Grid);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const a = _item;
                {
                    const itemCreation2 = (elmtId, isInitialRender) => {
                        GridItem.create(() => { }, false);
                    };
                    const observedDeepRender = () => {
                        this.observeComponentCreation2(itemCreation2, GridItem);
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            Column.create();
                            Column.width('100%');
                            Column.height('100%');
                            Column.justifyContent(FlexAlign.Center);
                            Column.onClick(() => {
                                this.choose(a);
                            });
                        }, Column);
                        {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                if (isInitialRender) {
                                    let componentCall = new UserAvatar(this, { avatar: a, diameter: 44, bg: this.avatar === a ? Colors.PRIMARY_SOFT : Colors.BG }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/AvatarPicker.ets", line: 115, col: 15 });
                                    ViewPU.create(componentCall);
                                    let paramsLambda = () => {
                                        return {
                                            avatar: a,
                                            diameter: 44,
                                            bg: this.avatar === a ? Colors.PRIMARY_SOFT : Colors.BG
                                        };
                                    };
                                    componentCall.paramsGenerator_ = paramsLambda;
                                }
                                else {
                                    this.updateStateVarsOfChildByElmtId(elmtId, {
                                        avatar: a, diameter: 44, bg: this.avatar === a ? Colors.PRIMARY_SOFT : Colors.BG
                                    });
                                }
                            }, { name: "UserAvatar" });
                        }
                        Column.pop();
                        GridItem.pop();
                    };
                    observedDeepRender();
                }
            };
            this.forEachUpdateFunction(elmtId, this.options, forEachItemGenFunction, (a: string) => a, false, false);
        }, ForEach);
        ForEach.pop();
        Grid.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('取消');
            Button.width('100%');
            Button.height(46);
            Button.fontSize(15);
            Button.fontColor(Colors.TEXT_SECONDARY);
            Button.backgroundColor(Colors.BG);
            Button.borderRadius(Radius.MD);
            Button.margin({ left: 20, right: 20, top: 18, bottom: 26 });
            Button.onClick(() => {
                this.onClose();
            });
        }, Button);
        Button.pop();
        Column.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.show) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Stack.create({ alignContent: Alignment.Bottom });
                        Stack.width('100%');
                        Stack.height('100%');
                    }, Stack);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 遮罩：点空白处关闭
                        Column.create();
                        // 遮罩：点空白处关闭
                        Column.width('100%');
                        // 遮罩：点空白处关闭
                        Column.height('100%');
                        // 遮罩：点空白处关闭
                        Column.backgroundColor('#66000000');
                        // 遮罩：点空白处关闭
                        Column.onClick(() => {
                            this.onClose();
                        });
                    }, Column);
                    // 遮罩：点空白处关闭
                    Column.pop();
                    this.panel.bind(this)();
                    Stack.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
