import { Colors, Radius, Spacing } from '../common/Theme'
import { AIService } from '../services/AIService'
import { AIMessage } from '../models/AIMessage'
import { MessageRole } from '../models/Enums'
import { IdUtils } from '../utils/IdUtils'
import { AITag } from '../components/AITag'
import { AIFirstDisclaimer } from '../components/AIFirstDisclaimer'

/** AI 考伴 —— 长期关系建立页 */
@Entry
@Component
export struct AICompanion {
  @State messages: AIMessage[] = []
  @State inputValue: string = ''
  @State answering: boolean = false
  private quickPrompts: string[] = ['帮我规划今天的学习', '我今天状态不好', '为什么我最近总是容易分心？', '帮我调整下周学习计划']

  aboutToAppear(): void {
    this.pushAI(AIService.getInstance().companionIntro())
  }

  private pushAI(content: string): void {
    const m = new AIMessage()
    m.id = IdUtils.uuid()
    m.role = MessageRole.AI
    m.content = content
    m.timestamp = Date.now()
    this.messages.push(m)
  }

  private async send(text?: string): Promise<void> {
    const content = text !== undefined ? text : this.inputValue.trim()
    if (content.length === 0 || this.answering) {
      return
    }
    this.inputValue = ''
    const um = new AIMessage()
    um.id = IdUtils.uuid()
    um.role = MessageRole.USER
    um.content = content
    um.timestamp = Date.now()
    this.messages.push(um)

    this.answering = true
    const reply = await AIService.getInstance().chat(content)
    this.answering = false
    this.pushAI(reply)
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
      Row() {
        Text('AI 考伴')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        AITag()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 10 })

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

          // 快捷提问
          Column() {
            Text('可以试试问我').fontSize(12).fontColor(Colors.TEXT_TERTIARY).width('100%')
            ForEach(this.quickPrompts, (p: string) => {
              Text(p)
                .fontSize(13)
                .fontColor(Colors.PRIMARY_DARK)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor(Colors.PRIMARY_SOFT)
                .borderRadius(16)
                .margin({ right: 8, top: 8 })
                .onClick(() => {
                  this.send(p)
                })
            }, (p: string) => p)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 16 })
        }
        .padding(20)
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      Row() {
        TextInput({ placeholder: '和小伴说点什么…' })
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
          .backgroundColor(Colors.PRIMARY)
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
