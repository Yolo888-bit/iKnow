import { router } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { FocusController } from '../services/FocusController'
import { FocusTuning } from '../common/FocusTuning'
import { TimeUtils } from '../utils/TimeUtils'
import { EndSessionDialog } from '../components/EndSessionDialog'

/**
 * 休息页 —— 休息态由 FocusController 独占，本页只做展示与出口。
 *
 * 结束专注的路径与专注页**完全一致**（同一个 `EndSessionDialog` 两步确认）：
 * 休息/暂停期间也能结束，选择「生成复盘」或「直接结束」，
 * 后者再确认一次且**不记录本次数据**。
 */
@Entry
@Component
export struct FocusBreak {
  @StorageProp(StorageKey.FOCUS_BREAK_REMAIN) restRemain: number = FocusTuning.BREAK_TOTAL_SEC
  @State ending: boolean = false
  /** 结束确认第一层（选「生成复盘 / 直接结束」） */
  @State showEndConfirm: boolean = false
  /** 结束确认第二层（「直接结束」的二次确认） */
  @State showDiscardConfirm: boolean = false

  aboutToDisappear(): void {
    this.leaveBreak()
  }

  onBackPress(): boolean {
    // 弹层开着时先关弹层，不要一下跳回专注页
    if (this.showDiscardConfirm) {
      this.showDiscardConfirm = false
      return true
    }
    if (this.showEndConfirm) {
      this.showEndConfirm = false
      return true
    }
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

  /**
   * 把「结束」交给专注页执行 —— 本页自己不结束、也不导航到复盘。
   *
   * 栈是「根页 → 专注页 → 本页」，本页无论 `back()` 还是 `back(index)` 都不够稳
   * （前者落在已结束的专注页上，后者依赖版本行为）。交回专注页后，
   * 休息页结束与专注页结束**走同一段代码**，落点必然是「复盘」，文案也不会分叉。
   */
  private requestEnd(mode: number): void {
    if (this.ending) {
      return
    }
    this.ending = true
    this.showEndConfirm = false
    this.showDiscardConfirm = false
    // 先归还状态机（结束休息段），再退回专注页；否则专注页会停在"休息中"
    this.leaveBreak()
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_END_REQUEST, mode)
    router.back()
  }

  build() {
    Stack() {
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

        // 休息中也能结束：走与专注页同一套两步确认
        Button('结束本次专注')
          .width('70%')
          .height(48)
          .fontSize(15)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.CARD)
          .borderRadius(Radius.LG)
          .margin({ top: 12 })
          .onClick(() => {
            this.showEndConfirm = true
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Colors.BG)

      // 结束确认：两步（先选「生成复盘 / 直接结束」，直接结束再确认一次）
      if (this.showEndConfirm || this.showDiscardConfirm) {
        EndSessionDialog({
          confirming: this.showDiscardConfirm,
          onClose: () => {
            this.showEndConfirm = false
            this.showDiscardConfirm = false
          },
          onReport: () => {
            // 1 = 生成复盘
            this.requestEnd(1)
          },
          onAskDiscard: () => {
            this.showDiscardConfirm = true
          },
          onDiscard: () => {
            // 2 = 直接结束（丢弃本次数据）
            this.requestEnd(2)
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
