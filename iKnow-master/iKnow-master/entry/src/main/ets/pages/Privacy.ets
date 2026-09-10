import { promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'

/** 隐私与数据（合规：分项授权 + 数据管理） */
@Entry
@Component
export struct Privacy {
  @State allowCamera: boolean = true
  @State allowMic: boolean = true
  @State allowHealth: boolean = false
  @State showClearConfirm: boolean = false

  private doClearAll(): void {
    this.showClearConfirm = false
    AppStore.getInstance().clearAll().then(() => {
      promptAction.showToast({ message: '✓ 数据已彻底销毁' })
    })
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: Spacing.LG }) {
          Text('隐私与数据')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')

          // 摄像头数据
          Column() {
            Text('摄像头数据')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')

            Text('仅用于实时分析专注状态')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .width('100%')
              .margin({ top: 6 })

            Text('✓ 本地分析\n✓ 不上传\n✓ 不保存原始视频')
              .fontSize(13)
              .fontColor(Colors.GREEN)
              .lineHeight(22)
              .width('100%')
              .margin({ top: 10 })
          }
          .privacyCard()

          // 生理数据（分项授权，不支持一键全部授权）
          Column() {
            Text('生理数据 · 分项授权')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 8 })

            this.authRow('允许摄像头', this.allowCamera, (v: boolean) => {
              this.allowCamera = v
            })
            this.authRow('允许麦克风', this.allowMic, (v: boolean) => {
              this.allowMic = v
            })
            this.authRow('允许健康数据', this.allowHealth, (v: boolean) => {
              this.allowHealth = v
            })
          }
          .privacyCard()

          // 数据管理
          Column() {
            Text('数据管理')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')

            Button('清除学习数据')
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontColor(Colors.TEXT_PRIMARY)
              .backgroundColor(Colors.CARD)
              .borderRadius(Radius.MD)
              .margin({ top: 12 })
              .onClick(() => {
                AppStore.getInstance().clearLearningData().then(() => {
                  promptAction.showToast({ message: '学习数据已清除' })
                })
              })

            Button('清除生理数据')
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontColor(Colors.TEXT_PRIMARY)
              .backgroundColor(Colors.CARD)
              .borderRadius(Radius.MD)
              .margin({ top: 10 })
              .onClick(() => {
                AppStore.getInstance().clearPhysioData().then(() => {
                  promptAction.showToast({ message: '当前为模拟模式，无持久化生理数据' })
                })
              })

            Button('清除全部数据')
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor(Colors.CAMERA_RED)
              .borderRadius(Radius.MD)
              .margin({ top: 10 })
              .onClick(() => {
                this.showClearConfirm = true
              })
          }
          .privacyCard()

          Blank().height(20)
        }
        .padding(20)
        .width('100%')
      }
      .width('100%')
      .height('100%')

      // 二次确认弹窗
      if (this.showClearConfirm) {
        Column() {
          Column() {
            Text('确定清除所有学习记录和生理数据吗？')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('该操作不可恢复。')
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
                  this.showClearConfirm = false
                })
              Button('确认清除')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(Colors.CAMERA_RED)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  this.doClearAll()
                })
            }
            .margin({ top: 20 })
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
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }

  @Builder
  authRow(label: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(Colors.TEXT_PRIMARY)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(Colors.PRIMARY)
        .onChange((v: boolean) => {
          onChange(v)
        })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }
}

@Extend(Column)
function privacyCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
