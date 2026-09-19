/**
 * 服务卡片（2*2 / 2*4）—— 桌面上的「今日专注」概览
 *
 * 数据由 `EntryFormAbility` 通过 formBindingData 注入到 LocalStorage，
 * 卡片侧只读这 3 个键，不直接访问数据库。
 */
@Entry
@Component
struct WidgetCard {
  @LocalStorageProp('todayFocus') todayFocus: string = '0min'
  @LocalStorageProp('focusRate') focusRate: string = '0%'
  @LocalStorageProp('advice') advice: string = '开始一段专注吧'

  build() {
    Column() {
      Text('iKnow · 今日专注')
        .fontSize(12)
        .fontColor('#9A9188')
        .width('100%')

      Text(this.todayFocus)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F2A26')
        .width('100%')
        .margin({ top: 10 })

      Text(`净专注率 ${this.focusRate}`)
        .fontSize(12)
        .fontColor('#9A9188')
        .width('100%')
        .margin({ top: 4 })

      Text(this.advice)
        .fontSize(11)
        .fontColor('#C6BDB4')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FAF6F1')
  }
}
