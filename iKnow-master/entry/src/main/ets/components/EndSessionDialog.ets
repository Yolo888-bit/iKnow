import { Colors, Radius } from '../common/Theme'

/**
 * 结束专注的两步确认 —— **专注页与休息页共用**，保证两处的文案与口径不会分叉。
 *
 *   ① 先选：「生成复盘」（结束并保存）还是「直接结束」；
 *   ② 选「直接结束」后再确认一次 —— 本次专注**不记录任何数据**。
 *
 * 为什么把状态放在调用方（只传 `confirming`，不在这里存）：
 * 页面还要在 `onBackPress()` 里按"最上层先关"的顺序处理返回键，
 * 状态藏在组件内部的话页面就拿不到、一点返回就会跳到底层动作。
 *
 * 用法：由调用方决定挂载，`if (show || confirming) { EndSessionDialog({ ... }) }`。
 */
@Component
export struct EndSessionDialog {
  /** true = 正在显示第二层（"直接结束"的二次确认） */
  @Prop confirming: boolean = false
  /** 关掉弹层（点遮罩 / 取消 / 继续专注） */
  onClose: () => void = () => {
  }
  /** 生成复盘：结束并保存本次专注 */
  onReport: () => void = () => {
  }
  /** 第一层点「直接结束」→ 切到第二次确认 */
  onAskDiscard: () => void = () => {
  }
  /** 第二层点「确认结束」→ 丢弃本次专注（不落库、不计入统计） */
  onDiscard: () => void = () => {
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 遮罩与面板必须是**兄弟节点**：塞进同一个 Column 里，
      // 点面板本身会冒泡到遮罩，一点就把弹层关掉了。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.onClose()
        })

      if (this.confirming) {
        // 第二层：说清代价再让用户决定
        Column() {
          Text('直接结束？')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
          Text('直接结束将不会记录本次专注的数据信息，是否确认？')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 8 })

          Row({ space: 12 }) {
            Button('取消')
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontColor(Colors.TEXT_SECONDARY)
              .backgroundColor(Colors.BG)
              .borderRadius(Radius.MD)
              .onClick(() => {
                this.onClose()
              })
            Button('确认结束')
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor(Colors.PRIMARY_DARK)
              .borderRadius(Radius.MD)
              .onClick(() => {
                this.onDiscard()
              })
          }
          .margin({ top: 20 })
        }
        .width('82%')
        .padding(24)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
      } else {
        // 第一层：选择
        Column() {
          Text('今天这一段辛苦了。')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
          Text('专注结束，需要小伴帮你总结一下这次学习吗？')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 8 })

          Row({ space: 12 }) {
            Button('直接结束')
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontColor(Colors.TEXT_SECONDARY)
              .backgroundColor(Colors.BG)
              .borderRadius(Radius.MD)
              .onClick(() => {
                this.onAskDiscard()
              })
            Button('生成复盘')
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor(Colors.PRIMARY_STRONG)
              .borderRadius(Radius.MD)
              .onClick(() => {
                this.onReport()
              })
          }
          .margin({ top: 20 })

          Button('继续专注')
            .width('100%')
            .height(40)
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .backgroundColor(Color.Transparent)
            .margin({ top: 8 })
            .onClick(() => {
              this.onClose()
            })
        }
        .width('82%')
        .padding(24)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
      }
    }
    .width('100%')
    .height('100%')
  }
}
