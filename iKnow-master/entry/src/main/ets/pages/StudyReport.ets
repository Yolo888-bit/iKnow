import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { StorageService } from '../services/StorageService'
import { Metrics } from '../services/Metrics'
import { SimActivity } from '../services/WatchSignalSimulator'
import { FocusSession, FocusTimelinePoint } from '../models/FocusSession'
import { StudyReport as StudyReportModel } from '../models/StudyReport'
import { QuestionRecord } from '../models/QuestionRecord'
import { ObservationRecord } from '../models/WatchSignal'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusChart, StateRun } from '../components/FocusChart'

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
  @State distractStr: string = ''
  @State bestPeriod: string = ''
  @State fatigueMin: number = 0
  @State focusRate: number = 0
  @State completionRate: number = 0
  @State taskDone: number = 0
  @State taskTotal: number = 0
  @State qaCount: number = 0
  @State questions: QuestionRecord[] = []
  /** 图的横轴：本次真实时间（毫秒），直接决定刻度上的时刻 */
  @State chartStartMs: number = 0
  @State chartEndMs: number = 0
  /** 状态段（绝对时间，已合并连续同状态）—— 由 buildChartRuns() 组装 */
  @State chartRuns: StateRun[] = []
  /**
   * 横轴是否为**真实时刻**。
   * 旧记录（没有 atMs）只能按「已判定学习时长」推算，休息/暂停也排不进去 ——
   * 这时图注要如实说明，不能让用户以为图上就是真实时间。
   */
  @State chartClockAxis: boolean = true
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
  /** 图片文件读不出来的观察记录 id：用于在那一行如实说明，而不是留空白 */
  @State failedImages: string[] = []
  /** 本次真实抓拍到画面的记录（不论云端判成什么）—— 供「本次画面片段」区块展示 */
  @State shots: ObservationRecord[] = []

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
    // 统计时长一律**精确到秒**：只用分钟时"本次专注 39 秒"会显示成 0min，像没数据
    this.totalStr = TimeUtils.formatSec(Metrics.totalStudySec(session))
    this.netStr = TimeUtils.formatSec(Metrics.netFocusSec(session))
    this.distractStr = TimeUtils.formatSec(Metrics.distractionSec(session))
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
    this.bestPeriod = report.bestFocusPeriod
    this.fatigueMin = report.fatiguePoint
    this.focusRate = report.focusRate
    this.completionRate = report.completionRate
    this.taskDone = session.completedTaskIds.length
    this.taskTotal = session.taskIds.length
    this.qaCount = report.questions.length
    this.questions = report.questions
    this.buildChartRuns(session)
    this.loadObservations(session.id)
  }

  // ---------- 复盘图的数据组装 ----------

  /**
   * 把会话的状态时间线组装成「**真实时间**的状态段」。
   *
   * 为什么要单独组装（而不像以前那样直接把 levels/states 丢给图）：
   *  - 图的横轴是真实钟点，所以每个段要有绝对起止时间；
   *  - 时间线里现在也包含「休息 / 暂停 / 答疑」的采样点（见 FocusController），
   *    于是这些时段能在图上以黄/灰单独标出，而不是被画成"一直在专注"。
   *
   * 旧记录没有 `atMs`（没有时刻信息）：退回按「已判定学习秒数」从会话起点推算，
   * 并把 `chartClockAxis` 置 false，让图注如实说明"横轴不是真实时间"。
   */
  private buildChartRuns(session: FocusSession): void {
    const tl = session.timeline
    if (tl.length === 0) {
      this.chartRuns = []
      this.chartClockAxis = true
      return
    }
    let hasClock = false
    for (const p of tl) {
      if (p.atMs > 0) {
        hasClock = true
        break
      }
    }
    this.chartClockAxis = hasClock

    const startMs = session.startTime > 0 ? session.startTime : tl[0].atMs
    let endMs = session.endTime > 0 ? session.endTime : Date.now()
    if (endMs <= startMs) {
      endMs = startMs + 60 * 1000
    }

    const runs: StateRun[] = []
    let runStart = startMs
    let runState = tl[0].state
    for (let i = 1; i < tl.length; i++) {
      if (tl[i].state === runState) {
        continue
      }
      const cut = this.pointMs(tl[i], startMs, hasClock)
      if (cut > runStart) {
        runs.push(this.runOf(runStart, cut, runState))
        runStart = cut
      }
      runState = tl[i].state
    }
    // 最后一段延伸到会话结束：否则最后一个状态在图上没有宽度
    if (endMs > runStart) {
      runs.push(this.runOf(runStart, endMs, runState))
    }
    this.chartRuns = runs
    this.chartStartMs = startMs
    this.chartEndMs = endMs
  }

  /** 采样点的绝对时刻：新记录直接用 atMs；旧记录按"已判定学习秒数"从起点推算 */
  private pointMs(p: FocusTimelinePoint, startMs: number, hasClock: boolean): number {
    if (hasClock && p.atMs > 0) {
      return p.atMs
    }
    const sec = p.sec > 0 ? p.sec : p.minute * 60
    return startMs + sec * 1000
  }

  private runOf(fromMs: number, toMs: number, state: string): StateRun {
    const r = new StateRun()
    r.fromMs = fromMs
    r.toMs = toMs
    r.state = state
    return r
  }

  /** 毫秒 → "14:05"（图注里写起止时刻用） */
  private clockOf(ms: number): string {
    const d = new Date(ms)
    return TimeUtils.minuteToClock(d.getHours() * 60 + d.getMinutes())
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
    const shots: ObservationRecord[] = []
    let learning = 0
    let undetermined = 0
    try {
      const all = await StorageService.getInstance().loadObservations(sessionId)
      for (const o of all) {
        // 有画面片段的都收进「本次画面片段」——**不管云端判成什么**：
        // 判成"看书/做题"时不进干扰事件列表，但照片确实拍了、也该看得见。
        // 模拟注入的记录：无摄像头时 imagePaths 为空，但 UI 层会显示 media 占位图，
        // 同样要出现在「本次画面片段」里，保证控制台演示的完整感。
        const isSimInject = o.evidence.includes('模拟注入')
        if (o.imagePaths.length > 0 || isSimInject) {
          shots.push(o)
        }
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
    this.shots = shots
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

  /**
   * 返回「复盘」总页面。
   *
   * 为什么不能只 `router.back()`：结束专注时 Focus 是 `replaceUrl` 到本页的，
   * 页面栈里只剩下「根页 + 本页」，直接退回去会落在根页的**首页（专注）Tab** 上 ——
   * 用户看到的就是"点返回怎么又回到专注了"。
   * 所以先把 Tab 请求设成复盘（2），再退回根页，由根页的 onTabRequest 切过去。
   */
  private backToReview(): void {
    AppStorage.setOrCreate<number>(StorageKey.INDEX_TAB_REQUEST, 2)
    // 栈形状已经由"休息页把结束委托给专注页"保证：本页一律是「根页 → 本页」，
    // 退一层就是根页，由根页按 INDEX_TAB_REQUEST 切到「复盘」。
    // （不再用 `router.back(0)`：它在不同版本上行为不稳，反而会退错。）
    router.back()
  }

  /** 系统返回键与左上角箭头行为保持一致：都回到复盘总页面 */
  onBackPress(): boolean {
    this.backToReview()
    return true
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        // 顶部：左上角返回箭头 → 复盘总页面（本次专注已经结束，不该再退回去继续专注）
        Row() {
          Row() {
            Text('←')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('返回复盘')
              .fontSize(15)
              .fontColor(Colors.TEXT_PRIMARY)
              .margin({ left: 4 })
          }
          .padding({ top: 6, bottom: 6, right: 10 })
          .onClick(() => {
            this.backToReview()
          })
          Blank()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 2 })

        if (!this.hasData) {
          Text('还没有可展示的复盘')
            .fontSize(16)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 60 })
          Button('返回复盘')
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY_STRONG)
            .height(44)
            .margin({ top: 16 })
            .onClick(() => {
              this.backToReview()
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

          // ① 专注数据总览（口径自解释，可验算）
          Column() {
            this.sectionTitle('专注数据总览')
            Row({ space: 12 }) {
              this.stat('总学习时长', this.totalStr)
              this.stat('净专注时长', this.netStr)
            }
            .width('100%')
            .margin({ top: 12 })
            Row({ space: 12 }) {
              this.stat('净专注率', `${this.focusRate}%`)
              this.stat('完成任务', this.taskTotal > 0
                ? `${this.taskDone}/${this.taskTotal} · ${this.completionRate}%` : '自由专注')
            }
            .width('100%')
            .margin({ top: 10 })
            Row({ space: 12 }) {
              this.stat('AI 答疑', `${this.qaCount} 个问题`)
              this.stat('分心', this.distractStr)
            }
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

          // ③ 专注时间轴（横轴=真实时间）+ 心率曲线区
          Column() {
            this.sectionTitle('专注时间轴')
            FocusChart({
              runs: this.chartRuns,
              startMs: this.chartStartMs,
              endMs: this.chartEndMs,
              // 会话里还没有心率留痕 → 传空数组，图内画占位虚线并写明"暂无数据"
              hrPoints: []
            })
            Text(this.chartClockAxis
              ? `横轴：本次真实时间 ${this.clockOf(this.chartStartMs)} – ${this.clockOf(this.chartEndMs)}；色带 = 该时刻的状态`
                + `（绿 专注 / 红 分心 / 黄 休息 / 灰 暂停·答疑）`
              : '横轴：本条记录较早，未保存时刻信息，按「已判定学习时长」推算；'
                + '休息 / 暂停未单独标出（色带：绿 专注 / 红 分心）')
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .lineHeight(17)
              .width('100%')
              .margin({ top: 6 })
            Text('纵轴：心率曲线 —— 本版本未接入心率设备，图中为占位虚线，不代表任何测量值')
              .fontSize(11)
              .fontColor(Colors.TEXT_TERTIARY)
              .lineHeight(17)
              .width('100%')
              .margin({ top: 4 })
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
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
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
                      Text(o.activity)
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

                    // 照片展示位：有真实片段就显示真实照片；没有（模拟注入/无摄像头）则显示
                    // media 资源里的「演示占位图」，保证控制台演示时复盘也能看到画面片段，
                    // 同时图片自身已标注"非真实抓拍"，不会误导。
                    if (o.imagePaths.length > 0) {
                      Image(this.fileUri(o.imagePaths[0]))
                        .width(120)
                        .height(90)
                        .borderRadius(Radius.MD)
                        .margin({ top: 8 })
                        // 文件被清除、或换设备/升级后路径失效时如实说明 ——
                        // 否则留一块空白，看起来就像"照片莫名没了"
                        .onError(() => {
                          if (this.failedImages.indexOf(o.id) < 0) {
                            this.failedImages = this.failedImages.concat(o.id)
                          }
                        })
                      if (this.failedImages.indexOf(o.id) >= 0) {
                        Text('画面片段文件读不出来（可能已被清除，或换设备后路径失效）')
                          .fontSize(11)
                          .fontColor(Colors.CAMERA_RED)
                          .width('100%')
                          .margin({ top: 4 })
                      }
                    } else {
                      Column() {
                        Image($r('app.media.sim_placeholder'))
                          .width(120)
                          .height(90)
                          .objectFit(ImageFit.Cover)
                          .borderRadius(Radius.MD)
                        Text('演示占位图 · 非真实抓拍')
                          .fontSize(10)
                          .fontColor(Colors.TEXT_TERTIARY)
                          .margin({ top: 4 })
                          .width('100%')
                          .textAlign(TextAlign.Center)
                      }
                      .width(120)
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

          // ⑥ 本次画面片段：**所有**带画面的记录（不限于干扰事件）
          // 为什么单独列一块：照片原先只挂在"干扰事件"下面，云端判成"看书/做题"就一张都看不到 ——
          // 而"触发了、也带回了画面"这件事本身就该看得见。
          if (this.obsLoaded && this.shots.length > 0) {
            Column({ space: Spacing.SM }) {
              this.sectionTitle(`本次画面片段（${this.shots.length} 张）`)
              Text('这些是触发时抓拍的画面；未接摄像头时为「演示占位图」（图片已标注，非真实照片）。' +
                '每次只保留前几张，可在「我的 → 隐私与数据」里一键清除。')
                .fontSize(11)
                .fontColor(Colors.TEXT_TERTIARY)
                .lineHeight(16)
                .width('100%')

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.shots, (o: ObservationRecord) => {
                  Column() {
                    if (o.imagePaths.length > 0) {
                      Image(this.fileUri(o.imagePaths[0]))
                        .width(96)
                        .height(72)
                        .borderRadius(Radius.MD)
                        .onError(() => {
                          if (this.failedImages.indexOf(o.id) < 0) {
                            this.failedImages = this.failedImages.concat(o.id)
                          }
                        })
                    } else {
                      Image($r('app.media.sim_placeholder'))
                        .width(96)
                        .height(72)
                        .objectFit(ImageFit.Cover)
                        .borderRadius(Radius.MD)
                    }
                    if (this.failedImages.indexOf(o.id) >= 0) {
                      Text('文件已清除')
                        .fontSize(10)
                        .fontColor(Colors.CAMERA_RED)
                        .margin({ top: 2 })
                    } else {
                      Text(`${o.activity}`)
                        .fontSize(11)
                        .fontColor(Colors.TEXT_SECONDARY)
                        .margin({ top: 4 })
                    }
                    Text(this.relMin(o.tMs))
                      .fontSize(10)
                      .fontColor(Colors.TEXT_TERTIARY)
                  }
                  .width(96)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ right: 12, bottom: 12 })
                }, (o: ObservationRecord) => o.id)
              }
              .width('100%')
              .margin({ top: 4 })
            }
            .reportCard()
          }


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
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
  // 兜底：卡片内任何内容算宽了都不许画到相邻卡片上（此前没有这层保护，溢出会交叠）
  .clip(true)
}
