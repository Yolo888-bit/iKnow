import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AIService } from '../services/AIService'
import { FocusController } from '../services/FocusController'
import { StorageService } from '../services/StorageService'
import { AppStore } from '../store/AppStore'
import { QAMessage, QATextPayload } from '../services/ai/QAService'
import { AIMessage } from '../models/AIMessage'
import { QuestionRecord } from '../models/QuestionRecord'
import { MessageRole } from '../models/Enums'
import { IdUtils } from '../utils/IdUtils'
import { TimeUtils } from '../utils/TimeUtils'
import { AITag } from '../components/AITag'
import { AIFirstDisclaimer } from '../components/AIFirstDisclaimer'
import { VoiceInputButton } from '../components/VoiceInputButton'

/** 专注中的 AI 答疑（计时不中断） */
@Entry
@Component
export struct AIChat {
  @StorageProp(StorageKey.FOCUS_QA_ELAPSED) qaElapsed: number = 0
  @StorageProp(StorageKey.FOCUS_ELAPSED) elapsed: number = 0
  @State messages: AIMessage[] = []
  /** 该用户最近问过的问题（跨会话记忆） */
  private priorQuestions: string[] = []
  @State inputValue: string = ''
  @State answering: boolean = false
  /** 流式输出中：正文逐段写入 streamingText，流结束后再落到消息列表 */
  @State streaming: boolean = false
  @State streamingText: string = ''
  /** 最后一条 AI 消息与其来源，用于如实标注「大模型回答 / 本地模板回答」 */
  @State lastAiMsgId: string = ''
  @State lastAiSource: string = ''

  // ---------- 悬浮球（返回专注）----------
  @State fabX: number = 320
  @State fabY: number = 420
  /** 展开态：按住/拖动时放大并完全不透明；停靠时收起为小圆点 */
  @State fabExpanded: boolean = false
  /** 正在拖拽（拖拽结束由 PanGesture 负责收起，避免和 onTouch 抢先后） */
  private panning: boolean = false
  @State stageW: number = 360
  @State stageH: number = 640
  private fabInit: boolean = false
  private panBaseX: number = 0
  private panBaseY: number = 0
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.pushAI('我在答疑模式，想问什么都可以。计时还在继续，安心问。')
    this.loadPriorQuestions()
  }

  /** 载入该用户最近问过的问题（跨会话记忆：换到这次专注也能接着上次聊） */
  private async loadPriorQuestions(): Promise<void> {
    try {
      const list = await StorageService.getInstance()
        .loadRecentQuestions(AppStore.getInstance().getUserId(), 3)
      const out: string[] = []
      for (const q of list) {
        out.push(q.question)
      }
      this.priorQuestions = out
    } catch (e) {
      // 读取失败不影响答疑
    }
  }

  aboutToDisappear(): void {
    this.leaveQA()
  }

  onBackPress(): boolean {
    this.leaveQA()
    router.back()
    return true
  }

  /** 离开答疑页即归还状态机，避免 qaMode 悬空导致净专注不再累积 */
  private leaveQA(): void {
    const c = FocusController.getInstance()
    if (c.isQaMode()) {
      c.endQA()
    }
  }

  /** 场景标识：让用户明确「我在专注会话里，问完就回去」，不会误以为是规划页 */
  private sceneLine(): string {
    const task = FocusController.getInstance().getCurrentTask()
    const name = task !== null ? ` · ${task.title}` : ''
    return `专注 ${TimeUtils.formatClock(this.elapsed)} · 答疑 ${TimeUtils.formatClock(this.qaElapsed)}${name}`
  }

  private pushAI(content: string): void {
    const m = new AIMessage()
    m.id = IdUtils.uuid()
    m.role = MessageRole.AI
    m.content = content
    m.timestamp = Date.now()
    this.messages.push(m)
    this.lastAiMsgId = m.id
    this.scrollToBottom()
  }

  private pushUser(content: string): void {
    const m = new AIMessage()
    m.id = IdUtils.uuid()
    m.role = MessageRole.USER
    m.content = content
    m.timestamp = Date.now()
    this.messages.push(m)
    this.scrollToBottom()
  }

  /** 新内容后滚到底部，保持「聊天跟手」（流式输出时尤其需要） */
  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 60)
  }

  private async send(): Promise<void> {
    const text = this.inputValue.trim()
    if (text.length === 0 || this.answering) {
      return
    }
    this.inputValue = ''
    this.pushUser(text)
    this.answering = true
    this.streaming = true
    this.streamingText = ''

    // 会话内历史（不含刚推入的这条用户消息），只带最近 8 条
    const all: QAMessage[] = []
    for (let i = 0; i < this.messages.length - 1; i++) {
      const m = this.messages[i]
      all.push({ role: m.role === MessageRole.USER ? 'user' : 'assistant', content: m.content })
    }
    const task = FocusController.getInstance().getCurrentTask()
    const payload: QATextPayload = { question: text, history: all.slice(-8) }
    if (task !== null) {
      payload.subject = task.title
    }
    if (this.priorQuestions.length > 0) {
      payload.recentQuestions = this.priorQuestions
    }

    let answer = ''
    let source = 'MOCK'
    try {
      answer = await AIService.getInstance()
        .answerQuestionStream(payload, AppStore.getInstance().getUserId(), (delta: string) => {
          this.streamingText += delta
          this.scrollToBottom()
        })
      source = AIService.getInstance().getLastQaSource()
    } catch (e) {
      // 必须复位，否则一次异常会让输入框永久锁死
      source = 'MOCK'
    } finally {
      this.answering = false
      this.streaming = false
    }
    if (answer.length === 0) {
      answer = this.streamingText.length > 0
        ? this.streamingText
        : '刚才没答上来，可能是网络或服务的问题。你可以再问一次，或者换个说法。'
    }
    this.streamingText = ''
    this.pushAI(answer)
    this.lastAiSource = source

    const q = new QuestionRecord()
    q.id = IdUtils.uuid()
    q.userId = AppStore.getInstance().getUserId()
    q.sessionId = FocusController.getInstance().getSession().id
    q.question = text
    q.answer = answer
    q.createdAt = Date.now()
    FocusController.getInstance().addQuestion(q)
    // 即时落库：离开答疑页也不丢（原先只在 endSession 时统一写）
    StorageService.getInstance().saveQuestion(q).catch(() => {})
  }

  private backToFocus(): void {
    this.leaveQA()
    router.back()
  }

  // ---------- 悬浮球：拖拽 + 自动吸边 ----------

  private fabSize(): number {
    return this.fabExpanded ? 66 : 48
  }

  /**
   * 吸附到最近的左/右边缘，并把纵向夹在可视区内。
   * 按**收起尺寸**对齐，这样球停在边缘时是贴边的（展开只是原地变大）。
   */
  private snapFab(): void {
    const rest = 48
    const edge = 10
    const mid = this.fabX + this.fabSize() / 2
    const targetX = mid < this.stageW / 2 ? edge : this.stageW - rest - edge
    let targetY = this.fabY
    if (targetY < 8) {
      targetY = 8
    }
    const maxY = this.stageH - rest - 8
    if (targetY > maxY) {
      targetY = maxY > 8 ? maxY : 8
    }
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.fabX = targetX
      this.fabY = targetY
    })
  }

  @Builder
  backFab() {
    Column() {
      Text('←')
        .fontSize(this.fabExpanded ? 22 : 19)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      if (this.fabExpanded) {
        Text('返回专注')
          .fontSize(11)
          .fontColor(Color.White)
          .margin({ top: 2 })
      }
    }
    .width(this.fabSize())
    .height(this.fabSize())
    .borderRadius(this.fabSize() / 2)
    .backgroundColor(Colors.PRIMARY_STRONG)
    .justifyContent(FlexAlign.Center)
    .shadow({ radius: 16, color: Colors.SHADOW, offsetX: 0, offsetY: 6 })
    // 停靠时半透明"隐身"，触碰/拖拽时完全显形
    .opacity(this.fabExpanded ? 1.0 : 0.72)
    .position({ x: this.fabX, y: this.fabY })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.fabExpanded = true
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        // 只点不拖时，PanGesture 不会触发，这里兜底把球收回停靠态
        // （拖拽结束时吸附动画约 220ms，稍等再收起，视觉更顺）
        setTimeout(() => {
          if (!this.panning) {
            this.fabExpanded = false
          }
        }, 260)
      }
    })
    .onClick(() => {
      this.backToFocus()
    })
    .gesture(
      PanGesture({ fingers: 1, distance: 4 })
        .onActionStart(() => {
          this.panning = true
          this.fabExpanded = true
          this.panBaseX = this.fabX
          this.panBaseY = this.fabY
        })
        .onActionUpdate((e: GestureEvent) => {
          this.fabX = this.panBaseX + e.offsetX
          this.fabY = this.panBaseY + e.offsetY
        })
        .onActionEnd(() => {
          this.panning = false
          this.snapFab()
          this.fabExpanded = false
        })
        .onActionCancel(() => {
          this.panning = false
          this.snapFab()
          this.fabExpanded = false
        })
    )
  }

  @Builder
  aiBubble(content: string, source: string) {
    Row() {
      Text('💡').fontSize(16)
      Column() {
        Text(content)
          .fontSize(15)
          .fontColor(Colors.TEXT_PRIMARY)
          .backgroundColor(Colors.CARD)
          .padding(12)
          .borderRadius(16)
          .constraintSize({ maxWidth: '78%' })
        // 如实标注来源：让"当前是不是真的走了大模型"一眼可见（排查用）
        if (source.length > 0) {
          Text(source === 'GATEWAY' ? '大模型回答' : '本地模板回答')
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 4, left: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 8 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  userBubble(content: string) {
    Row() {
      Text(content)
        .fontSize(15)
        .fontColor(Colors.TEXT_PRIMARY)
        .backgroundColor(Colors.PRIMARY_SOFT)
        .padding(12)
        .borderRadius(16)
        .constraintSize({ maxWidth: '78%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
  }

  @Builder
  bubble(m: AIMessage) {
    if (m.role === MessageRole.AI) {
      this.aiBubble(m.content, m.id === this.lastAiMsgId ? this.lastAiSource : '')
    } else {
      this.userBubble(m.content)
    }
  }

  build() {
    // 免责弹层与悬浮球挂在根 Stack（不参与内容 Column 的布局）
    Stack() {
      Column() {
          // 顶部：场景标识（我在专注会话里）
          Row() {
            Column() {
              Text('正在答疑')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.TEXT_PRIMARY)
              Text(this.sceneLine())
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 4 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            AITag()
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 14, bottom: 10 })
          .backgroundColor(Colors.QA_SOFT)

          Scroll(this.scroller) {
            Column({ space: Spacing.MD }) {
              ForEach(this.messages, (m: AIMessage) => {
                this.bubble(m)
              }, (m: AIMessage) => m.id)

              // 流式输出：正文实时逐段写入（不放进 messages，避免 ForEach key 不变导致不刷新）
              if (this.streaming) {
                if (this.streamingText.length > 0) {
                  this.aiBubble(this.streamingText, '')
                } else {
                  Text('小伴思考中…')
                    .fontSize(13)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .margin({ left: 24 })
                }
              }
            }
            .padding(20)
            .width('100%')
          }
          .layoutWeight(1)
          .align(Alignment.Top)

          Row({ space: 10 }) {
            TextInput({ placeholder: '输入你的问题…', text: this.inputValue })
              .fontSize(15)
              .height(44)
              .layoutWeight(1)
              .backgroundColor(Colors.CARD)
              .borderRadius(22)
              .onChange((v: string) => {
                this.inputValue = v
              })
              .onSubmit(() => {
                this.send()
              })

            // 按住说话：识别结果写回输入框，用户可以改完再发（不自动发送，留出纠错余地）
            VoiceInputButton({
              onFinal: (text: string) => {
                if (text.length > 0) {
                  this.inputValue = text
                }
              }
            })

            Button('发送')
              .height(44)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor(Colors.QA_ACCENT)
              .borderRadius(22)
              .onClick(() => {
                this.send()
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Colors.BG)

      // 返回专注：悬浮球（可拖拽、自动吸边、触碰显形）
      this.backFab()

      AIFirstDisclaimer()
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.stageW = newArea.width as number
      this.stageH = newArea.height as number
      if (!this.fabInit && this.stageW > 0) {
        this.fabInit = true
        this.fabX = this.stageW - 66 - 10
        this.fabY = this.stageH * 0.62
      }
    })
  }
}
