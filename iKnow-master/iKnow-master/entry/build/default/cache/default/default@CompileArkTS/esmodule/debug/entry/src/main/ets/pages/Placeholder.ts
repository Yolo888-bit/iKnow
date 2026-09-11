if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Placeholder_Params {
    title?: string;
    desc?: string;
}
import router from "@ohos:router";
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import type { NavParams } from '../models/NavParams';
export class Placeholder extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__title = new ObservedPropertySimplePU('模块', this, "title");
        this.__desc = new ObservedPropertySimplePU('该模块正在完善中，敬请期待。', this, "desc");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Placeholder_Params) {
        if (params.title !== undefined) {
            this.title = params.title;
        }
        if (params.desc !== undefined) {
            this.desc = params.desc;
        }
    }
    updateStateVars(params: Placeholder_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__title.purgeDependencyOnElmtId(rmElmtId);
        this.__desc.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__title.aboutToBeDeleted();
        this.__desc.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __title: ObservedPropertySimplePU<string>;
    get title() {
        return this.__title.get();
    }
    set title(newValue: string) {
        this.__title.set(newValue);
    }
    private __desc: ObservedPropertySimplePU<string>;
    get desc() {
        return this.__desc.get();
    }
    set desc(newValue: string) {
        this.__desc.set(newValue);
    }
    aboutToAppear(): void {
        const p = router.getParams() as NavParams;
        if (p !== undefined && p !== null && p.title.length > 0) {
            this.title = p.title;
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.padding(20);
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(Colors.BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ left: 20, right: 20, top: 16, bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.title);
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(Colors.TEXT_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding(20);
            Column.backgroundColor(Colors.CARD);
            Column.borderRadius(Radius.LG);
            Column.margin({ top: 8 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.desc);
            Text.fontSize(15);
            Text.fontColor(Colors.TEXT_SECONDARY);
            Text.lineHeight(24);
            Text.width('100%');
        }, Text);
        Text.pop();
        Column.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Placeholder";
    }
}
registerNamedRoute(() => new Placeholder(undefined, {}), "", { bundleName: "com.iknow.study", moduleName: "entry", pagePath: "pages/Placeholder", pageFullPath: "entry/src/main/ets/pages/Placeholder", integratedHsp: "false", moduleType: "followWithHap" });
