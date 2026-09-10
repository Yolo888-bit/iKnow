import { Colors, Radius } from '../common/Theme'

/** 任务卡片（勾选 + 标题 + 学科 + 预计时长） */
@Component
export struct TaskCard {
  @Prop title: string = ''
  @Prop subject: string = ''
  @Prop minutes: number = 0
  @Prop done: boolean = false
  @Prop showCheckbox: boolean = true
  onToggle: () => void = () => {
  }

  build() {
    Row() {
      if (this.showCheckbox) {
        Checkbox()
          .select(this.done)
          .selectedColor(Colors.PRIMARY)
          .width(22)
          .height(22)
          .onChange((val: boolean) => {
            this.onToggle()
          })
      }

      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.done ? Colors.TEXT_TERTIARY : Colors.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .decoration({ type: this.done ? TextDecorationType.LineThrough : TextDecorationType.None, color: Colors.TEXT_TERTIARY })

        Row() {
          Text(this.subject)
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
          Text('·')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ left: 6, right: 6 })
          Text(`${this.minutes} min`)
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: this.showCheckbox ? 12 : 0 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.MD)
  }
}
