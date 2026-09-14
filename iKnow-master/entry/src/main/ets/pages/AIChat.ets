import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AIService } from '../services/AIService'
import { FocusController } from '../services/FocusController'
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
  @State inputValue: string = ''
  @State answering: boolean = false

  aboutToAppear(): void {
    this.pushAI('我在答疑模式，想问什么都可以。计时还在继续，安心问。')
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
    const name = task !== null ? `（当前任务「${task.title}」）` : ''
    return `本次专注 ${TimeUtils.formatClock(this.elapsed)} · 答疑 ${TimeUtils.formatClock(this.qaElapsed)} · 结束后自动回到专注${name}`
  }

  private pushAI(content: string): void {
    const m = new AIMessage()
    m.id = IdUtils.uuid()
    m.role = MessageRole.AI
    m.content = content
    m.timestamp = Date.now()
    this.messages.push(m)
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
    const answer = await AIService.getInstance().answerQuestion(text)
    this.answering = false
    this.pushAI(answer)

    const q = new QuestionRecord()
    q.id = IdUtils.uuid()
    q.sessionId = FocusController.getInstance().getSession().id
    q.question = text
    q.answer = answer
    q.createdAt = Date.now()
    FocusController.getInstance().addQuestion(q)
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
        Text(m.content)
          .fontSize(15)
          .fontColor(Colors.TEXT_PRIMARY)
          .backgroundColor(Colors.CARD)
          .padding(12)
          .borderRadius(16)
          .constraintSize({ maxWidth: '78%' })
          .margin({ left: 8 })
      }
      .width('100%')
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

      Button('← 回到专注（继续计时）')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(Colors.QA_ACCENT)
        .borderRadius(Radius.MD)
        .margin({ left: 20, right: 20, bottom: 8 })
        .onClick(() => {
          this.backToFocus()
        })

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
    AIFirstDisclaimer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
