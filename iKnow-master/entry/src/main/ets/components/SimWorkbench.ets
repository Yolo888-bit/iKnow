import { promptAction } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
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
 *  - ② 合成信号：改的是信号本身，判定仍走真实的基线 / SQI / 触发 / 节流。
 *    因此它的结论依赖信号强度，**不保证每次都有结论**（例如"看手机"的运动
 *    特征不足以触发 MOTION_HIGH），这一点在界面上如实说明。
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

  /** 注入目标状态；没有进行中的会话时给出明确原因，不静默失败 */
  private pickState(activity: string): void {
    if (!FocusController.getInstance().simulateObservation(activity)) {
      promptAction.showToast({ message: '模拟状态只在专注中生效：未开始专注，或处于答疑 / 休息 / 暂停' })
      return
    }
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
    this.rev += 1
  }

  private pickHrv(low: boolean): void {
    WatchSignalSource.getInstance().setLowHrv(low)
    this.rev += 1
  }

  private pickSpo2(v: number): void {
    WatchSignalSource.getInstance().setSpo2(v)
    this.rev += 1
  }

  private pickMotion(mode: string): void {
    WatchSignalSource.getInstance().setMotion(mode)
    this.rev += 1
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
        // ① 目标状态：与云端可识别状态一一对应
        this.labelRow('目标状态（云端可识别的 7 种，直接注入）')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(SimActivity.ALL, (a: string) => {
            this.chip(a, () => {
              this.pickState(a)
            })
          }, (a: string) => a)
        }
        .width('100%')
        Text(this.stateLine())
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')
        this.note('注入的是"云端识别结果"，之后的规则组合、干预预算、状态机都是真实链路，因此点了立刻生效。' +
          '本机无摄像头，无法产生真实识别。')

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

        Button('一键模拟分心（看手机）')
          .width('100%')
          .height(38)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(Colors.YELLOW)
          .borderRadius(Radius.MD)
          .margin({ top: 8 })
          .onClick(() => {
            // 走状态注入：立刻生效。信号级注入见上方各按钮。
            this.pickState('看手机')
          })

        this.note('上面这组改的是信号本身，判定仍走真实的基线 / SQI / 触发 / 节流，' +
          `结论依赖信号强度，不保证每次都有结论（可点上方状态直接看结果）。${SensorService.getInstance().isWristPresent() ? '当前已佩戴模拟手表，红级干预会尝试手表震动。' : '当前未佩戴手表，红级干预走手机声音与屏幕，不会假装震动。'}`)
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)
  }
}
