import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { AIService } from '../services/AIService'
import { FocusProfile as Profile } from '../models/FocusProfile'
import { RadarChart } from '../components/RadarChart'
import { BarChart } from '../components/BarChart'
import { AITag } from '../components/AITag'

/** 长期个人专注画像 */
@Entry
@Component
export struct FocusProfile {
  @State profile: Profile = new Profile()
  @State dimValues: number[] = []
  @State trend: number[] = []
  @State hardest: string = '数学类任务'
  private dimLabels: string[] = ['效率', '专注度', '稳定性', '执行力', '抗干扰']

  aboutToAppear(): void {
    this.refresh()
  }

  private refresh(): void {
    const p = AppStore.getInstance().getProfile()
    this.profile = p
    this.dimValues = [p.efficiency, p.concentration, p.stability, p.execution, p.antiDistraction]
    this.trend = p.monthlyTrend.slice(-14)
    this.hardest = this.hardestSubject()
  }

  private hardestSubject(): string {
    const subs = AppStore.getInstance().getDashboard().subjectProgress
    if (subs.length === 0) {
      return '数学类任务'
    }
    let hardest = subs[0]
    for (const s of subs) {
      if (s.percent < hardest.percent) {
        hardest = s
      }
    }
    return `${hardest.subject}类任务`
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        Text('你的专注成长画像')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

        // 五维雷达图
        Column() {
          RadarChart({ values: this.dimValues, labels: this.dimLabels, chartSize: 280 })
        }
        .profileCard()

        // 个人专注画像
        Column() {
          Text('个人专注画像')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 14 })

          this.profileRow('黄金专注时段', this.profile.bestFocusTime)
          this.profileRow('最容易分心的任务', this.hardest)
          this.profileRow('当前专注阈值', `${this.profile.focusThreshold} min`)
        }
        .profileCard()

        // 专注成长趋势
        Column() {
          Text('专注成长趋势')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')

          Text(`近 30 天平均专注时长  ${this.trendStart()} min → ${this.trendEnd()} min`)
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .margin({ top: 12 })
            .width('100%')

          BarChart({ values: this.trend, labels: [] })
            .margin({ top: 12 })
            .width('100%')
        }
        .profileCard()

        // AI 长期分析
        Column() {
          Row() {
            Text('AI 长期分析')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            AITag()
          }
          .width('100%')

          Text(AIService.getInstance().longTermAnalysis(this.profile, this.hardest))
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .lineHeight(24)
            .margin({ top: 10 })
        }
        .profileCard()

        Blank().height(20)
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }

  private trendStart(): number {
    if (this.profile.monthlyTrend.length === 0) {
      return 0
    }
    return this.profile.monthlyTrend[0]
  }

  private trendEnd(): number {
    if (this.profile.monthlyTrend.length === 0) {
      return 0
    }
    return this.profile.monthlyTrend[this.profile.monthlyTrend.length - 1]
  }

  @Builder
  profileRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(Colors.TEXT_SECONDARY)
      Blank()
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }
}

@Extend(Column)
function profileCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
