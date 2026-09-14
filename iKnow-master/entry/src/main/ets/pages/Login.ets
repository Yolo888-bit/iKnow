import { router } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { AppStore } from '../store/AppStore'

/**
 * 首次使用引导（无账号体系）
 *
 * 竞赛 Demo 取舍：本地体验模式，不做注册/登录。只需填一个称呼；
 * 目标考试与日期可留空（稍后可在「我的」或工作台再设）。
 * 引导只在首次启动（尚无称呼）时出现。
 */
@Entry
@Component
struct Login {
  @State nickname: string = ''
  @State examType: string = ''
  @State dateText: string = ''
  @State errorMsg: string = ''
  @State saving: boolean = false

  aboutToAppear(): void {
    const store = AppStore.getInstance()
    const u = store.getUser()
    if (u.nickname.length > 0) {
      this.nickname = u.nickname
    }
    const g = store.getGoal()
    if (g.examType.length > 0) {
      this.examType = g.examType
    }
    if (g.targetDate > 0) {
      const d = new Date(g.targetDate)
      this.dateText = `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}`
    }
  }

  private pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`
  }

  /** 解析 YYYY-MM-DD；不合法或留空返回 0（= 不设置） */
  private parseDate(text: string): number {
    const parts = text.split('-')
    if (parts.length !== 3) {
      return 0
    }
    const y = Number(parts[0])
    const m = Number(parts[1])
    const d = Number(parts[2])
    if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d) || y < 2000 || m < 1 || m > 12 || d < 1 || d > 31) {
      return 0
    }
    return new Date(y, m - 1, d, 0, 0, 0, 0).getTime()
  }

  private async start(): Promise<void> {
    if (this.saving) {
      return
    }
    const name = this.nickname.trim()
    if (name.length === 0) {
      this.errorMsg = '先填一个称呼吧，App 里会用这个名字称呼你'
      return
    }
    this.errorMsg = ''
    this.saving = true

    await AppStore.getInstance().applyLoginUser(name)

    const exam = this.examType.trim()
    const target = this.parseDate(this.dateText.trim())
    if (exam.length > 0 || target > 0) {
      const g = AppStore.getInstance().getGoal()
      if (exam.length > 0) {
        g.examType = exam
        if (g.title.length === 0) {
          g.title = exam
        }
      }
      if (target > 0) {
        g.targetDate = target
      }
      await AppStore.getInstance().saveGoal(g)
    }

    this.saving = false
    router.replaceUrl({ url: 'pages/Index' })
  }

  build() {
    Column() {
      Column() {
        Text('iKnow')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.PRIMARY)
        Text('专注感知智能考伴')
          .fontSize(14)
          .fontColor(Colors.TEXT_SECONDARY)
          .margin({ top: 8 })
      }
      .margin({ bottom: 36 })

      Column() {
        Text('开始使用')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

        Text('不需要注册账号，数据只存在本机')
          .fontSize(12)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .margin({ top: 6 })

        TextInput({ placeholder: '怎么称呼你？（必填）', text: this.nickname })
          .fontSize(15)
          .height(48)
          .margin({ top: 18 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.nickname = v
          })

        TextInput({ placeholder: '目标考试，如 考研 / 期末（可跳过）', text: this.examType })
          .fontSize(15)
          .height(48)
          .margin({ top: 12 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.examType = v
          })

        TextInput({ placeholder: '考试日期，如 2026-12-20（可跳过）', text: this.dateText })
          .fontSize(15)
          .height(48)
          .margin({ top: 12 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.dateText = v
          })

        if (this.errorMsg.length > 0) {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor(Colors.CAMERA_RED)
            .width('100%')
            .margin({ top: 10 })
        }

        Button(this.saving ? '正在保存…' : '开始使用')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Colors.PRIMARY)
          .borderRadius(Radius.LG)
          .margin({ top: 20 })
          .enabled(!this.saving)
          .onClick(() => {
            this.start()
          })

        Text('目标考试与日期可以留空，之后在「我的」里再设')
          .fontSize(12)
          .fontColor(Colors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 14 })
      }
      .width('100%')
      .padding(24)
      .backgroundColor(Colors.CARD)
      .borderRadius(Radius.LG)
    }
    .width('100%')
    .height('100%')
    .padding(28)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Colors.BG)
  }
}
