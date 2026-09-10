import { router } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { FocusController } from '../services/FocusController'
import { TimeUtils } from '../utils/TimeUtils'

/** 休息页 */
@Entry
@Component
export struct FocusBreak {
  @State restRemain: number = 300
  @State finished: boolean = false
  private timerId: number = -1

  aboutToAppear(): void {
    this.timerId = setInterval(() => {
      if (this.restRemain > 0) {
        this.restRemain--
        if (this.restRemain === 0) {
          this.finished = true
        }
      }
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private continueFocus(): void {
    FocusController.getInstance().endBreak()
    router.back()
  }

  build() {
    Column() {
      Text(this.finished ? '休息结束啦' : '休息一下吧')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)

      Text(TimeUtils.formatClock(this.restRemain))
        .fontSize(60)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .margin({ top: 24 })

      Text(this.finished ? '准备继续了吗？' : '让眼睛和肩膀放松一下')
        .fontSize(14)
        .fontColor(Colors.TEXT_SECONDARY)
        .margin({ top: 12 })

      Button('继续专注')
        .width('70%')
        .height(48)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor(Colors.PRIMARY)
        .borderRadius(Radius.LG)
        .margin({ top: 48 })
        .onClick(() => {
          this.continueFocus()
        })

      Button('再休息 5 分钟')
        .width('70%')
        .height(48)
        .fontSize(15)
        .fontColor(Colors.TEXT_SECONDARY)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .margin({ top: 12 })
        .onClick(() => {
          this.restRemain = 300
          this.finished = false
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Colors.BG)
  }
}
