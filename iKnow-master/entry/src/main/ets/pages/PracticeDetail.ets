import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { Metrics, PracticeDetailItem } from '../services/Metrics'
import { PageHeader } from '../components/PageHeader'

/**
 * 练习内容明细 —— 长期视图里「练习内容总结」点开后看完整列表。
 *
 * 为什么单独一页：那一块是窄卡片，放不下全部内容；而且卡片里每科只显示
 * 一个代表标题，用户点开才能看到"这科到底做了哪些题"。
 */
@Entry
@Component
export struct PracticeDetail {
  @State items: PracticeDetailItem[] = []

  aboutToAppear(): void {
    this.items = Metrics.practiceDetail(
      AppStore.getInstance().getSessions(),
      AppStore.getInstance().getTasks()
    )
  }

  /** 按学科分组（保持 practiceDetail 的时间倒序） */
  private subjects(): string[] {
    const out: string[] = []
    for (const it of this.items) {
      if (out.indexOf(it.subject) < 0) {
        out.push(it.subject)
      }
    }
    return out
  }

  private itemsOf(subject: string): PracticeDetailItem[] {
    const out: PracticeDetailItem[] = []
    for (const it of this.items) {
      if (it.subject === subject) {
        out.push(it)
      }
    }
    return out
  }

  private dateLabel(ms: number): string {
    const d = new Date(ms)
    return `${d.getMonth() + 1}月${d.getDate()}日`
  }

  @Builder
  subjectBlock(subject: string) {
    Column({ space: Spacing.SM }) {
      Row() {
        Text(subject)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        Text(`${this.itemsOf(subject).length} 项`)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
      }
      .width('100%')

      ForEach(this.itemsOf(subject), (it: PracticeDetailItem) => {
        Row() {
          Text(it.title)
            .fontSize(14)
            .fontColor(Colors.TEXT_PRIMARY)
            .layoutWeight(1)
          Text(it.times > 1 ? `${this.dateLabel(it.lastDoneMs)} · ${it.times} 次` : this.dateLabel(it.lastDoneMs))
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .border({ width: { bottom: 0.5 }, color: Colors.LINE })
      }, (it: PracticeDetailItem) => `${it.subject}_${it.title}_${it.lastDoneMs}`)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.LG)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        // 顶栏：返回箭头 + 居中页面名称（从复盘页「练习内容总结」点进来，之前没有返回入口）
        PageHeader({ title: '练习内容明细' })
        Text(`共 ${this.items.length} 项已完成任务，按学科列出，右侧是最近完成时间`)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')

        if (this.items.length === 0) {
          Text('还没有完成过任务。完成的任务会出现在这里。')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
            .margin({ top: 30 })
        } else {
          ForEach(this.subjects(), (sub: string) => {
            this.subjectBlock(sub)
          }, (sub: string) => sub)
        }

        Blank().height(20)
      }
      // top 收窄：顶栏的返回箭头要贴着页面顶部
      .padding({ left: 20, right: 20, top: 6, bottom: 20 })
      .width('100%')
    }
    // 内容不足一屏时也必须从顶部开始排，不能垂直居中
    .align(Alignment.Top)
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }
}
