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
    // 与「练习内容总结」卡片**同源**：都用 mergedTasks()（今日计划 ∪ 任务表）。
    // 用 getTasks() 会漏掉只存在于当前计划里的任务，于是卡片写「数学 3 次」、这里只列出 1 项。
    this.items = Metrics.practiceDetail(
      AppStore.getInstance().getSessions(),
      AppStore.getInstance().mergedTasks()
    )
  }

  /**
   * 学科分组，**按该科已完成任务数降序**（与「练习内容总结」卡片同序）；
   * 同数时按名称排序，保证每次进来顺序稳定、不会跳。
   */
  private subjects(): string[] {
    const names: string[] = []
    const counts: number[] = []
    for (const it of this.items) {
      const idx = names.indexOf(it.subject)
      if (idx < 0) {
        names.push(it.subject)
        counts.push(1)
      } else {
        counts[idx] = counts[idx] + 1
      }
    }
    const order: number[] = []
    for (let i = 0; i < names.length; i++) {
      order.push(i)
    }
    order.sort((a: number, b: number): number => {
      if (counts[b] !== counts[a]) {
        return counts[b] - counts[a]
      }
      if (names[a] === names[b]) {
        return 0
      }
      return names[a] < names[b] ? -1 : 1
    })
    const out: string[] = []
    for (const i of order) {
      out.push(names[i])
    }
    return out
  }

  /**
   * 右侧元信息：最近完成时间 + 完成次数。
   * 只有勾选、没有会话时间（`lastDoneMs = 0`）时**只写次数**，不编造日期。
   */
  private metaOf(it: PracticeDetailItem): string {
    const parts: string[] = []
    if (it.lastDoneMs > 0) {
      parts.push(this.dateLabel(it.lastDoneMs))
    }
    if (it.times > 1) {
      parts.push(`${it.times} 次`)
    }
    return parts.length > 0 ? parts.join(' · ') : '已完成'
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
          Text(this.metaOf(it))
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
        Text(`共 ${this.items.length} 项已完成任务 · 按科目归组，科目与组内任务都按完成次数由多到少`)
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
