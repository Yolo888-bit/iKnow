import { promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { StorageService } from '../services/StorageService'
import { PageHeader } from '../components/PageHeader'

/**
 * 数据管理（从「我的 → 数据管理」点进来）
 *
 * 本页只保留两块：**分心提醒 / 数据管理**。
 * 《隐私保护说明》原文与「撤销隐私授权」在 `pages/PrivacyPolicy`
 * （「我的 → 隐私与数据」直接进那一页），本页不再重复入口。
 *
 * ⚠️ 本页文案必须与实现一致：本项目会**上传画面片段到云端识别**并**在本机保存**，
 * 因此"不联网、不保存"这类说法一律不写。
 * 原「允许麦克风 / 允许健康数据」两个开关已删除：它们不落盘、也不被任何 Service 读取、
 * 系统权限里也没有对应声明，属于假开关。宁可不给开关，也不给一个点了没用处的。
 * 语音输入（麦克风）能力已整体移除，故本页原「麦克风」模块也一并删除。
 */
@Entry
@Component
export struct Privacy {
  @State showClearConfirm: boolean = false
  @State vibrateOn: boolean = true
  @State voiceOn: boolean = true

  aboutToAppear(): void {
    StorageService.getInstance().loadKv(StorageKey.VIBRATE_ON).then((v: string) => {
      this.vibrateOn = v !== '0'
      AppStorage.setOrCreate<number>(StorageKey.VIBRATE_ON, this.vibrateOn ? 1 : 0)
    }).catch(() => {})
    StorageService.getInstance().loadKv(StorageKey.VOICE_ON).then((v: string) => {
      // 缺省为开：关着只会让人以为功能没接上
      this.voiceOn = v !== '0'
      AppStorage.setOrCreate<number>(StorageKey.VOICE_ON, this.voiceOn ? 1 : 0)
    }).catch(() => {})
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
          // 顶栏：返回箭头 + 居中页面名称（从「我的 → 数据管理」点进来）
          PageHeader({ title: '数据管理' })

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
            Text(`语音提醒播的是 App 内置的语音包，内容随考伴人格变化\n`
              + `✓ 分心持续到重度后开始响，并一直循环到你回到专注为止\n`
              + `✓ 回到专注 / 休息 / 暂停 / 答疑 / 结束本次，都会立刻停声\n`
              + `✓ 轻度分心只出提示卡片，不响\n`
              + `✓ 极简安静型不出声：界面只显示「⚠️轻度分心 / 🔴重度分心」徽标\n`
              + `✓ 切到其他应用期间不响（回到 App 时才记一条）`)
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .lineHeight(16)
              .width('100%')
              .margin({ top: 8 })

            // 试听按人格分（语音包就是按人格录的），所以放在「我的 → 考伴」那边，
            // 这一页只留开关，不把同一个功能拆成两处入口。
            Text('想听当前人格的提醒语音，去「我的 → 考伴」点「试听当前人格的提醒语音」。')
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .lineHeight(16)
              .width('100%')
              .margin({ top: 6 })
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
        // top 收窄：顶栏的返回箭头要贴着页面顶部
        .padding({ left: 20, right: 20, top: 6, bottom: 20 })
        .width('100%')
      }
      // 内容不足一屏时也必须从顶部开始排，不能垂直居中
      .align(Alignment.Top)
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
