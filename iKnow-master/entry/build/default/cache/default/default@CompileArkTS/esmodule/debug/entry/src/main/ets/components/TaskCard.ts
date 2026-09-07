if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface TaskCard_Params {
    title?: string;
    subject?: string;
    minutes?: number;
    done?: boolean;
    showCheckbox?: boolean;
    onToggle?: () => void;
}
import { Colors, Radius } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class TaskCard extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__title = new SynchedPropertySimpleOneWayPU(params.title, this, "title");
        this.__subject = new SynchedPropertySimpleOneWayPU(params.subject, this, "subject");
        this.__minutes = new SynchedPropertySimpleOneWayPU(params.minutes, this, "minutes");
        this.__done = new SynchedPropertySimpleOneWayPU(params.done, this, "done");
        this.__showCheckbox = new SynchedPropertySimpleOneWayPU(params.showCheckbox, this, "showCheckbox");
        this.onToggle = () => {
        };
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: TaskCard_Params) {
        if (params.title === undefined) {
            this.__title.set('');
        }
        if (params.subject === undefined) {
            this.__subject.set('');
        }
        if (params.minutes === undefined) {
            this.__minutes.set(0);
        }
        if (params.done === undefined) {
            this.__done.set(false);
        }
        if (params.showCheckbox === undefined) {
            this.__showCheckbox.set(true);
        }
        if (params.onToggle !== undefined) {
            this.onToggle = params.onToggle;
        }
    }
    updateStateVars(params: TaskCard_Params) {
        this.__title.reset(params.title);
        this.__subject.reset(params.subject);
        this.__minutes.reset(params.minutes);
        this.__done.reset(params.done);
        this.__showCheckbox.reset(params.showCheckbox);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__title.purgeDependencyOnElmtId(rmElmtId);
        this.__subject.purgeDependencyOnElmtId(rmElmtId);
        this.__minutes.purgeDependencyOnElmtId(rmElmtId);
        this.__done.purgeDependencyOnElmtId(rmElmtId);
        this.__showCheckbox.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__title.aboutToBeDeleted();
        this.__subject.aboutToBeDeleted();
        this.__minutes.aboutToBeDeleted();
        this.__done.aboutToBeDeleted();
        this.__showCheckbox.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __title: SynchedPropertySimpleOneWayPU<string>;
    get title() {
        return this.__title.get();
    }
    set title(newValue: string) {
        this.__title.set(newValue);
    }
    private __subject: SynchedPropertySimpleOneWayPU<string>;
    get subject() {
        return this.__subject.get();
    }
    set subject(newValue: string) {
        this.__subject.set(newValue);
    }
    private __minutes: SynchedPropertySimpleOneWayPU<number>;
    get minutes() {
        return this.__minutes.get();
    }
    set minutes(newValue: number) {
        this.__minutes.set(newValue);
    }
    private __done: SynchedPropertySimpleOneWayPU<boolean>;
    get done() {
        return this.__done.get();
    }
    set done(newValue: boolean) {
        this.__done.set(newValue);
    }
    private __showCheckbox: SynchedPropertySimpleOneWayPU<boolean>;
    get showCheckbox() {
        return this.__showCheckbox.get();
    }
    set showCheckbox(newValue: boolean) {
        this.__showCheckbox.set(newValue);
    }
    private onToggle: () => void;
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(16);
            Row.backgroundColor(Colors.CARD);
            Row.borderRadius(Radius.MD);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.showCheckbox) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Checkbox.create();
                        Checkbox.select(this.done);
                        Checkbox.selectedColor(Colors.PRIMARY);
                        Checkbox.width(22);
                        Checkbox.height(22);
                        Checkbox.onChange((val: boolean) => {
                            this.onToggle();
                        });
                    }, Checkbox);
                    Checkbox.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.margin({ left: this.showCheckbox ? 12 : 0 });
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.title);
            Text.fontSize(16);
            Text.fontColor(this.done ? Colors.TEXT_TERTIARY : Colors.TEXT_PRIMARY);
            Text.fontWeight(FontWeight.Medium);
            Text.decoration({ type: this.done ? TextDecorationType.LineThrough : TextDecorationType.None, color: Colors.TEXT_TERTIARY });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.margin({ top: 4 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.subject);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('·');
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_TERTIARY);
            Text.margin({ left: 6, right: 6 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.minutes} min`);
            Text.fontSize(12);
            Text.fontColor(Colors.TEXT_SECONDARY);
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
