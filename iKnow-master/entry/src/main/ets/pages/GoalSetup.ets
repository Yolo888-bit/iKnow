import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { LearningGoal } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'

/** 目标类型 */
interface GoalType {
  key: string
  emoji: string
  label: string
  /** 该目标的激励标语（离线兜底，AI 可用时会覆盖） */
  slogan: string
}

/**
 * 目标设置页（登录后引导）
 *
 *  - 选目标类型（考公 / 考研 / 高考 / 期末 / 其他）+ 目标日期（年月日）。
 *  - 保存后工作台「目标总览」按目标日期实时算剩余天数。
 */
@Entry
@Component
struct GoalSetup {
  @State typeIndex: number = -1
  @State customName: string = ''
  @State targetDate: Date = new Date(Date.now() + 180 * 24 * 3600 * 1000)
  @State saving: boolean = false
  @State errorMsg: string = ''
  private types: GoalType[] = [
    { key: '公务员考试', emoji: '🏛️', label: '公务员考试', slogan: '下一站，上岸' },
    { key: '研究生考试', emoji: '📚', label: '研究生考试', slogan: '一路生花' },
    { key: '高考冲刺', emoji: '✏️', label: '高考冲刺', slogan: '星光不负赶路人' },
    { key: '期末复习', emoji: '📝', label: '期末复习', slogan: '稳扎稳打，门门过关' },
    { key: '其他', emoji: '🎯', label: '其他', slogan: '定个目标，稳步推进' }
  ]

  aboutToAppear(): void {
    // 老用户（或改过目标）进来时，把已有目标回填，避免重复选一遍
    const g = AppStore.getInstance().getGoal()
    if (g.examType.length > 0) {
      for (let i = 0; i < this.types.length; i++) {
        if (this.types[i].key === g.examType) {
          this.typeIndex = i
          break
        }
      }
      if (this.typeIndex < 0) {
        // 不在预设里（自定义目标）→ 落到「其他」并带回原名
        this.typeIndex = this.types.length - 1
        this.customName = g.examType
      }
    }
    if (g.targetDate > 0) {
      this.targetDate = new Date(g.targetDate)
    }
  }

  private selectedLabel(): string {
    if (this.typeIndex < 0) {
      return ''
    }
    const t = this.types[this.typeIndex]
    if (t.key === '其他') {
      return this.customName.trim()
    }
    return t.label
  }

  private daysLeft(): number {
    return TimeUtils.daysUntil(this.targetDate.getTime(), Date.now())
  }

  private dateText(): string {
    const d = this.targetDate
    return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日`
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return
    }
    if (this.typeIndex < 0) {
      this.errorMsg = '请选择你的目标类型'
      return
    }
    if (this.types[this.typeIndex].key === '其他' && this.customName.trim().length === 0) {
      this.errorMsg = '给这个目标起个名字吧'
      return
    }
    if (this.daysLeft() < 0) {
      this.errorMsg = '目标日期不能早于今天'
      return
    }
    this.errorMsg = ''
    this.saving = true

    const store = AppStore.getInstance()
    const goal = new LearningGoal()
    const old = store.getGoal()
    goal.id = old.id.length > 0 ? old.id : `goal_${Date.now()}`
    goal.examType = this.types[this.typeIndex].key === '其他'
      ? this.customName.trim()
      : this.types[this.typeIndex].label
    goal.title = this.types[this.typeIndex].slogan
    goal.targetDate = this.targetDate.getTime()
    goal.subjects = old.subjects

    await store.saveGoal(goal)
    // 打标「已走过目标引导」，之后启动/登录直接进主界面
    await store.markGoalConfigured()
    // 目标变了，AI 标语需要重新生成
    AppStorage.setOrCreate<string>(StorageKey.GOAL_SLOGAN, '')

    this.saving = false
    router.replaceUrl({ url: 'pages/Index' })
  }

  @Builder
  typeCard(t: GoalType, index: number) {
    Row() {
      Text(t.emoji)
        .fontSize(20)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.typeIndex === index ? Colors.CARD : Colors.BG)
        .borderRadius(20)
      Column() {
        Text(t.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
        Text(t.slogan)
          .fontSize(12)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      if (this.typeIndex === index) {
        Text('✓')
          .fontSize(17)
          .fontColor(Colors.PRIMARY_DARK)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.typeIndex === index ? Colors.PRIMARY_SOFT : Colors.BG)
    .borderRadius(Radius.MD)
    .border({
      width: this.typeIndex === index ? 1.5 : 0,
      color: Colors.PRIMARY
    })
    .onClick(() => {
      this.typeIndex = index
      this.errorMsg = ''
    })
  }

  build() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        // 标题
        Column() {
          Text('设置你的目标')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text('我会按你的目标和剩余天数，帮你安排每天的学习节奏')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 8 })
            .width('100%')
        }
        .width('100%')
        .padding({ top: 24, bottom: 4 })

        // 目标类型
        Column() {
          Row() {
            Text('① 目标类型')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text('单选')
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
          }
          .width('100%')
          .margin({ bottom: 14 })

          Column({ space: Spacing.SM }) {
            ForEach(this.types, (t: GoalType, i: number) => {
              this.typeCard(t, i)
            }, (t: GoalType) => t.key)
          }
          .width('100%')

          if (this.typeIndex >= 0 && this.types[this.typeIndex].key === '其他') {
            TextInput({ placeholder: '给这个目标起个名字（如：雅思 7 分）', text: this.customName })
              .fontSize(15)
              .height(48)
              .margin({ top: 12 })
              .backgroundColor(Colors.BG)
              .borderRadius(Radius.MD)
              .onChange((v: string) => {
                this.customName = v
              })
          }
        }
        .gCard()

        // 目标日期
        Column() {
          Row() {
            Text('② 目标日期')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text(this.daysLeft() >= 0 ? `还剩 ${this.daysLeft()} 天` : '日期无效')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.daysLeft() >= 0 ? Colors.PRIMARY_DARK : Colors.RED)
          }
          .width('100%')
          .margin({ bottom: 6 })

          Text(this.dateText())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 6 })

          DatePicker({
            start: new Date(2020, 0, 1),
            end: new Date(2035, 11, 31),
            selected: this.targetDate
          })
            .height(160)
            .onDateChange((value: Date) => {
              this.targetDate = value
              this.errorMsg = ''
            })
        }
        .gCard()

        if (this.errorMsg.length > 0) {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor(Colors.RED)
            .width('100%')
            .padding({ left: 4 })
        }

        Button(this.saving ? '正在保存…' : '开始我的备考')
          .width('100%')
          .height(52)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Colors.PRIMARY_STRONG)
          .borderRadius(Radius.LG)
          .enabled(!this.saving)
          .onClick(() => {
            this.save()
          })

        Text('目标之后可以随时在「我的 → 长期计划与目标」修改')
          .fontSize(12)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)

        Blank().height(30)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}

@Extend(Column)
function gCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
  .shadow({ radius: 18, color: Colors.SHADOW, offsetX: 0, offsetY: 6 })
}
