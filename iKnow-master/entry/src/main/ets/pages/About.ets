import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'

/**
 * 关于（版本 / 能力说明 / AI 身份 / 隐私入口）
 *
 * 原先指向 Placeholder 占位页（"该模块正在完善中"）。评审看的是完备度，一页如实说明比占位页强，
 * 但**不许编**：版本号与 AppScope/app.json5 的 versionName 一致，能力说明与实现一致，
 * 没有可核对来源的信息（作者、联系方式）宁可不写。
 */
@Entry
@Component
export struct About {
  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        Text('关于')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

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
          Text('✓ 计时在本机完成：学习时长 = 墙钟 − 休息 − 暂停，与复盘页同一个口径\n' +
            '✓ 感知信号触发时才抓拍 2~3 秒短片段，不会持续录像\n' +
            '✓ 片段上传云端只做「在做什么」的可观察状态识别（做题 / 看书 / 看手机…），不做注意力推断\n' +
            '✓ 要不要干预由本机规则组合决定，判定依据与置信度都会显示出来\n' +
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
          Text('我是 AI 智能体，不是真人。我会陪你专注、答疑、复盘，但不能替代老师、医生或心理咨询师。所有内容仅供参考。')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(22)
            .margin({ top: 10 })
            .width('100%')
          Text('回答会如实标注来源：走大模型时标「大模型回答」，未配置或回退本地时标「本地模板回答」。')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .lineHeight(20)
            .margin({ top: 5 })
            .width('100%')
        }
        .aboutCard()

        Column() {
          Text('隐私与数据')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('画面片段与生理记录的上传范围、保存位置与清除方式，都在隐私页如实说明。')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(22)
            .margin({ top: 10 })
            .width('100%')
          Button('查看隐私与数据')
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.BG)
            .borderRadius(Radius.MD)
            .margin({ top: 14 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/Privacy' })
            })
        }
        .aboutCard()

        Blank().height(20)
      }
      .padding(20)
      .width('100%')
    }
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
