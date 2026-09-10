import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { QuestionRecord } from '../models/QuestionRecord'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusChart } from '../components/FocusChart'
import { AITag } from '../components/AITag'

/** 单次学习复盘 */
@Entry
@Component
export struct StudyReport {
  @State hasData: boolean = false
  @State totalStr: string = ''
  @State netStr: string = ''
  @State focusRate: number = 0
  @State completionRate: number = 0
  @State taskDone: number = 0
  @State taskTotal: number = 0
  @State qaCount: number = 0
  @State insights: string = ''
  @State suggestions: string[] = []
  @State questions: QuestionRecord[] = []
  @State levels: number[] = []
  @State states: string[] = []

  aboutToAppear(): void {
    const report = AppStore.getInstance().getCurrentReport()
    const session = AppStore.getInstance().getCurrentSession()
    if (report === null || session === null) {
      this.hasData = false
      return
    }
    this.hasData = true
    this.totalStr = TimeUtils.formatDuration(session.totalDuration)
    this.netStr = TimeUtils.formatDuration(session.focusDuration)
    this.focusRate = report.focusRate
    this.completionRate = report.completionRate
    this.taskDone = session.completedTaskIds.length
    this.taskTotal = session.taskIds.length
    this.qaCount = report.questions.length
    this.insights = report.insights
    this.suggestions = report.suggestions
    this.questions = report.questions
    for (const p of session.timeline) {
      this.levels.push(p.level)
      this.states.push(p.state)
    }
  }

  private finish(): void {
    router.back()
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        if (!this.hasData) {
          Text('还没有可展示的复盘')
            .fontSize(16)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 60 })
          Button('返回')
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY)
            .height(44)
            .margin({ top: 16 })
            .onClick(() => {
              this.finish()
            })
        } else {
          Column() {
            Text('今天这一段学习完成了 ✨')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('小伴帮你整理好了这次的学习情况')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // ① 专注数据总览
          Column() {
            this.sectionTitle('专注数据总览')
            Row({ space: 12 }) {
              this.stat('总学习时长', this.totalStr)
              this.stat('净专注时长', this.netStr)
            }
            Row({ space: 12 }) {
              this.stat('净专注率', `${this.focusRate}%`)
              this.stat('完成率', `${this.completionRate}%`)
            }
            Row({ space: 12 }) {
              this.stat('完成任务', `${this.taskDone} / ${this.taskTotal}`)
              this.stat('AI 答疑', `${this.qaCount} 个问题`)
            }
          }
          .reportCard()

          // ② 专注曲线
          Column() {
            this.sectionTitle('专注曲线')
            FocusChart({ levels: this.levels, states: this.states })
          }
          .reportCard()

          // ③ AI 学习洞察
          Column() {
            Row() {
              this.sectionTitle('AI 学习洞察')
              Blank()
              AITag()
            }
            Text(this.insights)
              .fontSize(15)
              .fontColor(Colors.TEXT_PRIMARY)
              .lineHeight(24)
              .margin({ top: 8 })
          }
          .reportCard()

          // ④ 优化建议
          Column() {
            this.sectionTitle('💡 下一次可以这样试试')
            ForEach(this.suggestions, (s: string) => {
              Row() {
                Text('•')
                  .fontSize(15)
                  .fontColor(Colors.PRIMARY_DARK)
                Text(s)
                  .fontSize(14)
                  .fontColor(Colors.TEXT_PRIMARY)
                  .margin({ left: 8 })
              }
              .width('100%')
              .margin({ top: 8 })
            }, (s: string) => s)
          }
          .reportCard()

          // ⑤ 今日问题记录
          if (this.questions.length > 0) {
            Column() {
              this.sectionTitle(`今天你问了 ${this.qaCount} 个问题`)
              ForEach(this.questions, (q: QuestionRecord) => {
                Column() {
                  Text(q.question)
                    .fontSize(14)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Text('→ 查看答案')
                    .fontSize(12)
                    .fontColor(Colors.PRIMARY_DARK)
                    .margin({ top: 6 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(12)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .margin({ top: 8 })
              }, (q: QuestionRecord) => q.id)
            }
            .reportCard()
          }

          Button('完成')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY)
            .borderRadius(Radius.LG)
            .margin({ top: 8 })
            .onClick(() => {
              this.finish()
            })

          Blank().height(24)
        }
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.TEXT_PRIMARY)
      .width('100%')
  }

  @Builder
  stat(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(Colors.TEXT_SECONDARY)
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(Colors.BG)
    .borderRadius(Radius.MD)
    .alignItems(HorizontalAlign.Start)
  }
}

@Extend(Column)
function reportCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
