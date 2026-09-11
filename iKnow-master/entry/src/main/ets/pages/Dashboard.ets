import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { TimeUtils } from '../utils/TimeUtils'
import { AIService } from '../services/AIService'
import { BarChart } from '../components/BarChart'
import { SubjectProgress } from '../models/Dashboard'
import { AITag } from '../components/AITag'

/** 我的工作台 —— 学习全局看板 */
@Component
export struct Dashboard {
  @StorageProp(StorageKey.EXAM_DAYS) examDays: number = 0
  @StorageProp(StorageKey.TODAY_DONE_TASKS) todayDone: number = 0
  @StorageProp(StorageKey.TODAY_TOTAL_TASKS) todayTotal: number = 0
  @StorageProp(StorageKey.WEEK_FOCUS_SEC) weekFocus: number = 0
  @StorageProp(StorageKey.FOCUS_RATE) focusRate: number = 0
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refresh') dataVersion: number = 0
  @State weekTrend: number[] = []
  @State subjects: SubjectProgress[] = []
  @State examType: string = '考研'
  @State hardestSubject: string = '综合'
  @State aiInsight: string = ''
  private weekLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']

  aboutToAppear(): void {
    this.refresh()
  }

  refresh(): void {
    const store = AppStore.getInstance()
    const d = store.getDashboard()
    this.weekTrend = d.weekTrend
    this.subjects = d.subjectProgress
    this.examType = store.getGoal().examType

    // 最薄弱学科 = 进度最低者，供 AI 洞察引用（指标统一走 AppStore 聚合）
    let minP = 101
    let hard = '综合'
    for (const sp of this.subjects) {
      if (sp.percent < minP) {
        minP = sp.percent
        hard = sp.subject
      }
    }
    this.hardestSubject = hard

    // 动态 AI 内容必须经 AI 服务返回（硬规则 §1）
    this.aiInsight = AIService.getInstance().longTermAnalysis(store.getProfile(), this.hardestSubject)
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.TEXT_PRIMARY)
      .width('100%')
      .margin({ bottom: 12 })
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        // 顶部标题
        Column() {
          Text('我的工作台')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('全局学习看板 · 数据每日更新')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 6 })
            .width('100%')
        }
        .width('100%')

        // 考试总览
        Column() {
          Row() {
            Column() {
              Text('考试总览')
                .fontSize(14)
                .fontColor(Colors.TEXT_SECONDARY)
              Text(this.examType)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(Colors.PRIMARY_DARK)
                .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Column() {
              Text(`${this.examDays}`)
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor(Colors.TEXT_PRIMARY)
              Text('天')
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          Text(`距离 ${this.examType} 还有 ${this.examDays} 天，按节奏稳步推进`)
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 10 })
            .width('100%')
        }
        .dashCard()

        // 总体进度
        Column() {
          this.sectionTitle('总体进度')
          Row() {
            Text(`${this.todayDone} / ${this.todayTotal}`)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text(this.todayTotal > 0 ? `${Math.round(this.todayDone / this.todayTotal * 100)}%` : '—')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.PRIMARY_DARK)
          }
          .width('100%')
          .margin({ bottom: 10 })
          Progress({
            value: this.todayDone,
            total: Math.max(1, this.todayTotal),
            type: ProgressType.Linear
          })
            .color(Colors.PRIMARY)
            .backgroundColor(Colors.LINE)
            .width('100%')
          Text('今日任务完成进度')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 8 })
            .width('100%')
        }
        .dashCard()

        // 科目进度
        Column() {
          this.sectionTitle('科目进度')
          if (this.subjects.length === 0) {
            Text('开始学习后，这里会显示各学科的完成进度')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .width('100%')
          } else {
            ForEach(this.subjects, (sp: SubjectProgress) => {
              Column() {
                Row() {
                  Text(sp.subject)
                    .fontSize(14)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Blank()
                  Text(`${sp.percent}%`)
                    .fontSize(14)
                    .fontColor(Colors.PRIMARY_DARK)
                }
                .width('100%')
                Progress({ value: sp.percent, total: 100, type: ProgressType.Linear })
                  .color(Colors.PRIMARY)
                  .backgroundColor(Colors.LINE)
                  .width('100%')
                  .margin({ top: 8 })
              }
              .width('100%')
              .margin({ top: 14 })
            }, (sp: SubjectProgress) => sp.subject)
          }
        }
        .dashCard()

        // 长期趋势
        Column() {
          this.sectionTitle('长期趋势')
          Text('近 7 天净专注时长（分钟）')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .margin({ bottom: 10 })
          BarChart({ values: this.weekTrend, labels: this.weekLabels })
            .width('100%')
          Text(`本周累计净专注 ${TimeUtils.formatHMin(this.weekFocus)}`)
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 10 })
            .width('100%')
        }
        .dashCard()

        // AI 洞察
        Column() {
          Row() {
            Text('AI 洞察')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            AITag()
          }
          .width('100%')
          .margin({ bottom: 10 })
          Text(this.aiInsight)
            .fontSize(14)
            .lineHeight(22)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
        }
        .dashCard()

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

@Extend(Column)
function dashCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
