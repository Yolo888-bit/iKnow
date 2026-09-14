import { router, promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { NavParams } from '../models/NavParams'
import { AppStore } from '../store/AppStore'
import { AIPersonality } from '../models/Enums'
import { UserAvatar } from '../components/UserAvatar'
import { AvatarPicker } from '../components/AvatarPicker'

/** AI 考伴类型（取自需求文档「页面 13：AI 考伴人格设置」的 3 种类型） */
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
  private types: CompanionType[] = [
    { key: AIPersonality.STRICT, emoji: '🎯', label: '严格教练型', desc: '直接 · 高执行力 · 适合拖延严重' },
    { key: AIPersonality.GENTLE, emoji: '🌤️', label: '温和陪伴型', desc: '鼓励 · 温和 · 低压力' },
    { key: AIPersonality.QUIET, emoji: '🌙', label: '极简安静型', desc: '尽量不主动说话 · 轻量提示' }
  ]
  aboutToAppear(): void {
    this.personality = AppStore.getInstance().getUser().aiPersonality
  }

  private selectPersona(key: AIPersonality): void {
    this.personality = key
    AppStore.getInstance().saveUserPersonality(key)
    promptAction.showToast({ message: '已切换考伴类型' })
  }

  /** 重新设置称呼 / 目标考试与日期（本地体验模式，无账号可退出） */
  private editProfile(): void {
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
          .fontColor(Colors.PRIMARY)
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
              .backgroundColor(Colors.PRIMARY)
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
          .margin({ left: 16 })
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.LG)

        // AI 考伴：3 种类型
        Column() {
          Text('AI 考伴')
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

        // 菜单
        Column({ space: Spacing.SM }) {
          this.menuItem('💬', '和考伴聊聊', '长期陪伴 · 智能答疑', 'pages/AICompanion', '')
          this.menuItem('⌚', '设备', '摄像头 · 智能手表', 'pages/Device', '')
          this.menuItem('🔔', '通知', '专注提醒与消息', 'pages/Placeholder', '通知')
          this.menuItem('🔒', '隐私', '授权与数据权限', 'pages/Privacy', '')
          this.menuItem('🗂️', '数据管理', '导出 · 清除学习数据', 'pages/Privacy', '')
          this.menuItem('ℹ️', '关于', '版本与开发者信息', 'pages/Placeholder', '关于')
        }
        .width('100%')

        // 重新设置称呼与目标（本地体验模式，无账号体系）
        Button('重新设置称呼与目标')
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontColor(Colors.TEXT_SECONDARY)
          .backgroundColor(Colors.CARD)
          .borderRadius(Radius.MD)
          .onClick(() => {
            this.editProfile()
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
    }
    .width('100%')
    .height('100%')
  }
}
