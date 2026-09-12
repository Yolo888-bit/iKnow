import { router } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { AuthService } from '../services/AuthService'

/** 登录 / 注册（本地账号）—— 应用入口，未登录不进入主界面 */
@Entry
@Component
struct Login {
  @State username: string = ''
  @State password: string = ''
  @State errorMsg: string = ''
  @State loading: boolean = false

  aboutToAppear(): void {
    // 已登录（如热重载/回退到本页）直接进入主界面
    AuthService.getInstance().isLoggedIn().then((logged: boolean) => {
      if (logged) {
        router.replaceUrl({ url: 'pages/Index' })
      }
    })
  }

  private async doLogin(): Promise<void> {
    if (this.loading) {
      return
    }
    this.errorMsg = ''
    this.loading = true
    const r = await AuthService.getInstance().login(this.username, this.password)
    if (!r.ok) {
      this.errorMsg = r.message
      this.loading = false
      return
    }
    // 登录用户名写入用户昵称，App 全局生效
    await AppStore.getInstance().applyLoginUser(r.username)
    this.loading = false
    router.replaceUrl({ url: 'pages/Index' })
  }

  build() {
    Column() {
      // 品牌区
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

      // 登录卡片
      Column() {
        Text('登录 / 注册')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

        TextInput({ placeholder: '用户名' })
          .fontSize(15)
          .height(48)
          .margin({ top: 18 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.username = v
          })

        TextInput({ placeholder: '密码（至少 6 位）' })
          .type(InputType.Password)
          .fontSize(15)
          .height(48)
          .margin({ top: 12 })
          .backgroundColor(Colors.BG)
          .borderRadius(Radius.MD)
          .onChange((v: string) => {
            this.password = v
          })

        if (this.errorMsg.length > 0) {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor(Colors.CAMERA_RED)
            .width('100%')
            .margin({ top: 10 })
        }

        Button(this.loading ? '登录中…' : '登录')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Colors.PRIMARY)
          .borderRadius(Radius.LG)
          .margin({ top: 20 })
          .enabled(!this.loading)
          .onClick(() => {
            this.doLogin()
          })

        Text('首次使用该用户名会自动创建本地账号')
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

      Text('登录后，应用内的称呼将使用你的用户名')
        .fontSize(12)
        .fontColor(Colors.TEXT_TERTIARY)
        .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .padding(28)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Colors.BG)
  }
}
