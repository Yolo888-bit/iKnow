import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { StorageService } from '../services/StorageService'
import { Metrics } from '../services/Metrics'
import { SimActivity } from '../services/WatchSignalSimulator'
import { FocusSession } from '../models/FocusSession'
import { StudyReport as StudyReportModel } from '../models/StudyReport'
import { QuestionRecord } from '../models/QuestionRecord'
import { ObservationRecord } from '../models/WatchSignal'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusChart } from '../components/FocusChart'

/**
 * 与 `FocusController.onObservation` 的规则组合同源：手持手机 / 看手机 / 离开 / 趴桌
 * 才会被判为干扰；"做题 / 看书"是在学习的证据，不能列进干扰事件。
 */
function isInterference(o: ObservationRecord): boolean {
  return o.handheld || SimActivity.DISTRACTING.includes(o.activity) || SimActivity.LIGHT_ONLY.includes(o.activity)
}

/**
 * 单次学习复盘 —— 定位是**档案记录**：
 * 只呈现这次实际发生了什么（数据、曲线、时段特征、问答、干扰事件），
 * 不做引导式的"下次你可以…"建议（那类内容属于「复盘」Tab 的长期建议）。
 */
@Entry
@Component
export struct StudyReport {
  @State hasData: boolean = false
  @State totalStr: string = ''
  @State netStr: string = ''
  @State wallStr: string = ''
  @State distractStr: string = ''
  @State qaStr: string = ''
  @State breakStr: string = ''
  @State pauseStr: string = ''
  @State bestPeriod: string = ''
  @State fatigueMin: number = 0
  @State focusRate: number = 0
  @State completionRate: number = 0
  @State taskDone: number = 0
  @State taskTotal: number = 0
  @State qaCount: number = 0
  @State questions: QuestionRecord[] = []
  @State levels: number[] = []
  @State states: string[] = []
  @State minutes: number[] = []
  /** 本次专注得分 = 100 − 走神占比（取整，夹 0~100） */
  @State score: number = 0
  /** 走神时间占总学习时间的百分比（取整） */
  @State distractRatio: number = 0
  /** 本次会话里**真正算干扰**的观察记录（看手机 / 离开 / 趴桌） */
  @State interference: ObservationRecord[] = []
  /** 云端确认为"在做题/看书"的次数 —— 属于学习确认，不该混进干扰事件 */
  @State learningConfirmCount: number = 0
  /** 未能判断的次数（多人 / 无法判断 / 识别失败） */
  @State undeterminedCount: number = 0
  @State obsLoaded: boolean = false
  @State sessionStartMs: number = 0
  /** 当前展开答案的问题 id（空串 = 全部收起） */
  @State expandedQ: string = ''

  aboutToAppear(): void {
    // 从「学习记录」进来时带 sessionId：改为从库里加载那一次的复盘
    const raw: string | undefined = AppStorage.get<string>(StorageKey.REPORT_SESSION_ID)
    const wantId = raw !== undefined ? raw : ''
    AppStorage.setOrCreate<string>(StorageKey.REPORT_SESSION_ID, '')
    if (wantId.length > 0) {
      this.loadFromStore(wantId)
      return
    }
    this.applyReport(AppStore.getInstance().getCurrentReport(), AppStore.getInstance().getCurrentSession())
  }

  /** 按会话 id 从数据库加载复盘（原先只认内存态，重启后再点开就是空白） */
  private async loadFromStore(sessionId: string): Promise<void> {
    try {
      const report = await StorageService.getInstance().loadReport(sessionId)
      const sessions = await StorageService.getInstance().loadSessions()
      let session: FocusSession | null = null
      for (const s of sessions) {
        if (s.id === sessionId) {
          session = s
          break
        }
      }
      this.applyReport(report, session)
    } catch (e) {
      this.hasData = false
    }
  }

  private applyReport(report: StudyReportModel | null, session: FocusSession | null): void {
    if (report === null || session === null) {
      this.hasData = false
      return
    }
    this.hasData = true
    this.sessionStartMs = session.startTime
    // 全部口径走 Metrics（与同页净专注率同分母），不再直接用墙钟当"总学习时长"
    this.totalStr = TimeUtils.formatDuration(Metrics.totalStudySec(session))
    this.wallStr = TimeUtils.formatDuration(Metrics.wallClock(session))
    this.netStr = TimeUtils.formatDuration(Metrics.netFocusSec(session))
    this.distractStr = TimeUtils.formatDuration(Metrics.distractionSec(session))
    // 本次专注得分：走神占比越低分越高；无数据时按满分处理（避免显示 0 分误导）
    const totalStudy: number = Metrics.totalStudySec(session)
    const ratio: number = totalStudy > 0
      ? Math.round(Metrics.distractionSec(session) / totalStudy * 100)
      : 0
    this.distractRatio = ratio
    let sc: number = 100 - ratio
    if (sc < 0) {
      sc = 0
    }
    if (sc > 100) {
      sc = 100
    }
    this.score = sc
    this.qaStr = TimeUtils.formatDuration(Metrics.qaSec(session))
    this.breakStr = TimeUtils.formatDuration(Metrics.restSec(session))
    this.pauseStr = TimeUtils.formatDuration(Metrics.pauseSec(session))
    this.bestPeriod = report.bestFocusPeriod
    this.fatigueMin = report.fatiguePoint
    this.focusRate = report.focusRate
    this.completionRate = report.completionRate
    this.taskDone = session.completedTaskIds.length
    this.taskTotal = session.taskIds.length
    this.qaCount = report.questions.length
    this.questions = report.questions
    const levels: number[] = []
    const states: string[] = []
    const minutes: number[] = []
    for (const p of session.timeline) {
      levels.push(p.level)
      states.push(p.state)
      minutes.push(p.minute)
    }
    this.levels = levels
    this.states = states
    this.minutes = minutes
    this.loadObservations(session.id)
  }

  /**
   * 载入本次会话的观察记录，并**按语义分三类**：
   *  - 干扰事件：会触发干预的那些（看手机 / 离开 / 趴桌）—— 只有这些属于"干扰"；
   *  - 学习确认：云端确认为"做题 / 看书"—— 这是**在学习的证据**，混进"干扰事件"是不合理的；
   *  - 未能判断：多人 / 无法判断 —— 不产生任何结论，只计数。
   *
   * 分类判据与 `FocusController.onObservation` 的规则组合保持一致，避免两处口径分叉。
   */
  private async loadObservations(sessionId: string): Promise<void> {
    const bad: ObservationRecord[] = []
    let learning = 0
    let undetermined = 0
    try {
      const all = await StorageService.getInstance().loadObservations(sessionId)
      for (const o of all) {
        if (isInterference(o)) {
          bad.push(o)
        } else if (SimActivity.LEARNING.includes(o.activity)) {
          learning += 1
        } else {
          undetermined += 1
        }
      }
    } catch (e) {
      // 读不到就是空态，不编造
    }
    this.interference = bad
    this.learningConfirmCount = learning
    this.undeterminedCount = undetermined
    this.obsLoaded = true
  }

  /** 图片是保存在应用沙箱里的，用 file:// 前缀交给 Image 渲染 */
  private fileUri(p: string): string {
    return `file://${p}`
  }

  /** 把绝对时间换算成"本次会话第几分钟" */
  private relMin(tMs: number): string {
    const min = Math.max(0, Math.floor((tMs - this.sessionStartMs) / 60000))
    return `第 ${min} 分钟`
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
            .backgroundColor(Colors.PRIMARY_STRONG)
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

          // ① 专注曲线（置顶）+ 本次专注得分
          Column() {
            Row() {
              Column() {
                Text('本次专注得分')
                  .fontSize(13)
                  .fontColor(Colors.TEXT_SECONDARY)
                Row() {
                  Text(`${this.score}`)
                    .fontSize(38)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Colors.PRIMARY_DARK)
                  Text('分')
                    .fontSize(13)
                    .fontColor(Colors.TEXT_SECONDARY)
                    .margin({ left: 3, bottom: 6 })
                }
                .alignItems(VerticalAlign.Bottom)
                .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column() {
                Text(`${this.distractRatio}%`)
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.distractRatio > 30 ? Colors.RED : Colors.TEXT_PRIMARY)
                Text('走神占比')
                  .fontSize(12)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            FocusChart({ levels: this.levels, states: this.states, minutes: this.minutes })
              .margin({ top: 12 })

            Text(`得分 = 100 − 走神占比（走神 ${this.distractStr} ÷ 总学习 ${this.totalStr}）`)
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .width('100%')
              .margin({ top: 10 })
          }
          .reportCard()

          // ② 专注数据总览（口径自解释，可验算）
          Column() {
            this.sectionTitle('专注数据总览')
            Row({ space: 12 }) {
              this.stat('总学习时长', this.totalStr)
              this.stat('净专注时长', this.netStr)
            }
            Row({ space: 12 }) {
              this.stat('净专注率', `${this.focusRate}%`)
              this.stat('完成率', this.taskTotal > 0 ? `${this.completionRate}%` : '—')
            }
            Row({ space: 12 }) {
              this.stat('完成任务', this.taskTotal > 0 ? `${this.taskDone} / ${this.taskTotal}` : '本次未设定任务')
              this.stat('AI 答疑', `${this.qaCount} 个问题`)
            }
            Row({ space: 12 }) {
              this.stat('分心', this.distractStr)
              this.stat('休息', this.breakStr)
              this.stat('暂停', this.pauseStr)
            }
            Text(`总学习 = 墙钟 ${this.wallStr} − 休息 ${this.breakStr} − 暂停 ${this.pauseStr}`)
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .width('100%')
              .margin({ top: 10 })
          }
          .reportCard()

          // ② 本次时段特征（此前算出来但从未渲染）
          Column() {
            this.sectionTitle('本次时段特征')
            if (this.bestPeriod.length === 0 && this.fatigueMin <= 0) {
              Text('本次时长较短或状态平稳，还没形成明显的时段特征')
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 8 })
                .width('100%')
            } else {
              if (this.bestPeriod.length > 0) {
                Row() {
                  Text('最佳专注时段')
                    .fontSize(13)
                    .fontColor(Colors.TEXT_SECONDARY)
                  Blank()
                  Text(this.bestPeriod)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.TEXT_PRIMARY)
                }
                .width('100%')
                .margin({ top: 8 })
              }
              if (this.fatigueMin > 0) {
                Row() {
                  Text('疲劳信号出现')
                    .fontSize(13)
                    .fontColor(Colors.TEXT_SECONDARY)
                  Blank()
                  Text(`第 ${this.fatigueMin} 分钟`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.TEXT_PRIMARY)
                }
                .width('100%')
                .margin({ top: 8 })
              }
            }
          }
          .reportCard()

          // ④ 今日问题记录
          if (this.questions.length > 0) {
            Column() {
              this.sectionTitle(`今天你问了 ${this.qaCount} 个问题`)
              ForEach(this.questions, (q: QuestionRecord) => {
                Column() {
                  Text(q.question)
                    .fontSize(14)
                    .fontColor(Colors.TEXT_PRIMARY)
                  // 档案页就该能查到当时的答案：展开/收起，不再是点了没反应的死链
                  Text(this.expandedQ === q.id ? '收起答案 ▲' : '展开答案 ▼')
                    .fontSize(12)
                    .fontColor(Colors.PRIMARY_DARK)
                    .margin({ top: 6 })
                  if (this.expandedQ === q.id) {
                    Text(q.answer.length > 0 ? q.answer : '这条提问当时没有留下答案')
                      .fontSize(13)
                      .fontColor(Colors.TEXT_SECONDARY)
                      .lineHeight(20)
                      .margin({ top: 8 })
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(12)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .margin({ top: 8 })
                .onClick(() => {
                  this.expandedQ = this.expandedQ === q.id ? '' : q.id
                })
              }, (q: QuestionRecord) => q.id)
            }
            .reportCard()
          }

          // ⑤ 干扰事件时间线（手表触发 → 抓拍 → 云端可观察状态）
          if (this.obsLoaded) {
            Column() {
              this.sectionTitle('本次干扰事件')
              Text('由手表状态变化触发抓拍，云端只给出"在做什么"的可观察结论，不做注意力推断。' +
                '只有会触发干预的状态（看手机 / 趴桌 / 离开）计入这里；'
                + '云端确认为"做题 / 看书"属于学习证据，不列为干扰。')
                .fontSize(12)
                .fontColor(Colors.TEXT_TERTIARY)
                .lineHeight(16)
                .width('100%')
                .margin({ top: 6 })

              // 分类计数：让"为什么这里只列出了几条"一目了然
              Row({ space: 10 }) {
                Column() {
                  Text(`${this.interference.length}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Text('干扰事件')
                    .fontSize(11)
                    .fontColor(Colors.TEXT_SECONDARY)
                }
                .layoutWeight(1)
                .padding(10)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .alignItems(HorizontalAlign.Start)

                Column() {
                  Text(`${this.learningConfirmCount}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Text('确认为学习中')
                    .fontSize(11)
                    .fontColor(Colors.TEXT_SECONDARY)
                }
                .layoutWeight(1)
                .padding(10)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .alignItems(HorizontalAlign.Start)

                Column() {
                  Text(`${this.undeterminedCount}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Text('未能判断')
                    .fontSize(11)
                    .fontColor(Colors.TEXT_SECONDARY)
                }
                .layoutWeight(1)
                .padding(10)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .margin({ top: 10 })

              if (this.interference.length === 0) {
                Text('本次没有被判定为干扰的事件。')
                  .fontSize(13)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ top: 12 })
                  .width('100%')
              } else {
                ForEach(this.interference, (o: ObservationRecord) => {
                  Column() {
                    Row() {
                      Text(this.relMin(o.tMs))
                        .fontSize(13)
                        .fontColor(Colors.TEXT_SECONDARY)
                      Blank()
                      Text(`${o.activity} · 置信度 ${Math.round(o.confidence * 100)}%`)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Colors.TEXT_PRIMARY)
                    }
                    .width('100%')

                    Text(o.evidence)
                      .fontSize(12)
                      .fontColor(Colors.TEXT_SECONDARY)
                      .margin({ top: 4 })
                      .width('100%')

                    // 照片展示位：有真实片段就显示，没有则给占位（不留空、也不假装有图）
                    if (o.imagePaths.length > 0) {
                      Image(this.fileUri(o.imagePaths[0]))
                        .width(120)
                        .height(90)
                        .borderRadius(Radius.MD)
                        .margin({ top: 8 })
                    } else {
                      Column() {
                        Text('🖼').fontSize(18)
                        Text('暂无画面片段')
                          .fontSize(11)
                          .fontColor(Colors.TEXT_TERTIARY)
                          .margin({ top: 2 })
                      }
                      .width(120)
                      .height(90)
                      .justifyContent(FlexAlign.Center)
                      .alignItems(HorizontalAlign.Center)
                      .backgroundColor(Colors.CARD)
                      .border({ width: 0.5, color: Colors.LINE, style: BorderStyle.Dashed })
                      .borderRadius(Radius.MD)
                      .margin({ top: 8 })
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .padding(12)
                  .backgroundColor(Colors.BG)
                  .borderRadius(Radius.MD)
                  .margin({ top: 10 })
                }, (o: ObservationRecord) => o.id)
              }
            }
            .reportCard()
          }

          Button('返回')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY_STRONG)
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
