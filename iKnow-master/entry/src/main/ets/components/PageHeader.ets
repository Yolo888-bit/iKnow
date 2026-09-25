import { router } from '@kit.ArkUI'
import { Colors, Spacing } from '../common/Theme'

/**
 * 二级页面统一顶栏：左「← 返回」+ 居中页面名称。
 *
 * 为什么要有这个组件：「我的」里点进「长期计划 / 学习记录 / 设备 / 隐私 / 关于」
 * 都是新开的页面，之前只画了页面标题、没有返回入口，只能靠系统返回手势，
 * 用户反馈"点进去出不来"。这里统一补上返回箭头，并让页面名称固定在顶部正中。
 *
 * 布局要点：左右两侧放**等宽**占位（slotW），中间的标题才会落在屏幕正中央 ——
 * 若左侧按钮按内容宽度排布，标题会被按钮宽度顶偏。
 * 用法：`Column() { PageHeader({ title: '学习记录' })  Scroll() { ... } }`
 */
@Component
export struct PageHeader {
  /** 页面名称，显示在顶部正中央（单行，过长省略） */
  @Prop title: string = ''
  /** 返回行为；不传则退到上一页 */
  onBack: () => void = () => {
    router.back()
  }
  /** 左右两侧占位宽度，必须相等才能保证标题真正居中 */
  private slotW: number = 74

  build() {
    Row() {
      // 左：返回箭头（带上「返回」二字，比只有一个箭头更容易懂）
      Row() {
        Text('←')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Text('返回')
          .fontSize(14)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ left: 5 })
      }
      .width(this.slotW)
      .height(40)
      .justifyContent(FlexAlign.Start)
      .onClick(() => {
        this.onBack()
      })

      // 中：页面名称（正中央，单行）
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .layoutWeight(1)

      // 右：等宽占位（不放内容，只为把标题顶到正中）
      Row() {
      }
      .width(this.slotW)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: Spacing.SM, right: Spacing.SM, top: 12, bottom: 6 })
  }
}
