import { Colors, Radius, Spacing } from '../common/Theme'
import { PageHeader } from '../components/PageHeader'

/**
 * 关于（版本 / 能力说明 / AI 身份 / 联系我们）
 *
 * 原先指向 Placeholder 占位页（"该模块正在完善中"）。评审看的是完备度，一页如实说明比占位页强，
 * 但**不许编**：版本号与 AppScope/app.json5 的 versionName 一致，能力说明与实现一致。
 * 「联系我们」写的是团队名与邮箱（uDefine / 3142488461@qq.com），由项目方给出，非杜撰。
 */
@Entry
@Component
export struct About {
  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        // 顶栏：返回箭头 + 居中页面名称（从「我的」点进来，之前没有返回入口）
        PageHeader({ title: '关于' })

        Column() {
          Text('iKnow · 专注感知智能考伴')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('v1.0.0 · HarmonyOS NEXT（API 12）')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 6 })
            .width('100%')
          Text('2026 中国高校计算机大赛 · 人工智能创意赛（鸿蒙赛道）参赛作品')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(20)
            .margin({ top: 6 })
            .width('100%')
        }
        .aboutCard()

        Column() {
          Text('它怎么工作')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('✓ 计时在本机完成，只统计净专注时长\n' +
            '✓ 感知信号触发时才抓拍几张画面，不会持续录像\n' +
            '✓ 学习记录、画像与画面片段都保存在本机，可随时清除')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(22)
            .margin({ top: 10 })
            .width('100%')
        }
        .aboutCard()

        Column() {
          Text('关于 AI')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('小伴是 AI 智能体，不是真人。陪你专注、答疑、复盘都可以，但不能替代老师、医生或心理咨询师。所有内容仅供参考。')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(22)
            .margin({ top: 10 })
            .width('100%')
          Text('回答会标注来源：大模型回答 / 本地模板回答。')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .lineHeight(20)
            .margin({ top: 5 })
            .width('100%')
        }
        .aboutCard()

        Column() {
          Text('联系我们')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('有任何建议或问题，欢迎联系开发团队 uDefine，我们会尽快回复。')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(22)
            .margin({ top: 10 })
            .width('100%')
          // 邮箱做成可长按复制的实心块，方便直接拷贝
          Text('3142488461@qq.com')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.PRIMARY_DARK)
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(Colors.PRIMARY_SOFT)
            .borderRadius(Radius.MD)
            .margin({ top: 12 })
            .copyOption(CopyOptions.LocalDevice)
        }
        .aboutCard()

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
    .backgroundColor(Colors.BG)
  }
}

@Extend(Column)
function aboutCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
