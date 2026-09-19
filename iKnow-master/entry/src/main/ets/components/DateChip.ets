import { Colors } from '../common/Theme'

/**
 * 动态日历图标
 *
 * 外形是一个日历（顶部彩条 + 两个挂环），里面的数字**随日期变化**：
 * 今天是 19 号就显示 19，不会是一个写死的日历 emoji。
 * 工作台 / 复盘页共用，保证视觉一致。
 */
@Component
export struct DateChip {
  /** 要显示的日期数字（1~31） */
  @Prop day: number = 1
  /** 整体宽度（高度约为宽度的 1.1 倍，多出来的部分给顶部挂环） */
  @Prop chipSize: number = 42
  /** 顶部彩条颜色 */
  @Prop accent: string = Colors.PRIMARY

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        // 顶部彩条
        Row()
          .width('100%')
          .height(this.chipSize * 0.25)
          .backgroundColor(this.accent)
        // 日期数字
        Text(`${this.day}`)
          .fontSize(this.chipSize * 0.38)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width(this.chipSize)
      .height(this.chipSize * 1.05)
      .backgroundColor(Colors.CARD)
      .borderRadius(this.chipSize * 0.26)
      .border({ width: 1, color: Colors.LINE })
      .clip(true)

      // 两个挂环，强化「日历」外形
      Row({ space: this.chipSize * 0.30 }) {
        Column()
          .width(this.chipSize * 0.07)
          .height(this.chipSize * 0.15)
          .backgroundColor(Colors.PRIMARY_DARK)
          .borderRadius(2)
        Column()
          .width(this.chipSize * 0.07)
          .height(this.chipSize * 0.15)
          .backgroundColor(Colors.PRIMARY_DARK)
          .borderRadius(2)
      }
      .offset({ y: -this.chipSize * 0.07 })
    }
    .width(this.chipSize)
    .height(this.chipSize * 1.1)
  }
}
