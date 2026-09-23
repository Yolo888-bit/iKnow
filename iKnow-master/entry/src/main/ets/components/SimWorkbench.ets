import { promptAction } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { FocusTuning } from '../common/FocusTuning'
import { StorageKey } from '../common/Constants'
import { FocusController } from '../services/FocusController'
import { SensorService } from '../services/SensorService'
import { WatchSignalSource } from '../services/WatchSignalSource'
import { WatchEventEngine } from '../services/WatchEventEngine'
import { SimActivity } from '../services/WatchSignalSimulator'

/**
 * 模拟状态控制台（唯一实现，排在专注页里）
 *
 * ⚠️ 这里的一切都是**演示用输入**，不是真实测量/真实识别：
 *  - ① 目标状态：注入一条"云端识别结果"。云端识别结果的取值与
 *    `Prompts.activity()` 完全一致（7 个），映射见 `SimActivity`。
 *    这一层之后的规则组合 / 干预预算 / 状态机 / UI 都是**真实链路**。
 *  - ② 合成信号：正常档只改信号；异常档（紧张 / HRV 偏低 / 低血氧 / 大幅移动）
 *    会**直接注入一条对应的观察**让按钮反馈可见：心率 / HRV / 血氧异常 → 「趴桌」(轻提示·黄)，
 *    大幅移动 → 「离开」(分心·红)。无摄像头时注入的是演示值（无真实照片），但页面变色与复盘记录
 *    都真实发生（证据标注为模拟）。等价于真机"异常生理变化触发抓拍、云端识别可观察状态"的演示版。
 *
 * 为什么要拆成两层：无摄像头/无真表时，只靠合成信号去撞真实阈值，
 * 用户点了要等很久甚至永远没有反应；而"识别结果 → 规则 → 干预"这段本身是真实的，
 * 直接注入它既能立刻看到真实反应，也不需要伪造任何结论。
 */
@Component
export struct SimWorkbench {
  /** 仅用于点击后强制重绘（服务是单例，本身不响应式） */
  @State rev: number = 0

  /** 模拟模式是否开启（默认开：当前无硬件） */
  private simOn(): boolean {
    const raw: number | undefined = AppStorage.get<number>(StorageKey.SIM_MODE)
    return raw === undefined ? true : raw === 1
  }

  private running(): boolean {
    return FocusController.getInstance().isRunning()
  }

  /**
   * 目标状态入口：点一下 = 真机「拍照 → 云端识别」得到的可观察状态，这里直接注入该结果，
   * 之后走真实下游链路（规则组合 → 状态机 → 干预 → 复盘落库）。
   */
  private runFlow(activity: string): void {
    const c = FocusController.getInstance()
    // ① 目标状态 = 直接注入"云端识别结果"（与文件头注释一致）：这是设计上最可靠的演示路径，
    // 它**绕过相机/网关的可用性**，把可观察状态直接送进「规则组合 → 状态机 → 干预 → 复盘」，
    // 因此在纯预览 / 无摄像头下也能稳定让页面变色、复盘记录分心事件。
    if (!c.simulateObservation(activity, FocusTuning.SIM_INJECT_CONFIDENCE)) {
      promptAction.showToast({ message: '模拟流程只在专注中生效（未开始专注，或处于答疑 / 休息 / 暂停）' })
      return
    }
    promptAction.showToast({ message: `已注入：云端识别为「${activity}」，结论进入复盘（可去学习记录查看）` })
    this.rev += 1
  }

  /**
   * 异常生理值 → 注入一条"对应观察"，让按钮反馈可见且复盘可查。
   *
   * 产品本意：生理异常只是"为什么要拍一张照"的线索，最终结论由照片 / 云端判定；
   * 但无摄像头时根本没有照片，识别器只会回显"当前阶段"（默认专注），按钮就会"毫无反应"。
   * 所以这里**直接注入一条对应的可观察状态**（趴桌=轻提示·黄 / 离开=分心·红），
   * 等价于真机"异常生理变化触发抓拍、云端识别出可观察状态"的演示版——
   * 页面变色与复盘记录都真实发生（证据标注为模拟），按钮作用一眼可见。
   */
  private fireVital(reason: string, demoActivity: string): void {
    const c = FocusController.getInstance()
    if (!c.isRunning()) {
      promptAction.showToast({ message: '模拟流程只在专注中生效（请先开始专注）' })
      return
    }
    c.simulateObservation(demoActivity, FocusTuning.SIM_INJECT_CONFIDENCE)
    promptAction.showToast({ message: `已触发：生理异常已记录，并注入「${demoActivity}」（可在学习记录查看）` })
    this.rev += 1
  }

  /** 信号级注入：切换合成信号阶段并强制结算一次 */
  private pickSignalPhase(activity: string): void {
    if (!FocusController.getInstance().simulateWatchPhase(activity)) {
      promptAction.showToast({ message: '合成信号只在专注中生效：未开始专注，或处于答疑 / 休息 / 暂停' })
      return
    }
    this.rev += 1
  }

  private pickHeartRate(bpm: number, lowHrv: boolean): void {
    WatchSignalSource.getInstance().setHeartRate(bpm)
    WatchSignalSource.getInstance().setLowHrv(lowHrv)
    // 异常档（紧张 / HRV 偏低）→ 注入「趴桌」(轻提示·黄)，证明"生理异常→拍照事件"可见
    if (bpm >= 90 || lowHrv) {
      this.fireVital(`心率 ${bpm} bpm${lowHrv ? ' + HRV偏低' : ''}`, '趴桌')
    } else {
      this.rev += 1
    }
  }

  private pickHrv(low: boolean): void {
    WatchSignalSource.getInstance().setLowHrv(low)
    if (low) {
      this.fireVital('HRV偏低', '趴桌')
    } else {
      this.rev += 1
    }
  }

  private pickSpo2(v: number): void {
    WatchSignalSource.getInstance().setSpo2(v)
    // 低血氧（≤93%）→ 注入「趴桌」(轻提示·黄)
    if (v <= 93) {
      this.fireVital(`血氧 ${v}%`, '趴桌')
    } else {
      this.rev += 1
    }
  }

  private pickMotion(mode: string): void {
    WatchSignalSource.getInstance().setMotion(mode)
    // 大幅移动 → 注入「离开」(分心·红)；静止 / 写字不触发，仅改信号
    if (mode === 'MOVE') {
      this.fireVital('大幅移动', '离开')
    } else {
      this.rev += 1
    }
  }

  private baselineLine(): string {
    const e = WatchEventEngine.getInstance()
    if (!e.isRunning()) {
      return '未运行（开始专注后启动）'
    }
    return e.isBaselineDone()
      ? '已建成'
      : `建立中 ${e.getBaselineProgress()}/4 窗`
  }

  private stateLine(): string {
    const cur = FocusController.getInstance().getSimulatedActivity()
    return `当前信号阶段对应「${cur}」· ${SimActivity.effectOf(cur)}`
  }

  @Builder
  chip(label: string, onTap: () => void) {
    Button(label)
      .height(32)
      .fontSize(12)
      .fontColor(Colors.TEXT_PRIMARY)
      .backgroundColor(Colors.BG)
      .borderRadius(16)
      .margin({ right: 6, bottom: 6 })
      .onClick(onTap)
  }

  @Builder
  labelRow(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor(Colors.TEXT_TERTIARY)
      .width('100%')
      .margin({ top: 8, bottom: 4 })
  }

  @Builder
  note(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor(Colors.TEXT_TERTIARY)
      .lineHeight(16)
      .width('100%')
      .margin({ top: 6 })
  }

  build() {
    Column() {
      Row() {
        Text('模拟状态')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text('非真实测量')
          .fontSize(11)
          .fontColor(Colors.TEXT_TERTIARY)
      }
      .width('100%')

      if (!this.simOn()) {
        this.note('模拟模式已关闭。到「我的 → 模拟模式」开启后才能手动驱动状态；开启后连接真实手表则自动改用真实信号。')
      } else {
        // ① 目标状态：点一下就走**完整流程**（信号变化 → 触发 → 抓拍 → 云端 → 干预）
        this.labelRow('目标状态（云端可识别的 7 种 · 点一下走完整流程）')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(SimActivity.ALL, (a: string) => {
            this.chip(a, () => {
              this.runFlow(a)
            })
          }, (a: string) => a)
        }
        .width('100%')
        Text(this.stateLine())
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')
        this.note('点一下 = 真机「生理信号变化、到达拍照触发点」后云端识别出的可观察状态，' +
          '这里**直接注入这条云端识别结果**（与真机「拍照 → 云端识别」拿到的是同一个东西），' +
          '之后走**真实链路**：规则组合 → 状态机 → 干预 → 复盘落库。' +
          '因此无摄像头 / 纯预览下也能稳定让页面变色、复盘记录这次分心（evidence 标注为模拟）。' +
          '配置网关 + 真机时，这条按钮对应真实「拍照 → 云端识别」入口。')

        // ② 合成信号：跑真实的触发/基线链路
        Text(`合成信号 · HR ${WatchSignalSource.getInstance().currentBpm()} bpm · SpO2 ${WatchSignalSource.getInstance().currentSpo2()}% · 基线 ${this.baselineLine()} · 时基 ×30`)
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')
          .margin({ top: 14 })

        this.labelRow('心率')
        Row() {
          this.chip('静息 62', () => {
            this.pickHeartRate(62, false)
          })
          this.chip('专注 74', () => {
            this.pickHeartRate(74, false)
          })
          this.chip('紧张 92', () => {
            this.pickHeartRate(92, true)
          })
        }
        .width('100%')

        this.labelRow('HRV')
        Row() {
          this.chip('正常', () => {
            this.pickHrv(false)
          })
          this.chip('偏低', () => {
            this.pickHrv(true)
          })
        }
        .width('100%')

        this.labelRow('血氧')
        Row() {
          this.chip('98%', () => {
            this.pickSpo2(98)
          })
          this.chip('95%', () => {
            this.pickSpo2(95)
          })
          this.chip('92%', () => {
            this.pickSpo2(92)
          })
        }
        .width('100%')

        this.labelRow('动作')
        Row() {
          this.chip('静止', () => {
            this.pickMotion('STILL')
          })
          this.chip('写字', () => {
            this.pickMotion('WRITE')
          })
          this.chip('大幅移动', () => {
            this.pickMotion('MOVE')
          })
        }
        .width('100%')

        // 配额显示：被挡住时必须能看出来，否则"点了没反应"永远是黑盒
        Text(`本会话配额：触发 ${FocusController.getInstance().getTriggerQuotaUsed()}/${FocusTuning.MAX_TRIGGER_PER_SESSION}` +
          ` · 采集 ${FocusController.getInstance().getQueueQuotaUsed()}/${FocusTuning.MAX_QUEUE_PER_SESSION}`)
          .fontSize(11)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .margin({ top: 10 })
        // 抓拍诊断：把"为什么这次没有真实画面"直接摆到界面上（原因原本只在日志里，
        // 界面上看不出来 → 每次都要靠猜）。点一次「目标状态」后这里会给出确切结论。
        if (FocusController.getInstance().getLastCaptureDiag().length > 0) {
          Text(`上次抓拍：${FocusController.getInstance().getLastCaptureDiag()}`)
            .fontSize(11)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(16)
            .width('100%')
            .margin({ top: 4 })
        }
        if (FocusController.getInstance().getTriggerQuotaUsed() >= FocusTuning.MAX_TRIGGER_PER_SESSION
          || FocusController.getInstance().getQueueQuotaUsed() >= FocusTuning.MAX_QUEUE_PER_SESSION) {
          Text('配额已用完 —— 这时的点击不会再抓拍（这是产品约束：避免连续抓拍与打扰）。' +
            '可点下面重置，或结束本次专注重新开始。')
            .fontSize(11)
            .fontColor(Colors.CAMERA_RED)
            .lineHeight(16)
            .width('100%')
        }
        Button('重置本会话演示配额')
          .width('100%')
          .height(32)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .margin({ top: 6 })
          .onClick(() => {
            FocusController.getInstance().resetDemoQuota()
            promptAction.showToast({ message: '已重置本会话演示配额' })
            this.rev += 1
          })

        Button('一键模拟分心（看手机）')
          .width('100%')
          .height(38)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(Colors.YELLOW)
          .borderRadius(Radius.MD)
          .margin({ top: 8 })
          .onClick(() => {
            // 与上面的「看手机」同一个入口：一键走完整流程（抓拍 → 云端识别 → 落库带照片 → 干预）
            this.runFlow('看手机')
          })

        this.note('上面这组：**正常档（静息/专注/正常/98%/静止/写字）只改信号**；' +
          '**异常档（紧张/HRV偏低/低血氧/大幅移动）会立即注入一条对应观察**，可在「学习记录/复盘」里看到这次触发与结论' +
          '（无摄像头时为演示值，无真实照片）。' +
          '其中：心率 / HRV / 血氧异常 → 注入「趴桌」(轻提示·黄)；大幅移动 → 注入「离开」(分心·红)。' +
          `${SensorService.getInstance().isWristPresent() ? '当前已佩戴模拟手表，红级干预会尝试手表震动。' : '当前未佩戴手表，红级干预走手机声音与屏幕，不会假装震动。'}`)
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)
  }
}
