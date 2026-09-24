import { router, promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { NavParams } from '../models/NavParams'
import { AppStore } from '../store/AppStore'
import { StorageService } from '../services/StorageService'
import { AuthService } from '../services/AuthService'
import { AIPersonality } from '../models/Enums'
import { UserAvatar } from '../components/UserAvatar'
import { AvatarPicker } from '../components/AvatarPicker'

/** 考伴类型（取自需求文档「页面 13：考伴人格设置」的 3 种类型） */
interface CompanionType {
  key: AIPersonality
  emoji: string
  label: string
  desc: string
}

/** 我的 */
@Component
export struct Mine {
  @StorageProp(StorageKey.USER_NICKNAME) nickname: string = ''
  @StorageProp(StorageKey.USER_AVATAR) avatar: string = '🧑‍🎓'
  @State personality: AIPersonality = AIPersonality.GENTLE
  @State showAvatarSheet: boolean = false
  /** 改称呼的覆盖层 */
  @State showRename: boolean = false
  @State renameValue: string = ''
  /** 模拟模式（默认开：当前无真机/真表，靠合成信号驱动演示） */
  @State simMode: boolean = true
  private types: CompanionType[] = [
    { key: AIPersonality.STRICT, emoji: '🎯', label: '严格教练型', desc: '直接 · 高执行力 · 适合拖延严重' },
    { key: AIPersonality.GENTLE, emoji: '🌤️', label: '温和陪伴型', desc: '鼓励 · 温和 · 低压力' },
    { key: AIPersonality.QUIET, emoji: '🌙', label: '极简安静型', desc: '尽量不主动说话 · 轻量提示' }
  ]
  aboutToAppear(): void {
    this.personality = AppStore.getInstance().getUser().aiPersonality
    StorageService.getInstance().loadKv(StorageKey.SIM_MODE).then((v: string) => {
      this.simMode = v !== '0'
      AppStorage.setOrCreate<number>(StorageKey.SIM_MODE, this.simMode ? 1 : 0)
    }).catch(() => {
      // 读不到按默认（开）处理
    })
  }

  private setSimMode(on: boolean): void {
    this.simMode = on
    AppStorage.setOrCreate<number>(StorageKey.SIM_MODE, on ? 1 : 0)
    StorageService.getInstance().saveKv(StorageKey.SIM_MODE, on ? '1' : '0').catch(() => {})
    promptAction.showToast({
      message: on ? '模拟模式已开启' : '模拟模式已关闭，连接手表后使用真实数据'
    })
  }

  private selectPersona(key: AIPersonality): void {
    this.personality = key
    AppStore.getInstance().saveUserPersonality(key)
    promptAction.showToast({ message: '已切换考伴类型' })
  }

  /** 打开改称呼的覆盖层 */
  private openRename(): void {
    this.renameValue = this.nickname
    this.showRename = true
  }

  private async saveNickname(): Promise<void> {
    const name = this.renameValue.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: '称呼不能为空' })
      return
    }
    await AppStore.getInstance().saveUserNickname(name)
    this.showRename = false
    promptAction.showToast({ message: '称呼已更新' })
  }

  /** 退出登录：确认后回到登录页（本机学习数据保留，重新登录即可继续） */
  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '退出后本机已保存的学习数据仍会保留，重新登录就能继续。',
      primaryButton: {
        value: '退出',
        fontColor: Colors.RED,
        action: () => {
          this.doLogout()
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    })
  }

  private async doLogout(): Promise<void> {
    await AuthService.getInstance().logout()
    router.replaceUrl({ url: 'pages/Login' })
  }

  @Builder
  menuItem(icon: string, title: string, subtitle: string, url: string, paramTitle: string) {
    Row() {
      Text(icon).fontSize(22)
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor(Colors.TEXT_TERTIARY)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.MD)
    .onClick(() => {
      if (paramTitle.length > 0) {
        router.pushUrl({ url: url, params: new NavParams(paramTitle) })
      } else {
        router.pushUrl({ url: url })
      }
    })
  }

  @Builder
  companionTypeCard(t: CompanionType) {
    Row() {
      Text(t.emoji).fontSize(20)
      Column() {
        Text(t.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(t.desc)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      if (this.personality === t.key) {
        Text('✓')
          .fontSize(18)
          .fontColor(Colors.PRIMARY_DARK)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.personality === t.key ? Colors.PRIMARY_SOFT : Colors.BG)
    .borderRadius(Radius.MD)
    .onClick(() => {
      this.selectPersona(t.key)
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: Spacing.MD }) {
        // 用户信息
        Row() {
          Stack({ alignContent: Alignment.BottomEnd }) {
            UserAvatar({ avatar: this.avatar, diameter: 60, bg: Colors.CARD })
            // 可点击编辑的提示角标
            Text('✎')
              .fontSize(11)
              .fontColor(Color.White)
              .width(20)
              .height(20)
              .textAlign(TextAlign.Center)
              .backgroundColor(Colors.PRIMARY_STRONG)
              .borderRadius(10)
          }
          .onClick(() => {
            this.showAvatarSheet = true
          })
          Column() {
            Text(this.nickname.length > 0 ? this.nickname : '同学')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('专注感知智能考伴')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 16 })

          // 改称呼挪到这里（底部按钮让给「退出登录」）
          Text('修改称呼')
            .fontSize(13)
            .fontColor(Colors.PRIMARY_DARK)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(Colors.PRIMARY_SOFT)
            .borderRadius(12)
            .onClick(() => {
              this.openRename()
            })
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)

        // 考伴：3 种类型
        Column() {
          Text('考伴')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('选择考伴类型，会影响提醒语气、干预方式与专注节奏')
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
            .margin({ top: 6, bottom: 12 })

          Column({ space: Spacing.SM }) {
            ForEach(this.types, (t: CompanionType) => {
              this.companionTypeCard(t)
            }, (t: CompanionType) => t.label)
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)
        .alignItems(HorizontalAlign.Start)

        // 模拟模式（无硬件时靠它驱动演示；连接真表后自动走真实信号）
        Column() {
          Row() {
            Column() {
              Text('模拟模式')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.TEXT_PRIMARY)
              Text(this.simMode
                ? '无硬件时用于演示专注感知'
                : '已关闭，连接手表后使用真实数据')
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.simMode })
              .selectedColor(Colors.PRIMARY)
              .onChange((v: boolean) => {
                this.setSimMode(v)
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)

        // 菜单
        Column({ space: Spacing.SM }) {
          this.menuItem('🎯', '长期计划与目标', '考试倒计时 · 科目 · 长期计划', 'pages/LongTermPlan', '')
          this.menuItem('🗂️', '学习记录', '历史专注复盘', 'pages/StudyHistory', '')
          this.menuItem('⌚', '设备', '摄像头 · 蓝牙心率设备', 'pages/Device', '')
          this.menuItem('🔒', '隐私', '授权与数据权限', 'pages/Privacy', '')
          this.menuItem('🗂️', '数据管理', '清除学习数据与画面片段', 'pages/Privacy', '')
          this.menuItem('ℹ️', '关于', '版本 · 能力说明 · 隐私入口', 'pages/About', '')
        }
        .width('100%')

        // 底部主操作：退出登录（改称呼在右上角）
        Button('退出登录')
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontColor(Colors.RED)
          .backgroundColor(Colors.CARD)
          .borderRadius(Radius.MD)
          .onClick(() => {
            this.confirmLogout()
          })

        Blank().height(20)
        }
        .padding(20)
        .width('100%')
      }
      .backgroundColor(Colors.BG)
      .width('100%')
      .height('100%')

      // 头像选择器（自定义覆盖层，替代 bindSheet，Tab 子页面里更稳）
      AvatarPicker({
        show: this.showAvatarSheet,
        onClose: () => {
          this.showAvatarSheet = false
        }
      })

      // 改称呼（自定义覆盖层，与头像选择器同一套做法：Tab 子页面里比 bindSheet 稳）
      if (this.showRename) {
        Stack({ alignContent: Alignment.Center }) {
          // 遮罩：点空白处关闭。必须是面板的**兄弟节点**，
          // 否则点在面板上的事件会冒泡到遮罩，一点输入框就把弹层关了
          Column() {}
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.showRename = false
          })

          Column() {
            Text('修改称呼')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
            Text('App 里会用这个名字称呼你')
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .width('100%')
              .margin({ top: 6, bottom: 16 })

            TextInput({ placeholder: '输入称呼', text: this.renameValue })
              .fontSize(15)
              .height(48)
              .backgroundColor(Colors.BG)
              .borderRadius(Radius.MD)
              .maxLength(20)
              .onChange((v: string) => {
                this.renameValue = v
              })
              .onSubmit(() => {
                this.saveNickname()
              })

            Row({ space: 10 }) {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontColor(Colors.TEXT_SECONDARY)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  this.showRename = false
                })
              Button('保存')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(Colors.PRIMARY_STRONG)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  this.saveNickname()
                })
            }
            .width('100%')
            .margin({ top: 20 })
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
  }
}
