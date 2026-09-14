import { promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { DeviceService } from '../services/DeviceService'
import { DeviceInfo } from '../services/ServiceTypes'

/** 设备连接（含模拟设备模式） */
@Entry
@Component
export struct Device {
  @State devices: DeviceInfo[] = []
  @State simulateMode: boolean = true
  @State watchPresent: boolean = false

  aboutToAppear(): void {
    this.refresh()
  }

  private refresh(): void {
    this.devices = DeviceService.getInstance().getDevices()
    this.simulateMode = DeviceService.getInstance().isSimulateMode()
    this.watchPresent = DeviceService.getInstance().isWatchPresent()
  }

  private icon(type: string): string {
    if (type === 'CAMERA') {
      return '📷'
    }
    if (type === 'WATCH') {
      return '⌚'
    }
    return '📱'
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        Text('设备连接')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

        Column({ space: Spacing.SM }) {
          ForEach(this.devices, (d: DeviceInfo) => {
            Row() {
              Text(this.icon(d.type)).fontSize(26)
              Column() {
                Text(d.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Colors.TEXT_PRIMARY)
                Text(d.statusText)
                  .fontSize(12)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 14 })
              .layoutWeight(1)

              Row() {
                Circle()
                  .width(8)
                  .height(8)
                  .fill(d.connected ? Colors.GREEN : Colors.TEXT_TERTIARY)
                Text(d.connected ? '已连接' : '未连接')
                  .fontSize(12)
                  .fontColor(d.connected ? Colors.GREEN : Colors.TEXT_SECONDARY)
                  .margin({ left: 6 })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
          }, (d: DeviceInfo) => d.type)
        }
        .width('100%')

        // 模拟设备模式
        Column() {
          Text('模拟设备模式')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')

          Text('当前为 MVP 演示，手表为模拟设备（默认未佩戴）。未佩戴时红级干预走手机声音与屏幕，不会假装震动。可手动触发状态，验证专注页的绿/黄/红联动。')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(20)
            .width('100%')
            .margin({ top: 8 })

          Row() {
            Column() {
              Text('模拟佩戴手表')
                .fontSize(15)
                .fontColor(Colors.TEXT_PRIMARY)
              Text(this.watchPresent ? '已佩戴：红级干预尝试手表震动' : '未佩戴：红级干预走手机声音 + 屏幕')
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.watchPresent })
              .selectedColor(Colors.PRIMARY)
              .onChange((v: boolean) => {
                this.watchPresent = v
                DeviceService.getInstance().setWatchPresent(v)
                this.refresh()
              })
          }
          .width('100%')
          .padding({ top: 14, bottom: 4 })

          Row({ space: 10 }) {
            Button('模拟轻度分心')
              .layoutWeight(1)
              .height(42)
              .fontSize(13)
              .fontColor(Colors.TEXT_PRIMARY)
              .backgroundColor(Colors.YELLOW_SOFT)
              .borderRadius(Radius.MD)
              .onClick(() => {
                DeviceService.getInstance().simulateDistraction(false)
                promptAction.showToast({ message: '已模拟轻度分心' })
              })
            Button('模拟重度走神')
              .layoutWeight(1)
              .height(42)
              .fontSize(13)
              .fontColor(Colors.TEXT_PRIMARY)
              .backgroundColor(Colors.RED_SOFT)
              .borderRadius(Radius.MD)
              .onClick(() => {
                DeviceService.getInstance().simulateDistraction(true)
                promptAction.showToast({ message: '已模拟重度走神' })
              })
            Button('恢复专注')
              .layoutWeight(1)
              .height(42)
              .fontSize(13)
              .fontColor(Colors.TEXT_PRIMARY)
              .backgroundColor(Colors.GREEN_SOFT)
              .borderRadius(Radius.MD)
              .onClick(() => {
                DeviceService.getInstance().resumeFocus()
                promptAction.showToast({ message: '已恢复专注' })
              })
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .deviceCard()

        Blank().height(20)
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }
}

@Extend(Column)
function deviceCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
