import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { FocusController } from '../services/FocusController'
import { FocusDetectionService } from '../services/FocusDetectionService'
import { Task } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusStateUi } from '../common/FocusStateUi'
import { FocusTimer } from '../components/FocusTimer'
import { BreathingLight } from '../components/BreathingLight'
import { AITag } from '../components/AITag'

/** 专注模式 —— 极简沉浸 + 状态机 */
@Entry
@Component
export struct Focus {
  @StorageProp(StorageKey.FOCUS_ELAPSED) elapsed: number = 0
  @StorageProp(StorageKey.FOCUS_NET) net: number = 0
  @StorageProp(StorageKey.FOCUS_STATE) focusState: string = 'FOCUSED'
  @State taskTitle: string = '自由专注'
  @State taskSubject: string = '无任务'
  @State showEndConfirm: boolean = false
  @State ending: boolean = false

  aboutToAppear(): void {
    const controller = FocusController.getInstance()
    if (!controller.isRunning()) {
      controller.start(AppStore.getInstance().getCurrentPlan())
    }
    this.refreshTask()
  }

  private refreshTask(): void {
    const plan = AppStore.getInstance().getCurrentPlan()
    let cur: Task | null = null
    for (const t of plan) {
      if (!t.done) {
        cur = t
        break
      }
    }
    if (cur === null && plan.length > 0) {
      cur = plan[0]
    }
    if (cur !== null) {
      this.taskTitle = cur.title
      this.taskSubject = cur.subject
    }
  }

  private togglePause(): void {
    const c = FocusController.getInstance()
    if (c.isPaused()) {
      c.resume()
    } else {
      c.pause()
    }
  }

  private rest(): void {
    FocusController.getInstance().startBreak()
    router.pushUrl({ url: 'pages/FocusBreak' })
  }

  private openQA(): void {
    FocusController.getInstance().startQA()
    router.pushUrl({ url: 'pages/AIChat' })
  }

  private continueFromRed(): void {
    FocusDetectionService.getInstance().resume()
  }

  private async endFlow(showReport: boolean): Promise<void> {
    if (this.ending) {
      return
    }
    this.ending = true
    await AppStore.getInstance().endSession()
    this.ending = false
    if (showReport) {
      router.replaceUrl({ url: 'pages/StudyReport' })
    } else {
      router.back()
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 顶部合规栏：红色摄像头指示灯 + AI 智能体标签
        Row() {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(Colors.CAMERA_RED)
            Text('摄像头感知中')
              .fontSize(12)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ left: 6 })
          }
          Blank()
          AITag()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 8 })

        // 主体
        Column() {
          Text(this.taskSubject)
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
          Text(this.taskTitle)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .margin({ top: 4 })
          Text('当前任务')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 4 })

          FocusTimer({ seconds: this.elapsed, big: true })
            .margin({ top: 40 })

          Text(`已专注 ${TimeUtils.formatHMin(this.net)}`)
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 8 })

          BreathingLight({
            state: this.focusState,
            onTap: () => {
              FocusController.getInstance().demoCycleState()
            }
          })
            .margin({ top: 48 })

          Text(FocusStateUi.label(this.focusState))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .margin({ top: 24 })
          Text(FocusStateUi.subLabel(this.focusState))
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 6 })

          // 红灯：AI 主动询问（给选择，不指责）
          if (this.focusState === 'DISTRACTED') {
            Column() {
              Text('注意到你离开有一会儿了。')
                .fontSize(15)
                .fontColor(Colors.TEXT_PRIMARY)
                .margin({ top: 24 })
              Text('需要休息一下，还是继续学习？')
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 6 })

              Row({ space: 10 }) {
                Button('继续学习')
                  .fontSize(13)
                  .fontColor(Color.White)
                  .backgroundColor(Colors.PRIMARY)
                  .height(38)
                  .borderRadius(19)
                  .onClick(() => {
                    this.continueFromRed()
                  })
                Button('休息一下')
                  .fontSize(13)
                  .fontColor(Colors.TEXT_PRIMARY)
                  .backgroundColor(Colors.CARD)
                  .height(38)
                  .borderRadius(19)
                  .onClick(() => {
                    this.rest()
                  })
                Button('结束本次专注')
                  .fontSize(13)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .backgroundColor(Colors.CARD)
                  .height(38)
                  .borderRadius(19)
                  .onClick(() => {
                    this.showEndConfirm = true
                  })
              }
              .margin({ top: 16 })
            }
            .width('86%')
            .padding(16)
            .backgroundColor(Colors.RED_SOFT)
            .borderRadius(Radius.LG)
          }

          // 暂停：轻量恢复
          if (this.focusState === 'PAUSED') {
            Column() {
              Text('已暂停')
                .fontSize(15)
                .fontColor(Colors.TEXT_PRIMARY)
              Button('继续专注')
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor(Colors.PRIMARY)
                .height(40)
                .borderRadius(20)
                .margin({ top: 12 })
                .onClick(() => {
                  FocusController.getInstance().resume()
                })
            }
            .width('86%')
            .padding(16)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.LG)
            .margin({ top: 24 })
          }
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .layoutWeight(1)

        // 底部控制
        Row({ space: 12 }) {
          Button(this.focusState === 'PAUSED' ? '继续' : '暂停')
            .layoutWeight(1)
            .height(46)
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.togglePause()
            })
          Button('休息')
            .layoutWeight(1)
            .height(46)
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.rest()
            })
          Button('结束')
            .layoutWeight(1)
            .height(46)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY_DARK)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.showEndConfirm = true
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 24, top: 8 })
      }
      .width('100%')
      .height('100%')

      // AI 答疑悬浮按钮（右下角半透明）
      Button('AI')
        .width(58)
        .height(58)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(Colors.PRIMARY)
        .opacity(0.92)
        .borderRadius(29)
        .margin({ right: 20, bottom: 90 })
        .shadow({ radius: 12, color: Colors.SHADOW, offsetX: 0, offsetY: 4 })
        .onClick(() => {
          this.openQA()
        })

      // 结束确认（AI 语气，二次确认）
      if (this.showEndConfirm) {
        Column() {
          Column() {
            Text('今天这一段辛苦了。')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('专注结束，需要我帮你总结一下这次学习吗？')
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
                  this.showEndConfirm = false
                  this.endFlow(false)
                })
              Button('生成复盘')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(Colors.PRIMARY)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  this.showEndConfirm = false
                  this.endFlow(true)
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
}
