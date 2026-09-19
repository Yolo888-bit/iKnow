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
  /** 最后一条 AI 消息与其来源，用于如实标注「大模型回答 / 本地模板回答」 */
  @State lastAiMsgId: string = ''
  @State lastAiSource: string = ''

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
  }

  private pushUser(content: string): void {
    const m = new AIMessage()
    m.id = IdUtils.uuid()
    m.role = MessageRole.USER
    m.content = content
    m.timestamp = Date.now()
    this.messages.push(m)
  }

  private async send(): Promise<void> {
    const text = this.inputValue.trim()
    if (text.length === 0 || this.answering) {
      return
    }
    this.inputValue = ''
    this.pushUser(text)
    this.answering = true

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
        .answerQuestion(payload, AppStore.getInstance().getUserId())
      source = AIService.getInstance().getLastQaSource()
    } catch (e) {
      answer = '刚才没答上来，可能是网络或服务的问题。你可以再问一次，或者换个说法。'
      source = 'MOCK'
    } finally {
      // 必须复位，否则一次异常会让输入框永久锁死
      this.answering = false
    }
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

  @Builder
  bubble(m: AIMessage) {
    if (m.role === MessageRole.AI) {
      Row() {
        Text('💡').fontSize(16)
        Column() {
          Text(m.content)
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .backgroundColor(Colors.CARD)
            .padding(12)
            .borderRadius(16)
            .constraintSize({ maxWidth: '78%' })
          // 如实标注来源：让"当前是不是真的走了大模型"一眼可见（排查用）
          if (m.id === this.lastAiMsgId && this.lastAiSource.length > 0) {
            Text(this.lastAiSource === 'GATEWAY' ? '大模型回答' : '本地模板回答')
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
    } else {
      Row() {
        Text(m.content)
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
  }

  build() {
    // 免责弹层挂在根 Stack（不参与内容 Column 的布局）
    Stack() {
      Column() {
      // 顶部：场景标识（我在专注会话里）+ 返回
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

      Scroll() {
        Column({ space: Spacing.MD }) {
          ForEach(this.messages, (m: AIMessage) => {
            this.bubble(m)
          }, (m: AIMessage) => m.id)

          if (this.answering) {
            Text('小伴思考中…')
              .fontSize(13)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ left: 24 })
          }
        }
        .padding(20)
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      // 左右缩进统一用外层 padding（width('100%') 与 margin 叠加会溢出）
      Row() {
        Button('← 回到专注（继续计时）')
          .width('100%')
          .height(44)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(Colors.QA_ACCENT)
          .borderRadius(Radius.MD)
          .onClick(() => {
            this.backToFocus()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Row() {
        TextInput({ placeholder: '输入你的问题…' })
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

        Button('发送')
          .height(44)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(Colors.QA_ACCENT)
          .borderRadius(22)
          .margin({ left: 10 })
          .onClick(() => {
            this.send()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Colors.BG)

      AIFirstDisclaimer()
    }
    .width('100%')
    .height('100%')
  }
}
