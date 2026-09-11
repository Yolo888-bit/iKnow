import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { NavParams } from '../models/NavParams'

/** 我的 */
@Component
export struct Mine {
  @StorageProp(StorageKey.USER_NICKNAME) nickname: string = '刘灿'
  @StorageProp(StorageKey.USER_AVATAR) avatar: string = '🧑‍🎓'

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

  build() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        // 用户信息
        Row() {
          Text(this.avatar)
            .fontSize(30)
            .width(60)
            .height(60)
            .textAlign(TextAlign.Center)
            .backgroundColor(Colors.CARD)
            .borderRadius(30)
          Column() {
            Text(this.nickname)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('专注感知智能学伴')
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

        // 菜单
        Column({ space: Spacing.SM }) {
          this.menuItem('💡', 'AI 学伴', '长期陪伴 · 智能答疑', 'pages/AICompanion', '')
          this.menuItem('⌚', '设备', '摄像头 · 智能手表', 'pages/Device', '')
          this.menuItem('🔔', '通知', '专注提醒与消息', 'pages/Placeholder', '通知')
          this.menuItem('🔒', '隐私', '授权与数据权限', 'pages/Privacy', '')
          this.menuItem('🗂️', '数据管理', '导出 · 清除学习数据', 'pages/Privacy', '')
          this.menuItem('ℹ️', '关于', '版本与开发者信息', 'pages/Placeholder', '关于')
        }
        .width('100%')

        Blank().height(20)
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }
}
