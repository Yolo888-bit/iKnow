import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { TimeUtils } from '../utils/TimeUtils'
import { BarChart } from '../components/BarChart'
import { SubjectProgress } from '../models/Dashboard'

/** 我的工作台 —— 学习全局看板 */
@Component
export struct Dashboard {
  @StorageProp(StorageKey.EXAM_DAYS) examDays: number = 0
  @StorageProp(StorageKey.TODAY_DONE_TASKS) todayDone: number = 0
  @StorageProp(StorageKey.TODAY_TOTAL_TASKS) todayTotal: number = 0
  @StorageProp(StorageKey.WEEK_FOCUS_SEC) weekFocus: number = 0
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refresh') dataVersion: number = 0
  @State weekTrend: number[] = []
  @State subjects: SubjectProgress[] = []
  @State examType: string = '考研'
  private weekLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']

  aboutToAppear(): void {
    this.refresh()
  }

  refresh(): void {
    const d = AppStore.getInstance().getDashboard()
    this.weekTrend = d.weekTrend
    this.subjects = d.subjectProgress
    this.examType = AppStore.getInstance().getGoal().examType
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        // 顶部
        Column() {
          Text('我的工作台')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text(`距离${this.examType}还有 ${this.examDays} 天`)
            .fontSize(15)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 6 })
            .width('100%')
        }
        .width('100%')

        // 今日目标
        Column() {
          Text('今日任务')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
          Text(`${this.todayDone} / ${this.todayTotal} 已完成`)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .margin({ top: 4 })
            .width('100%')
          Progress({
            value: this.todayDone,
            total: Math.max(1, this.todayTotal),
            type: ProgressType.Linear
          })
            .color(Colors.PRIMARY)
            .backgroundColor(Colors.LINE)
            .width('100%')
            .margin({ top: 14 })
        }
        .dashCard()

        // 本周学习数据
        Column() {
          Text('本周已学习')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
          Text(TimeUtils.formatHMin(this.weekFocus))
            .fontSize(26)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .margin({ top: 4 })
            .width('100%')
          Text('近 7 天净专注趋势（分钟）')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 4 })
            .width('100%')
          BarChart({ values: this.weekTrend, labels: this.weekLabels })
            .margin({ top: 12 })
            .width('100%')
        }
        .dashCard()

        // 学科进度
        Column() {
          Text('学科 / 任务进度')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 12 })

          if (this.subjects.length === 0) {
            Text('开始学习后，这里会显示各学科的进度')
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
