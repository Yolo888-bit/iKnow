import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { AIService } from '../services/AIService'
import { Metrics } from '../services/Metrics'
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
  @State hardest: string = ''
  /** 长期分析文案：在 refresh() 里算好（窗口指标现算，不放进持久化的 Profile） */
  @State aiAdvice: string = ''
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
    // 近 7 天/前 7 天与连续学习天数是**窗口指标**，每次现算（§6.4：不进 FocusProfile）
    const now = Date.now()
    const sessions = AppStore.getInstance().getSessions()
    this.aiAdvice = AIService.getInstance().longTermAnalysis(this.profile, this.hardest,
      Metrics.trend7v7(sessions, now), Metrics.streaks(sessions, now))
  }

  /** 推进最慢的科目；没有科目数据时返回空串（原来返回硬编码的『数学类任务』= 凭空生成结论） */
  private hardestSubject(): string {
    const subs = AppStore.getInstance().getDashboard().subjectProgress
    if (subs.length === 0) {
      return ''
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

        if (Metrics.canShowProfile(this.profile.sampleCount)) {
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
          this.profileRow('最容易分心的任务', this.hardest.length > 0 ? this.hardest : '暂无科目数据')
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

          if (this.hasTrend()) {
            Text(`近 30 天平均专注时长  ${this.trendStart()} min → ${this.trendEnd()} min`)
              .fontSize(15)
              .fontColor(Colors.TEXT_PRIMARY)
              .margin({ top: 12 })
              .width('100%')

            BarChart({ values: this.trend, labels: [] })
              .margin({ top: 12 })
              .width('100%')
          } else {
            // 近 30 天确实没有记录时如实说明，不给「0 min → 0 min」+ 空柱状图
            Text('近 30 天还没有专注记录')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 12 })
              .width('100%')
          }
        }
        .profileCard()

        // 长期分析
        Column() {
          Row() {
            Text('长期分析')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            AITag()
          }
          .width('100%')

          Text(this.aiAdvice)
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .lineHeight(24)
            .margin({ top: 10 })
        }
        .profileCard()

        } else {
          // 硬规则 §5/§6：样本不足，禁止显示默认五维雷达图，仅给空态
          Column() {
            Text('🌱 还在了解你')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('完成 3 次专注后，我会根据真实数据为你生成五维画像与成长趋势。')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .lineHeight(22)
              .margin({ top: 12 })
              .width('100%')
          }
          .profileCard()
        }

        Blank().height(20)
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }

  /** 近 30 天是否有专注记录（全 0 视为没有记录） */
  private hasTrend(): boolean {
    let sum = 0
    for (let i = 0; i < this.trend.length; i++) {
      sum += this.trend[i]
    }
    return sum > 0
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
