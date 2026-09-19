import { router } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { FocusController } from '../services/FocusController'
import { FocusTuning } from '../common/FocusTuning'
import { TimeUtils } from '../utils/TimeUtils'

/** 休息页 —— 休息态由 FocusController 独占，本页只做展示与出口 */
@Entry
@Component
export struct FocusBreak {
  @StorageProp(StorageKey.FOCUS_BREAK_REMAIN) restRemain: number = FocusTuning.BREAK_TOTAL_SEC
  @State ending: boolean = false

  aboutToDisappear(): void {
    this.leaveBreak()
  }

  onBackPress(): boolean {
    this.leaveBreak()
    router.back()
    return true
  }

  /** 离开休息页即归还状态机，避免 resting 悬空导致计时冻结 */
  private leaveBreak(): void {
    const c = FocusController.getInstance()
    if (c.isResting()) {
      c.endBreak()
    }
  }

  private continueFocus(): void {
    FocusController.getInstance().endBreak()
    router.back()
  }

  private extend(): void {
    FocusController.getInstance().extendBreak(FocusTuning.BREAK_EXTEND_SEC)
  }

  private async endFlow(): Promise<void> {
    if (this.ending) {
      return
    }
    this.ending = true
    try {
      await AppStore.getInstance().endSession()
    } catch (e) {
      await AppStore.getInstance().syncAfterSession()
    } finally {
      this.ending = false
    }
    router.replaceUrl({ url: 'pages/StudyReport' })
  }

  build() {
    Column() {
      Text(this.restRemain <= 0 ? '休息结束啦' : '休息一下吧')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)

      Text(TimeUtils.formatClock(this.restRemain))
        .fontSize(60)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .margin({ top: 24 })

      Text(this.restRemain <= 0 ? '准备继续了吗？' : '让眼睛和肩膀放松一下')
        .fontSize(14)
        .fontColor(Colors.TEXT_SECONDARY)
        .margin({ top: 12 })

      Button('继续专注')
        .width('70%')
        .height(48)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor(Colors.PRIMARY_STRONG)
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
          this.extend()
        })

      Button('结束本次专注')
        .width('70%')
        .height(48)
        .fontSize(15)
        .fontColor(Colors.TEXT_SECONDARY)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .margin({ top: 12 })
        .onClick(() => {
          this.endFlow()
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Colors.BG)
  }
}
