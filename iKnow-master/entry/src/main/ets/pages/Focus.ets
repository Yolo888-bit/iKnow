import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { FocusController } from '../services/FocusController'
import { PermissionService } from '../services/PermissionService'
import { CameraService } from '../services/CameraService'
import { SensorService } from '../services/SensorService'
import { Task } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusStateUi } from '../common/FocusStateUi'
import { InterventionEngine } from '../services/InterventionEngine'
import { SimWorkbench } from '../components/SimWorkbench'
import { InterventionEvent } from '../models/InterventionEvent'
import { FeedbackAction, FocusState } from '../models/Enums'
import { CompanionDecision } from '../services/ai/CompanionService'
import { FocusTimer } from '../components/FocusTimer'
import { BreathingLight } from '../components/BreathingLight'
import { TaskCard } from '../components/TaskCard'
import { AITag } from '../components/AITag'

/**
 * 专注模式 —— 极简沉浸 + 状态机
 *
 * 结构约定（第三轮改造）：
 *  - 任务信息只出现一次（任务列表）；不再有顶部任务块 / 「当前任务」冗余标签。
 *  - 分心一律由「干预卡」承接（原遗留红灯卡已删除，不再重复提示）。
 *  - 主体包在 Scroll 内：基础状态内容不足一屏不滚动，卡片多时也不会与底部按钮交叠。
 *  - AI 答疑作为底部四按钮之一，不再用会压住内容的悬浮球。
 */
@Entry
@Component
export struct Focus {
  @StorageProp(StorageKey.FOCUS_ELAPSED) elapsed: number = 0
  @StorageProp(StorageKey.FOCUS_NET) net: number = 0
  /** 总学习秒数（墙钟 − 休息 − 暂停），与复盘页口径一致 */
  @StorageProp(StorageKey.FOCUS_STUDY) studySec: number = 0
  @StorageProp(StorageKey.FOCUS_STATE) @Watch('onStateChanged') focusState: string = 'FOCUSED'
  @StorageProp(StorageKey.PERCEPTION_MODE) perceptionMode: string = 'PERCEPTION_FULL'
  @State tasks: Task[] = []
  @State currentTaskId: string = ''
  @State hasPlan: boolean = false
  @State planDone: number = 0
  @State planTotal: number = 0
  /** 本机探测到的摄像头数量（0 = 无可用硬件；由 probe() 无条件探测得到） */
  @State camCount: number = 0
  /** 相机系统权限是否已授予 */
  @State camGranted: boolean = false
  @State cameraError: string = ''
  private camController: XComponentController = new XComponentController()
  @State showEndConfirm: boolean = false
  @State ending: boolean = false
  /** 当前干预（来自 InterventionEngine，经 FocusController 回调送达） */
  @State interventionMsg: string = ''
  @State interventionLevel: string = ''
  @State interventionChannel: string = ''
  private interventionEvent: InterventionEvent | null = null
  /** 首次进入由 XComponent.onAppear 拉起预览；返回本页时（pushUrl 不重建页面）才需要自己拉回 */
  private firstShow: boolean = true

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
    // 干预链路接上 UI：引擎决策 → 卡片（原先 setOnIntervention 无人调用，链路是死的）
    controller.setOnIntervention((d: CompanionDecision, e: InterventionEvent) => {
      this.interventionEvent = e
      this.interventionMsg = d.message
      this.interventionLevel = d.level
      this.interventionChannel = d.channel
    })
    this.camGranted = PermissionService.getInstance().isCameraOn()
    // 无条件探测本机摄像头：不能由"本地授权标记"决定要不要探测，否则永远测不出有没有硬件
    const probeCtx = getContext(this) as common.UIAbilityContext
    this.camCount = CameraService.getInstance().probe(probeCtx)
    this.cameraError = CameraService.getInstance().getLastError()
    this.refreshTask()
  }

  aboutToDisappear(): void {
    FocusController.getInstance().setOnIntervention(null)
    // 相机会话是独占资源，离开页面必须释放
    CameraService.getInstance().stopPreview()
  }

  /** 从休息 / 答疑返回：pushUrl 不触发 aboutToDisappear，也不重建页面，预览要自己拉回来 */
  onPageShow(): void {
    if (this.firstShow) {
      this.firstShow = false
      return
    }
    if (this.perceptionMode === 'PERCEPTION_FULL' && this.camCount > 0 && this.camGranted) {
      this.tryStartCamera()
    }
  }

  /** 拉起前置预览：先确保权限，再启动；失败则把错误码留在界面上便于排查 */
  private async tryStartCamera(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    if (!this.camGranted) {
      this.camGranted = await PermissionService.getInstance().ensureCamera(ctx)
    }
    if (!this.camGranted) {
      this.cameraError = '未授予相机权限'
      return
    }
    const surfaceId = this.camController.getXComponentSurfaceId()
    const ok = await CameraService.getInstance().startPreview(ctx, surfaceId)
    this.cameraError = ok ? '' : CameraService.getInstance().getLastError()
  }

  /** 回到专注态即清掉未处理的干预提示，避免卡片常驻 */
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

  /** 顶部感知状态文案：如实反映"有没有硬件 / 有没有开感知" */
  private perceptionLabel(): string {
    if (this.perceptionMode === 'PERCEPTION_TIMER_ONLY') {
      return '本次未开启感知'
    }
    return this.camCount > 0 ? '摄像头感知中' : '无可用摄像头'
  }

  /** 模拟模式是否开启（默认开：当前无硬件） */
  private simOn(): boolean {
    const raw: number | undefined = AppStorage.get<number>(StorageKey.SIM_MODE)
    return raw === undefined ? true : raw === 1
  }

  /** 感知依据：让"为什么现在变黄/红了"可解释 */
  private basisText(): string {
    const c = FocusController.getInstance()
    const d = c.getLastDetail()
    if (d.length === 0) {
      return this.perceptionMode === 'PERCEPTION_TIMER_ONLY' ? '未开启感知（仅计时）' : '等待感知数据…'
    }
    return `${d} · 置信度 ${c.getLastConfidence()}%`
  }

  onBackPress(): boolean {
    if (this.showEndConfirm) {
      this.showEndConfirm = false
      return true
    }
    if (!FocusController.getInstance().isRunning()) {
      return false
    }
    // 手势/返回键离开专注页 = 结束本次专注（不再让会话在后台继续计时）。
    // 用二次确认避免误触丢进度；确认后走既有 endFlow(false)（内部已落库、已防重入）。
    AlertDialog.show({
      title: '结束本次专注？',
      message: '返回将结束本次专注并保存记录，未完成的任务会留在今日计划里。',
      primaryButton: {
        value: '结束并保存',
        action: () => {
          this.endFlow(false)
        }
      },
      secondaryButton: {
        value: '继续专注',
        action: () => {
          // 什么都不做：留在专注页继续
        }
      }
    })
    return true
  }

  private refreshTask(): void {
    const c = FocusController.getInstance()
    this.tasks = c.getTasks().slice()
    this.hasPlan = c.getTaskCount() > 0
    this.planTotal = c.getTaskCount()
    this.planDone = c.getCompletedCount()
    this.currentTaskId = c.getCurrentTaskId()
  }

  /** 勾选 / 撤销某个任务（撤销是误勾的出口） */
  private toggleTask(id: string, done: boolean): void {
    if (!FocusController.getInstance().setTaskDone(id, done)) {
      return
    }
    this.afterPlanChanged()
  }

  /** 点任务行 = 把当前任务切到它（用于任务级归因） */
  private switchTask(id: string): void {
    FocusController.getInstance().switchToTask(id)
    this.refreshTask()
  }

  private afterPlanChanged(): void {
    AppStore.getInstance().setCurrentPlan(FocusController.getInstance().getTasks())
    AppStore.getInstance().syncPlan()
    this.refreshTask()
  }

  private togglePause(): void {
    const c = FocusController.getInstance()
    this.clearIntervention()
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
    this.clearIntervention()
    c.startBreak()
    // pushUrl 不会触发 aboutToDisappear，不主动释放的话预览会一直在后台跑（相机是独占资源）
    CameraService.getInstance().stopPreview()
    router.pushUrl({ url: 'pages/FocusBreak' })
  }

  private openQA(): void {
    const c = FocusController.getInstance()
    if (!c.isRunning() || c.isPaused() || c.isResting() || c.isQaMode()) {
      return
    }
    this.clearIntervention()
    c.startQA()
    CameraService.getInstance().stopPreview()
    router.pushUrl({ url: 'pages/AIChat' })
  }

  private async endFlow(showReport: boolean): Promise<void> {
    if (this.ending) {
      return
    }
    this.ending = true
    this.clearIntervention()
    // try/finally：结束流程里任何一步抛异常都不能把「结束」按钮永久锁死，
    // 也不能让统计同步被跳过（退出专注后今日数据必须更新）
    try {
      await AppStore.getInstance().endSession()
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Focus', '结束会话出错，仍继续同步统计：%{public}s', e.message)
      await AppStore.getInstance().syncAfterSession()
    } finally {
      this.ending = false
    }
    if (showReport) {
      router.replaceUrl({ url: 'pages/StudyReport' })
    } else {
      router.back()
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        // 顶部合规栏：感知状态指示灯 + AI 智能体标签
        Row() {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(this.perceptionMode === 'PERCEPTION_TIMER_ONLY' || this.camCount === 0
                ? Colors.TEXT_TERTIARY : Colors.CAMERA_RED)
            Text(this.perceptionLabel())
              .fontSize(12)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ left: 6 })
          }
          Blank()
          AITag()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 4 })

        // 大字计时器固定在滚动区之上：它是本页的核心视觉，
        // 放进 Scroll 里一旦任务列表 / 干预卡变多就会被滚出屏幕（第三轮已提醒过，此处是回归）
        Column() {
          // 大字 = 学习时长（墙钟 − 休息 − 暂停），与复盘页「总学习时长」完全同口径
          FocusTimer({ seconds: this.studySec, big: true })
            .margin({ top: 12 })

          Text('本次学习（不含休息/暂停，与复盘一致）')
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 6 })
          Text(`本次已进行 ${TimeUtils.formatClock(this.elapsed)}（含休息/暂停）· 净专注 ${TimeUtils.formatHMin(this.net)}`)
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 4, bottom: 8 })

        // 主体：可滚动区（计时器已固定在滚动区之上，不会被滚走）
        Scroll() {
          Column() {
            // 感知画面：有摄像头就挂载预览（不再依赖"已授权"或手动展开，
            // 否则会出现"永远不去探测硬件"的死角）
            if (this.perceptionMode === 'PERCEPTION_FULL') {
              if (this.camCount > 0) {
                XComponent({
                  id: 'cameraPreview',
                  type: XComponentType.SURFACE,
                  controller: this.camController
                })
                  .width('100%')
                  .height(140)
                  .backgroundColor(Colors.CARD)
                  .borderRadius(Radius.MD)
                  .onAppear(() => {
                    this.tryStartCamera()
                  })
                Row() {
                  Text(`前置预览 · 信号触发时抓拍短片段 · 检测到 ${this.camCount} 个摄像头`)
                    .fontSize(11)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .layoutWeight(1)
                  if (this.cameraError.length > 0) {
                    Text('重试')
                      .fontSize(11)
                      .fontColor(Colors.PRIMARY_DARK)
                      .onClick(() => {
                        this.tryStartCamera()
                      })
                  }
                }
                .width('100%')
                .margin({ top: 4 })

                if (this.cameraError.length > 0) {
                  Text(this.cameraError)
                    .fontSize(11)
                    .fontColor(Colors.CAMERA_RED)
                    .width('100%')
                    .margin({ top: 2 })
                }
              } else {
                // 本机确实没有可用摄像头（或探测失败）：如实说明，不假装"感知中"
                Column() {
                  Text('📷').fontSize(22)
                  Text('本机无可用摄像头')
                    .fontSize(13)
                    .fontColor(Colors.TEXT_SECONDARY)
                    .margin({ top: 4 })
                  Text(this.cameraError.length > 0 ? this.cameraError : '已探测摄像头：0 个')
                    .fontSize(11)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .margin({ top: 4 })
                  Text('专注状态由规则引擎判定，画面不做识别')
                    .fontSize(11)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .margin({ top: 2 })
                }
                .width('100%')
                .padding(12)
                .backgroundColor(Colors.CARD)
                .borderRadius(Radius.MD)
              }
            } else {
              // 仅计时模式：区分"有硬件但没开感知"与"根本没硬件"
              Text(this.camCount > 0
                ? `检测到 ${this.camCount} 个摄像头，本次未开启感知（仅计时）`
                : '本次未开启感知（仅计时）')
                .fontSize(11)
                .fontColor(Colors.TEXT_TERTIARY)
                .width('100%')
            }

            // 佩戴手表时展示实时生理信号（未佩戴则完全不显示，不编造）
            if (SensorService.getInstance().isWristPresent()) {
              Row() {
                Text('❤️').fontSize(12)
                Text(`心率 ${SensorService.getInstance().getHeartRate()} bpm · ${SensorService.getInstance().isSimulatedWrist() ? '模拟手表' : '真实设备'}`)
                  .fontSize(12)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ left: 6 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 8 })
            }

            BreathingLight({
              state: this.focusState,
              onTap: () => {
                FocusController.getInstance().demoCycleState()
              }
            })
              .margin({ top: 20 })

            Text(FocusStateUi.label(this.focusState))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .margin({ top: 12 })
            Text(`${FocusStateUi.subLabel(this.focusState)} · ${this.basisText()}`)
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 6 })

            // 干预卡片（唯一的"分心提示"出口：LIGHT 提醒 / HEAVY 主动询问）
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

                if (!SensorService.getInstance().isWristPresent()) {
                  Text('（手机提醒，未连接手表，不会震动）')
                    .fontSize(11)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .margin({ top: 6 })
                    .width('100%')
                }

                Row({ space: 10 }) {
                  Button('继续专注')
                    .fontSize(13)
                    .fontColor(Color.White)
                    .backgroundColor(Colors.PRIMARY)
                    .height(38)
                    .borderRadius(19)
                    .onClick(() => {
                      this.feedback(FeedbackAction.CONTINUE, true)
                      FocusController.getInstance().resumeByUser()
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
              .width('100%')
              .padding(14)
              .backgroundColor(this.interventionLevel === 'HEAVY' ? Colors.RED_SOFT : Colors.YELLOW_SOFT)
              .borderRadius(Radius.LG)
              .margin({ top: 16 })
            }

            // 任务列表：勾选即完成，再点一次即撤销；点行进"当前任务"（归因用）
            if (this.hasPlan) {
              Column({ space: Spacing.SM }) {
                Row() {
                  Text('今日任务')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Blank()
                  Text(`${this.planDone}/${this.planTotal}`)
                    .fontSize(13)
                    .fontColor(Colors.TEXT_SECONDARY)
                }
                .width('100%')

                ForEach(this.tasks, (t: Task) => {
                  Column() {
                    TaskCard({
                      title: t.title,
                      subject: t.subject,
                      minutes: t.estimatedDuration,
                      done: t.done,
                      showCheckbox: true,
                      onToggle: () => {
                        this.toggleTask(t.id, !t.done)
                      }
                    })
                  }
                  .width('100%')
                  .border({
                    width: this.currentTaskId === t.id ? 1.5 : 0,
                    color: Colors.PRIMARY
                  })
                  .borderRadius(Radius.MD)
                  .onClick(() => {
                    this.switchTask(t.id)
                  })
                }, (t: Task) => `${t.id}_${t.done}_${this.currentTaskId === t.id}`)

                Text('勾选即完成，再点一次可撤销；点任务行把它设为当前任务')
                  .fontSize(11)
                  .fontColor(Colors.TEXT_TERTIARY)
                  .width('100%')
              }
              .width('100%')
              .margin({ top: 16 })
            }

            // 模拟工作台（唯一实现，与「工作台 → 模拟状态」共用同一组件）。
            // 放在专注页是因为：跳去别的 Tab 就看不到触发结果了。
            if (this.simOn()) {
              Column() {
                SimWorkbench()
              }
              .width('100%')
              .margin({ top: 16 })
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
                    this.togglePause()
                  })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Colors.CARD)
              .borderRadius(Radius.LG)
              .margin({ top: 16 })
            }
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 6, bottom: 12 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        // 底部控制：暂停 / 休息 / 答疑 / 结束（AI 不再用悬浮球压内容）
        Row({ space: 10 }) {
          Button(this.focusState === 'PAUSED' ? '继续' : '暂停')
            .layoutWeight(1)
            .height(46)
            .fontSize(14)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.togglePause()
            })
          Button('休息')
            .layoutWeight(1)
            .height(46)
            .fontSize(14)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
            .enabled(this.focusState !== 'RESTING' && this.focusState !== 'QA_MODE')
            .onClick(() => {
              this.rest()
            })
          Button('答疑')
            .layoutWeight(1)
            .height(46)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor(Colors.QA_ACCENT)
            .borderRadius(Radius.MD)
            .enabled(this.focusState !== 'PAUSED' && this.focusState !== 'RESTING')
            .opacity(this.focusState === 'PAUSED' || this.focusState === 'RESTING' ? 0.4 : 1)
            .onClick(() => {
              this.openQA()
            })
          Button('结束')
            .layoutWeight(1)
            .height(46)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY_DARK)
            .borderRadius(Radius.MD)
            .onClick(() => {
              this.showEndConfirm = true
            })
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 20, top: 6 })
      }
      .width('100%')
      .height('100%')

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
