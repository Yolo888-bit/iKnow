import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { Metrics } from '../services/Metrics'
import { FocusSession } from '../models/FocusSession'
import { TimeUtils } from '../utils/TimeUtils'
import { PageHeader } from '../components/PageHeader'

/**
 * 学习记录 —— 历史每次专注的复盘入口。
 *
 * 之前单次复盘只依赖 `AppStore.currentReport`（内存态），重启或从别处进入就是空白；
 * 这里列出库里所有已结束的会话，点进去由 StudyReport 按 sessionId 从库加载。
 */
@Entry
@Component
export struct StudyHistory {
  @State sessions: FocusSession[] = []

  aboutToAppear(): void {
    const sorted: FocusSession[] = AppStore.getInstance().getSessions().slice()
    sorted.sort((a: FocusSession, b: FocusSession): number => b.startTime - a.startTime)
    this.sessions = sorted
  }

  private openReport(s: FocusSession): void {
    AppStorage.setOrCreate<string>(StorageKey.REPORT_SESSION_ID, s.id)
    router.pushUrl({ url: 'pages/StudyReport' })
  }

  private timeLabel(ts: number): string {
    const d = new Date(ts)
    const h = d.getHours()
    const m = d.getMinutes()
    const hh = h < 10 ? `0${h}` : `${h}`
    const mm = m < 10 ? `0${m}` : `${m}`
    return `${d.getMonth() + 1}月${d.getDate()}日 ${hh}:${mm}`
  }

  @Builder
  row(s: FocusSession) {
    Row() {
      Column() {
        Text(this.timeLabel(s.startTime))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(s.title.length > 0 ? s.title : '自由专注')
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text(TimeUtils.formatHMin(Metrics.totalStudySec(s)))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(s.taskIds.length > 0
          ? `净专注 ${Metrics.focusRatePercent(s)}% · 完成 ${Metrics.completionRate(s)}%`
          : `净专注 ${Metrics.focusRatePercent(s)}% · 自由专注`)
          .fontSize(11)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.CARD)
    .borderRadius(Radius.MD)
    .onClick(() => {
      this.openReport(s)
    })
  }

  build() {
    Scroll() {
      Column({ space: Spacing.SM }) {
        // 顶栏：返回箭头 + 居中页面名称（从「我的」点进来，之前没有返回入口）
        PageHeader({ title: '学习记录' })
        Text(`共 ${this.sessions.length} 次专注 · 点任意一条查看那次完整复盘`)
          .fontSize(13)
          .fontColor(Colors.TEXT_SECONDARY)
          .width('100%')
          .margin({ bottom: 6 })

        if (this.sessions.length === 0) {
          Text('还没有专注记录')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 40 })
        } else {
          ForEach(this.sessions, (s: FocusSession) => {
            this.row(s)
          }, (s: FocusSession) => s.id)
        }

        Blank().height(20)
      }
      // 显式左对齐：Column 默认是居中的，列表只有一两条时整块会飘到屏幕中间
      .alignItems(HorizontalAlign.Start)
      // top 收窄：顶栏的返回箭头要贴着页面顶部
      .padding({ left: 20, right: 20, top: 6, bottom: 20 })
      .width('100%')
    }
    // 内容不足一屏时也必须从顶部开始排 —— 之前没写 align，短列表会整体垂直居中
    .align(Alignment.Top)
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }
}
