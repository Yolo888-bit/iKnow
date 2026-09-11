import { Colors, Radius } from '../common/Theme'
import { StorageKey } from '../common/Constants'

/**
 * AI 智能体首次身份声明（硬规则 §11）
 *
 *  - 所有 AI 页面顶部均有 AITag 标识；本组件负责"首次进入时说明我不是真人"。
 *  - 通过 AppStorage 全局键保证整个 App 生命周期只弹一次；关闭后写入标记。
 *  - 组件以绝对定位全屏覆盖层呈现，本身不参与页面正常布局流。
 */
@Component
export struct AIFirstDisclaimer {
  @StorageProp(StorageKey.AI_DISCLAIMER_SHOWN) shown: boolean = false

  build() {
    if (this.shown) {
      Column() {}
    } else {
      Column() {
        Column() {
          Text('关于小伴')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Text('我是 AI 智能体，不是真人。我会陪你专注、答疑、复盘，' +
            '但不能替代老师、医生或心理咨询师。所有内容仅供参考。')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(22)
            .margin({ top: 12 })
            .width('100%')
          Button('我知道了')
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY)
            .borderRadius(Radius.MD)
            .margin({ top: 20 })
            .onClick(() => {
              AppStorage.setOrCreate<boolean>(StorageKey.AI_DISCLAIMER_SHOWN, true)
            })
        }
        .width('82%')
        .padding(24)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .position({ x: 0, y: 0 })
    }
  }
}
