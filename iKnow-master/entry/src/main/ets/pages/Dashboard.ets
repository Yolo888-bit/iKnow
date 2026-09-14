import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { TimeUtils } from '../utils/TimeUtils'
import { BarChart } from '../components/BarChart'
import { FocusController } from '../services/FocusController'
import { SubjectProgress } from '../models/Dashboard'
import { UserAvatar } from '../components/UserAvatar'
import { AvatarPicker } from '../components/AvatarPicker'

/** 我的工作台 —— 学习全局看板 */
@Component
export struct Dashboard {
  @StorageProp(StorageKey.EXAM_DAYS) examDays: number = 0
  @StorageProp(StorageKey.USER_NICKNAME) nickname: string = ''
  @StorageProp(StorageKey.USER_AVATAR) avatar: string = '🧑‍🎓'
  @StorageProp(StorageKey.TODAY_DONE_TASKS) todayDone: number = 0
  @StorageProp(StorageKey.TODAY_TOTAL_TASKS) todayTotal: number = 0
  @StorageProp(StorageKey.WEEK_FOCUS_SEC) weekFocus: number = 0
  @StorageProp(StorageKey.FOCUS_RATE) focusRate: number = 0
  @StorageProp(StorageKey.DATA_VERSION) @Watch('refresh') dataVersion: number = 0
  @StorageProp(StorageKey.FOCUS_ELAPSED) focusElapsed: number = 0
  @State weekTrend: number[] = []
  @State subjects: SubjectProgress[] = []
  @State examType: string = ''
  @State greeting: string = ''
  @State showAvatarSheet: boolean = false
  private weekLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']

  aboutToAppear(): void {
    this.refresh()
  }

  /** 顶部问候语（按当前时间）+ 登录用户名 */
  private displayName(): string {
    const n = this.nickname.length > 0 ? this.nickname : AppStore.getInstance().getUser().nickname
    return n.length > 0 ? n : '同学'
  }

  refresh(): void {
    this.greeting = TimeUtils.greeting(Date.now())
    const store = AppStore.getInstance()
    const d = store.getDashboard()
    this.weekTrend = d.weekTrend
    this.subjects = d.subjectProgress
    this.examType = store.getGoal().examType
  }

  /** 有会话在跑（含被返回键留在后台的）时，首页给出继续入口 */
  private focusRunning(): boolean {
    return FocusController.getInstance().isRunning()
  }

  private resumeFocus(): void {
    router.pushUrl({ url: 'pages/Focus' })
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.TEXT_PRIMARY)
      .width('100%')
      .margin({ bottom: 12 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: Spacing.LG }) {
        // 顶部问候（按当前时间生成 + 登录用户名）+ 右上角头像
        Row() {
          Column() {
            Text(`${this.greeting}，${this.displayName()}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
            Text('今天也一起稳稳推进吧')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 6 })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 右上角头像：点击即可更换
          Column() {
            UserAvatar({ avatar: this.avatar, diameter: 52, bg: Colors.PRIMARY_SOFT })
          }
          .onClick(() => {
            this.showAvatarSheet = true
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 专注进行中：返回键留在后台的会话不丢，从这里继续（E4）
        if (this.focusRunning()) {
          Row() {
            Text(`专注进行中 · ${TimeUtils.formatClock(this.focusElapsed)}`)
              .fontSize(14)
              .fontColor(Colors.TEXT_PRIMARY)
              .layoutWeight(1)
            Button('继续专注')
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor(Colors.PRIMARY)
              .height(34)
              .borderRadius(17)
              .onClick(() => {
                this.resumeFocus()
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Colors.PRIMARY_SOFT)
          .borderRadius(Radius.MD)
        }

        // 考试总览
        Column() {
          Text('考试总览')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .width('100%')
          if (this.examType.length === 0) {
            Text('还没设置目标考试')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 6 })
              .width('100%')
            Text('在「我的 → 重新设置称呼与目标」里填写，倒计时才会准确')
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ top: 10 })
              .width('100%')
          } else {
            Row() {
              Column() {
                Text(this.examType)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Colors.PRIMARY_DARK)
                  .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Column() {
                Text(`${this.examDays}`)
                  .fontSize(34)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Colors.TEXT_PRIMARY)
                Text('天')
                  .fontSize(12)
                  .fontColor(Colors.TEXT_SECONDARY)
              }
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .margin({ top: 6 })
            Text(`距离 ${this.examType} 还有 ${this.examDays} 天，按节奏稳步推进`)
              .fontSize(12)
              .fontColor(Colors.TEXT_TERTIARY)
              .margin({ top: 10 })
              .width('100%')
          }
        }
        .dashCard()

        // 总体进度
        Column() {
          this.sectionTitle('总体进度')
          Row() {
            Text(`${this.todayDone} / ${this.todayTotal}`)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Text(this.todayTotal > 0 ? `${Math.round(this.todayDone / this.todayTotal * 100)}%` : '—')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.PRIMARY_DARK)
          }
          .width('100%')
          .margin({ bottom: 10 })
          Progress({
            value: this.todayDone,
            total: Math.max(1, this.todayTotal),
            type: ProgressType.Linear
          })
            .color(Colors.PRIMARY)
            .backgroundColor(Colors.LINE)
            .width('100%')
          Text('今日任务完成进度')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .margin({ top: 8 })
            .width('100%')
        }
        .dashCard()

        // 科目进度
        Column() {
          this.sectionTitle('科目进度')
          if (this.subjects.length === 0) {
            Text('开始学习后，这里会显示各学科的完成进度')
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

        // 长期趋势
        Column() {
          this.sectionTitle('长期趋势')
          Text('近 7 天净专注时长（分钟）')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .margin({ bottom: 10 })
          BarChart({ values: this.weekTrend, labels: this.weekLabels })
            .width('100%')
          Text(`本周累计净专注 ${TimeUtils.formatHMin(this.weekFocus)}`)
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 10 })
            .width('100%')
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

      // 头像选择器（右上角头像点击后弹出）
      AvatarPicker({
        show: this.showAvatarSheet,
        onClose: () => {
          this.showAvatarSheet = false
        }
      })
    }
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
