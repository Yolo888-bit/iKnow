import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { FocusController } from '../services/FocusController'
import { FocusDetectionService } from '../services/FocusDetectionService'
import { SensorService } from '../services/SensorService'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusStateUi } from '../common/FocusStateUi'
import { InterventionEngine } from '../services/InterventionEngine'
import { InterventionEvent } from '../models/InterventionEvent'
import { FeedbackAction } from '../models/Enums'
import { CompanionDecision } from '../services/ai/CompanionService'
import { FocusTimer } from '../components/FocusTimer'
import { BreathingLight } from '../components/BreathingLight'
import { AITag } from '../components/AITag'

/** 专注模式 —— 极简沉浸 + 状态机 */
@Entry
@Component
export struct Focus {
  @StorageProp(StorageKey.FOCUS_ELAPSED) elapsed: number = 0
  @StorageProp(StorageKey.FOCUS_NET) net: number = 0
  @StorageProp(StorageKey.FOCUS_STATE) @Watch('onStateChanged') focusState: string = 'FOCUSED'
  @StorageProp(StorageKey.PERCEPTION_MODE) perceptionMode: string = 'PERCEPTION_FULL'
  @State taskTitle: string = '自由专注'
  @State taskSubject: string = '无任务'
  @State hasPlan: boolean = false
  @State planDone: number = 0
  @State planTotal: number = 0
  @State showEndConfirm: boolean = false
  @State ending: boolean = false
  /** 当前干预（来自 InterventionEngine，经 FocusController 回调送达） */
  @State interventionMsg: string = ''
  @State interventionLevel: string = ''
  @State interventionChannel: string = ''
  private interventionEvent: InterventionEvent | null = null

  aboutToAppear(): void {
    const controller = FocusController.getInstance()
    if (!controller.isRunning()) {
      // 只有"主动开始"才新开会话；否则（如从复盘返回）退回根页，避免静默开始一段新专注
      const raw: number | undefined = AppStorage.get<number>(StorageKey.FOCUS_START_REQUEST)
      const requested = raw !== undefined ? raw : 0
      AppStorage.setOrCreate<number>(StorageKey.FOCUS_START_REQUEST, 0)
      if (requested !== 1) {
        router.back()
        return
      }
      controller.start(AppStore.getInstance().getCurrentPlan())
    }
    // 干预链路接上 UI：引擎决策 → 横幅/卡片（原先 setOnIntervention 无人调用，链路是死的）
    controller.setOnIntervention((d: CompanionDecision, e: InterventionEvent) => {
      this.interventionEvent = e
      this.interventionMsg = d.message
      this.interventionLevel = d.level
      this.interventionChannel = d.channel
    })
    this.refreshTask()
  }

  aboutToDisappear(): void {
    FocusController.getInstance().setOnIntervention(null)
  }

  /** 回到专注态即清掉未处理的干预提示，避免红框常驻 */
  private onStateChanged(): void {
    if (this.focusState === 'FOCUSED') {
      this.clearIntervention()
    }
  }

  private clearIntervention(): void {
    this.interventionEvent = null
    this.interventionMsg = ''
    this.interventionLevel = ''
    this.interventionChannel = ''
  }

  private feedback(action: FeedbackAction, recovered: boolean): void {
    const e = this.interventionEvent
    if (e !== null) {
      InterventionEngine.getInstance().recordUserFeedback(e, action, recovered)
    }
    this.clearIntervention()
  }

  private channelText(): string {
    if (this.interventionChannel === 'watch-vibrate') {
      return '手表震动'
    }
    if (this.interventionChannel === 'phone-sound') {
      return '手机提醒'
    }
    if (this.interventionChannel === 'screen-select') {
      return '屏幕提示'
    }
    return ''
  }

  /** 感知依据：让"为什么现在变黄/红了"可解释 */
  private basisText(): string {
    const c = FocusController.getInstance()
    const d = c.getLastDetail()
    if (d.length === 0) {
      return this.perceptionMode === 'PERCEPTION_TIMER_ONLY' ? '依据：未开启感知（仅计时）' : '依据：等待感知数据…'
    }
    return `依据：${d} · 置信度 ${c.getLastConfidence()}%`
  }

  onBackPress(): boolean {
    if (this.showEndConfirm) {
      this.showEndConfirm = false
      return true
    }
    if (!FocusController.getInstance().isRunning()) {
      return false
    }
    // 保持会话运行返回上一页（根页会显示「继续专注」），避免幽灵会话
    router.back()
    return true
  }

  private refreshTask(): void {
    const c = FocusController.getInstance()
    this.hasPlan = c.getTaskCount() > 0
    this.planTotal = c.getTaskCount()
    this.planDone = c.getCompletedCount()
    const cur = c.getCurrentTask()
    if (cur !== null) {
      this.taskTitle = cur.title
      this.taskSubject = cur.subject
    } else if (this.hasPlan) {
      this.taskTitle = '今日任务已全部完成'
      this.taskSubject = '可以结束了'
    } else {
      this.taskTitle = '自由专注'
      this.taskSubject = '未设定任务'
    }
  }

  private completeTask(): void {
    if (!FocusController.getInstance().completeCurrentTask()) {
      return
    }
    AppStore.getInstance().setCurrentPlan(FocusController.getInstance().getTasks())
    AppStore.getInstance().syncPlan()
    this.refreshTask()
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
    const c = FocusController.getInstance()
    if (!c.isRunning() || c.isResting() || c.isQaMode()) {
      return
    }
    c.startBreak()
    router.pushUrl({ url: 'pages/FocusBreak' })
  }

  private openQA(): void {
    const c = FocusController.getInstance()
    if (!c.isRunning() || c.isPaused() || c.isResting() || c.isQaMode()) {
      return
    }
    c.startQA()
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
        // 顶部合规栏：感知状态指示灯 + AI 智能体标签
        Row() {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(this.perceptionMode === 'PERCEPTION_TIMER_ONLY' ? Colors.TEXT_TERTIARY : Colors.CAMERA_RED)
            Text(this.perceptionMode === 'PERCEPTION_TIMER_ONLY' ? '本次未开启感知' : '摄像头感知中')
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

          // 摄像头感知预览占位（开启感知时展示；仅计时模式不显示）
          if (this.perceptionMode === 'PERCEPTION_FULL') {
            Stack({ alignContent: Alignment.Center }) {
              Column() {
                Text('📷')
                  .fontSize(34)
                Text('AI 实时专注感知预览')
                  .fontSize(13)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ top: 6 })
              }
            }
            .width('100%')
            .height(150)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
            .margin({ top: 20 })
          }

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

          // 感知依据：说明"为什么现在是这个状态"
          Text(this.basisText())
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 6 })

          // 干预卡片（来自 InterventionEngine：LIGHT 提醒 / HEAVY 主动询问）
          if (this.interventionLevel.length > 0) {
            Column() {
              Row() {
                Text(this.interventionLevel === 'HEAVY' ? '🔔 需要休息一下吗' : '💡 小伴提醒')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Colors.TEXT_PRIMARY)
                Blank()
                Text(this.channelText())
                  .fontSize(11)
                  .fontColor(Colors.TEXT_TERTIARY)
              }
              .width('100%')

              Text(this.interventionMsg)
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 6 })
                .width('100%')

              Row({ space: 10 }) {
                Button('继续专注')
                  .fontSize(13)
                  .fontColor(Color.White)
                  .backgroundColor(Colors.PRIMARY)
                  .height(38)
                  .borderRadius(19)
                  .onClick(() => {
                    this.feedback(FeedbackAction.CONTINUE, true)
                    FocusDetectionService.getInstance().resume()
                  })
                Button('休息一下')
                  .fontSize(13)
                  .fontColor(Colors.TEXT_PRIMARY)
                  .backgroundColor(Colors.CARD)
                  .height(38)
                  .borderRadius(19)
                  .onClick(() => {
                    this.feedback(FeedbackAction.REST, false)
                    this.rest()
                  })
                if (this.interventionLevel === 'HEAVY') {
                  Button('结束本次')
                    .fontSize(13)
                    .fontColor(Colors.TEXT_SECONDARY)
                    .backgroundColor(Colors.CARD)
                    .height(38)
                    .borderRadius(19)
                    .onClick(() => {
                      this.feedback(FeedbackAction.END, false)
                      this.showEndConfirm = true
                    })
                }
              }
              .margin({ top: 12 })
            }
            .width('86%')
            .padding(14)
            .backgroundColor(this.interventionLevel === 'HEAVY' ? Colors.RED_SOFT : Colors.YELLOW_SOFT)
            .borderRadius(Radius.LG)
            .margin({ top: 20 })
          }

          // 当前任务：勾选完成（复盘完成率的数据来源）
          if (this.hasPlan) {
            Column() {
              Row() {
                Checkbox()
                  .select(this.planDone >= this.planTotal)
                  .selectedColor(Colors.PRIMARY)
                  .width(22)
                  .height(22)
                  .enabled(this.planDone < this.planTotal)
                  .onChange(() => {
                    this.completeTask()
                  })
                Column() {
                  Text(this.taskSubject)
                    .fontSize(12)
                    .fontColor(Colors.TEXT_SECONDARY)
                  Text(this.taskTitle)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.TEXT_PRIMARY)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })

                Text(`${this.planDone}/${this.planTotal}`)
                  .fontSize(13)
                  .fontColor(Colors.TEXT_SECONDARY)
              }
              .width('100%')

              Text('完成后勾选，复盘会统计完成率')
                .fontSize(11)
                .fontColor(Colors.TEXT_TERTIARY)
                .margin({ top: 8 })
            }
            .width('86%')
            .padding(14)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
            .margin({ top: 24 })
          }

          // 红灯：AI 主动询问（给选择，不指责）
          // 干预引擎已给出卡片时不再重复渲染，避免同一件事弹两次
          if (this.focusState === 'DISTRACTED' && this.interventionLevel.length === 0) {
            Column() {
              Text('注意到你离开有一会儿了。')
                .fontSize(15)
                .fontColor(Colors.TEXT_PRIMARY)
                .margin({ top: 24 })
              Text('需要休息一下，还是继续学习？')
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 6 })
              if (!SensorService.getInstance().isWristPresent()) {
                Text('（手机提醒，未连接手表，不会震动）')
                  .fontSize(12)
                  .fontColor(Colors.TEXT_TERTIARY)
                  .margin({ top: 8 })
              }

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
            .enabled(this.focusState !== 'RESTING' && this.focusState !== 'QA_MODE')
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
        .opacity(this.focusState === 'PAUSED' || this.focusState === 'RESTING' ? 0.4 : 0.92)
        .borderRadius(29)
        .margin({ right: 20, bottom: 90 })
        .shadow({ radius: 12, color: Colors.SHADOW, offsetX: 0, offsetY: 4 })
        .enabled(this.focusState !== 'PAUSED' && this.focusState !== 'RESTING')
        .onClick(() => {
          this.openQA()
        })

      // 结束确认（AI 语气，二次确认 + 可取消）
      if (this.showEndConfirm) {
        Stack({ alignContent: Alignment.Center }) {
          // 遮罩层：点击即取消
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              this.showEndConfirm = false
            })

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

            Button('继续专注')
              .width('100%')
              .height(40)
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .backgroundColor(Color.Transparent)
              .margin({ top: 8 })
              .onClick(() => {
                this.showEndConfirm = false
              })
          }
          .width('82%')
          .padding(24)
          .backgroundColor(Colors.CARD)
          .borderRadius(Radius.LG)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
