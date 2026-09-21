import { Colors, Radius } from '../common/Theme'

/**
 * 科目 / 任务列表编辑器：**一块一行，用户可自行添加行**。
 *
 * 引导向导（登录后设置目标）与「长期计划与目标」页共用同一套交互，
 * 避免两处各写一份、口径不一致。
 *
 * 用法：`SubjectListEditor({ items: this.subjects, onChange: (v) => { this.subjects = v }, ... })`
 *
 * 刻意用「`@Prop` 传值 + `onChange` 回调」而不是 `@Link`：本项目在 Tabs 子页面 / 深层自定义组件里
 * `@Link` 出过同步问题，回调式更稳（与 AvatarPicker 同一套做法）。
 */
@Component
export struct SubjectListEditor {
  @Prop items: string[] = []
  /** 列表变化后整体回传（数组元素是基础类型，必须整体替换父组件的数组才会刷新） */
  onChange: (items: string[]) => void = () => {
  }
  @Prop placeholder: string = '输入科目或任务名称'
  @Prop addLabel: string = '添加一行'
  @Prop maxRows: number = 15
  /** 可选的快捷添加项（按目标类型给），点了就补一行 */
  @Prop suggestions: string[] = []

  private setName(index: number, v: string): void {
    const next: string[] = this.items.slice()
    next[index] = v
    this.onChange(next)
  }

  private addRow(name: string): void {
    if (this.items.length >= this.maxRows) {
      return
    }
    const next: string[] = this.items.slice()
    next.push(name)
    this.onChange(next)
  }

  private removeRow(index: number): void {
    const next: string[] = []
    for (let i = 0; i < this.items.length; i++) {
      if (i !== index) {
        next.push(this.items[i])
      }
    }
    this.onChange(next)
  }

  /** 快捷项是否已经在列表里（已加过就不再重复加） */
  private alreadyHas(name: string): boolean {
    for (const s of this.items) {
      if (s.trim() === name) {
        return true
      }
    }
    return false
  }

  build() {
    Column({ space: 8 }) {
      // 一行一项
      ForEach(this.items, (item: string, index: number) => {
        Row() {
          Text(`${index + 1}`)
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .width(20)
            .textAlign(TextAlign.Center)

          TextInput({ placeholder: this.placeholder, text: item })
            .fontSize(15)
            .height(46)
            .layoutWeight(1)
            .margin({ left: 6 })
            .backgroundColor(Colors.BG)
            .borderRadius(Radius.SM)
            .maxLength(20)
            .onChange((v: string) => {
              this.setName(index, v)
            })

          // 删除这一行
          Text('✕')
            .fontSize(14)
            .fontColor(Colors.TEXT_TERTIARY)
            .width(34)
            .height(46)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.removeRow(index)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }, (item: string, index: number) => `row_${index}`)

      // 添加一行
      Row() {
        Text('＋')
          .fontSize(15)
          .fontColor(Colors.PRIMARY_DARK)
        Text(this.addLabel)
          .fontSize(14)
          .fontColor(Colors.PRIMARY_DARK)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Colors.PRIMARY_SOFT)
      .borderRadius(Radius.SM)
      .opacity(this.items.length >= this.maxRows ? 0.5 : 1)
      .onClick(() => {
        this.addRow('')
      })

      // 快捷添加
      if (this.suggestions.length > 0) {
        Column() {
          Text('常用科目（点一下直接添加）')
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .margin({ bottom: 8 })

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.suggestions, (s: string) => {
              Text(s)
                .fontSize(13)
                .fontColor(this.alreadyHas(s) ? Colors.TEXT_TERTIARY : Colors.PRIMARY_DARK)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.alreadyHas(s) ? Colors.BG_ALT : Colors.PRIMARY_SOFT)
                .borderRadius(14)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  if (!this.alreadyHas(s)) {
                    this.addRow(s)
                  }
                })
            }, (s: string) => `sg_${s}`)
          }
          .width('100%')
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
