import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { NavParams } from '../models/NavParams'

/** 通用占位页：用于尚未完善的模块（通知 / 关于 / 历史记录 / 周报 / 月报）。
 * 后续各模块补齐后，将其入口改为对应真实页面即可。 */
@Entry
@Component
export struct Placeholder {
  @State title: string = '模块'
  @State desc: string = '该模块正在完善中，敬请期待。'

  aboutToAppear(): void {
    const p = router.getParams() as NavParams
    if (p !== undefined && p !== null && p.title.length > 0) {
      this.title = p.title
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 10 })

      Column() {
        Text(this.desc)
          .fontSize(15)
          .fontColor(Colors.TEXT_SECONDARY)
          .lineHeight(24)
          .width('100%')
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Colors.CARD)
      .borderRadius(Radius.LG)
      .margin({ top: 8 })
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
