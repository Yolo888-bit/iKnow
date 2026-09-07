import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { AIService } from '../services/AIService'
import { AIMessage } from '../models/AIMessage'
import { Task } from '../models/Task'
import { MessageRole, TaskStatus } from '../models/Enums'
import { IdUtils } from '../utils/IdUtils'
import { AITag } from '../components/AITag'

/** AI 对话式任务规划 */
@Entry
@Component
export struct TaskPlanning {
  @State messages: AIMessage[] = []
  @State plan: Task[] = []
  @State step: number = 0
  @State goalText: string = ''
  @State inputValue: string = ''
  @State planning: boolean = false

  aboutToAppear(): void {
    this.pushAI(AIService.getInstance().openPlanning())
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
    if (text.length === 0) {
      return
    }
    this.inputValue = ''
    this.pushUser(text)

    if (this.step === 0) {
      this.goalText = text
      this.step = 1
      this.pushAI(AIService.getInstance().nextPlanningQuestion(0))
    } else {
      this.step = 2
      this.pushAI('好的，我帮你安排一下。')
      this.planning = true
      const tasks = await AppStore.getInstance().planTasks(this.goalText)
      this.plan = tasks
      this.planning = false
      this.pushAI(`我帮你拆成了 ${tasks.length} 个小任务，你可以勾选、删除或添加，确认后再开始。`)
    }
  }

  private toggle(id: string): void {
    const next: Task[] = []
    for (const t of this.plan) {
      const c = t.copy()
      if (c.id === id) {
        c.done = !c.done
        c.status = c.done ? TaskStatus.DONE : TaskStatus.TODO
      }
      next.push(c)
    }
    this.plan = next
  }

  private removeTask(id: string): void {
    const next: Task[] = []
    for (const t of this.plan) {
      if (t.id !== id) {
        next.push(t)
      }
    }
    this.plan = next
  }

  private addTask(): void {
    const t = new Task()
    t.id = IdUtils.uuid()
    t.title = '新任务'
    t.subject = '综合'
    t.estimatedDuration = 25
    t.sortOrder = this.plan.length
    t.createdAt = Date.now()
    this.plan.push(t)
  }

  private confirm(): void {
    AppStore.getInstance().setCurrentPlan(this.plan)
    router.replaceUrl({ url: 'pages/Focus' })
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
      // 顶部标题
      Row() {
        Text('AI 任务规划')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
        Blank()
        AITag()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      // 对话 + 计划
      Scroll() {
        Column({ space: Spacing.MD }) {
          ForEach(this.messages, (m: AIMessage) => {
            this.bubble(m)
          }, (m: AIMessage) => m.id)

          if (this.planning) {
            Text('小伴思考中…')
              .fontSize(13)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ left: 24 })
          }

          if (this.plan.length > 0) {
            Column() {
              Text('今日学习计划')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.TEXT_PRIMARY)
                .width('100%')
                .margin({ top: 8, bottom: 12 })

              ForEach(this.plan, (task: Task) => {
                Row() {
                  Checkbox()
                    .select(task.done)
                    .selectedColor(Colors.PRIMARY)
                    .width(22)
                    .height(22)
                    .onChange((val: boolean) => {
                      this.toggle(task.id)
                    })
                  Column() {
                    Text(task.title)
                      .fontSize(15)
                      .fontColor(task.done ? Colors.TEXT_TERTIARY : Colors.TEXT_PRIMARY)
                    Text(`${task.subject} · ${task.estimatedDuration} min`)
                      .fontSize(12)
                      .fontColor(Colors.TEXT_SECONDARY)
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 12 })
                  .layoutWeight(1)

                  Text('×')
                    .fontSize(20)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .padding(6)
                    .onClick(() => {
                      this.removeTask(task.id)
                    })
                }
                .width('100%')
                .padding(14)
                .backgroundColor(Colors.CARD)
                .borderRadius(Radius.MD)
              }, (task: Task) => task.id)

              Row() {
                Text('+ 添加任务')
                  .fontSize(14)
                  .fontColor(Colors.PRIMARY_DARK)
                  .onClick(() => {
                    this.addTask()
                  })
                Blank()
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })

              Button('确认计划并开始专注')
                .width('100%')
                .height(50)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .backgroundColor(Colors.PRIMARY)
                .borderRadius(Radius.LG)
                .margin({ top: 8 })
                .onClick(() => {
                  this.confirm()
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Colors.BG)
            .borderRadius(Radius.LG)
          }
        }
        .padding(20)
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      // 输入栏
      Row() {
        TextInput({ placeholder: '说说你今天想学什么…' })
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
      .padding({ left: 16, right: 16, top: 10, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
