import { promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { StorageService } from '../services/StorageService'
import { PermissionService } from '../services/PermissionService'

/**
 * 隐私与数据（合规：如实说明数据流向 + 数据管理）
 *
 * 原「允许麦克风 / 允许健康数据」两个开关已删除：它们既不落盘、也不被任何 Service 读取、
 * 系统权限里也没有对应声明，属于假开关。宁可不给开关，也不给一个点了没用处的。
 *
 * ⚠️ 本页文案必须与实现一致：本项目会**上传画面片段到云端识别**并**在本机保存**，
 * 因此原先"不联网、不保存"的说法已删除，改为如实描述。
 * 授权点只有一个：首页「开始专注」时的感知确认（确认即为授权，默认同意；
 * 选择「仅计时」则完全不抓拍、不上传）。这里不设独立的采集/上传开关，只说明链路与撤回方式。
 */
@Entry
@Component
export struct Privacy {
  @State showClearConfirm: boolean = false
  @State vibrateOn: boolean = true
  @State voiceOn: boolean = true
  /** 麦克风（语音输入）的系统授权状态：只读展示，不再做成"假开关" */
  @State micOn: boolean = false

  aboutToAppear(): void {
    StorageService.getInstance().loadKv(StorageKey.VIBRATE_ON).then((v: string) => {
      this.vibrateOn = v !== '0'
      AppStorage.setOrCreate<number>(StorageKey.VIBRATE_ON, this.vibrateOn ? 1 : 0)
    }).catch(() => {})
    StorageService.getInstance().loadKv(StorageKey.VOICE_ON).then((v: string) => {
      // 缺省为开：语音提醒改成本机音频文件后不再依赖系统语音能力，默认开着才有意义
      this.voiceOn = v !== '0'
      AppStorage.setOrCreate<number>(StorageKey.VOICE_ON, this.voiceOn ? 1 : 0)
    }).catch(() => {})
    this.micOn = PermissionService.getInstance().isMicrophoneOn()
  }

  private clearImages(): void {
    AppStore.getInstance().clearImages().then(() => {
      promptAction.showToast({ message: '已清除本机保存的画面片段' })
    }).catch(() => {
      promptAction.showToast({ message: '清除失败，请重试' })
    })
  }

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

            Text('✓ 仅在感知信号触发时抓拍 2~3 秒的短片段，不会持续录像\n✓ 片段会上传到云端做「在做什么」识别，并保存在本机供你复盘\n✓ 云端只输出可观察状态（做题/看书/看手机…），不做注意力推断\n✓ 授权方式：开始专注时确认「开启感知」即为授权；选择「仅计时开始」则完全不抓拍、不上传\n✓ 本机保存的画面可随时用下方「清除已保存的画面片段」一键清除')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .lineHeight(22)
              .width('100%')
              .margin({ top: 10 })

          }
          .privacyCard()

          // 分心提醒方式
          Column() {
            Text('分心提醒')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 8 })

            this.authRow('识别到分心时震动', this.vibrateOn, (v: boolean) => {
              this.vibrateOn = v
              AppStorage.setOrCreate<number>(StorageKey.VIBRATE_ON, v ? 1 : 0)
              StorageService.getInstance().saveKv(StorageKey.VIBRATE_ON, v ? '1' : '0').catch(() => {})
            })
            this.authRow('识别到分心时语音提醒', this.voiceOn, (v: boolean) => {
              this.voiceOn = v
              AppStorage.setOrCreate<number>(StorageKey.VOICE_ON, v ? 1 : 0)
              StorageService.getInstance().saveKv(StorageKey.VOICE_ON, v ? '1' : '0').catch(() => {})
            })
            Text(`语音提醒由系统语音合成朗读（按离线模式请求），合成不可用时改用 App 内置的提醒音频\n`
              + `✓ 只在确认分心时响：识别到「看手机」或画面里没有人\n`
              + `✓ 「趴在桌上」这类轻度状态只出提示卡片，不出声\n`
              + `✓ 切到其他应用期间不响（回到 App 时才记一条卡片）\n`
              + `✓ 同一段专注内受冷却与提醒次数上限约束，不会反复响`)
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .lineHeight(16)
              .width('100%')
              .margin({ top: 8 })
          }
          .privacyCard()

          // 语音输入（麦克风）
          Column() {
            Text('麦克风')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')

            Text(`系统授权状态：${this.micOn ? '已授权' : '未授权'}\n`
              + '✓ 只在任务规划 / 专注答疑里按住说话时采集，其余时间不采集\n'
              + '✓ 语音交给系统语音识别服务按在线模式转成文字，音频本身不由本 App 保存\n'
              + '✓ 未授权时不影响使用，输入框照常可以打字')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .lineHeight(22)
              .width('100%')
              .margin({ top: 10 })
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

            Button('清除已保存的画面片段')
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontColor(Colors.TEXT_PRIMARY)
              .backgroundColor(Colors.CARD)
              .borderRadius(Radius.MD)
              .margin({ top: 10 })
              .onClick(() => {
                this.clearImages()
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
                  promptAction.showToast({ message: '已清除本机保存的生理记录（心率 / HRV）' })
                }).catch(() => {
                  promptAction.showToast({ message: '清除失败，请重试' })
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
