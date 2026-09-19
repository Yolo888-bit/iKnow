import { router } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { AppStore } from '../store/AppStore'

/**
 * 首次使用引导（无账号体系）
 *
 * 竞赛 Demo 取舍：本地体验模式，不做注册/登录，只需要一个称呼。
 * 目标考试 / 日期 / 长期计划统一在「我的 → 长期计划与目标」配置
 * （此前在引导页与长期计划页各写一份，语义重复且入口分散）。
 * 引导只在首次启动（尚无称呼）时出现。
 */
@Entry
@Component
struct Login {
  @State nickname: string = ''
  @State errorMsg: string = ''
  @State saving: boolean = false

  aboutToAppear(): void {
    const u = AppStore.getInstance().getUser()
    if (u.nickname.length > 0) {
      this.nickname = u.nickname
    }
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

        Text('不需要注册账号，学习记录存在本机')
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

        Text('目标考试、日期与长期计划，之后在「我的 → 长期计划与目标」里设置')
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
