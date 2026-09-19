import { router } from '@kit.ArkUI'
import { Colors, Radius } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { AuthService } from '../services/AuthService'

/**
 * 登录 / 注册（账号 + 密码）
 *
 *  - 「登录」「注册」分成两个页签：**首次使用默认停在「注册」**，先建号再登录。
 *  - 密码框用系统标准样式（`InputType.Password` 自带显示/隐藏小眼睛），不再自造图标。
 *  - 注册需二次确认密码；密码本地 djb2 散列，不落明文、不上传。
 */
@Entry
@Component
struct Login {
  /** 0 = 登录，1 = 注册 */
  @State mode: number = 1
  @State username: string = ''
  @State password: string = ''
  @State confirm: string = ''
  @State errorMsg: string = ''
  @State saving: boolean = false

  aboutToAppear(): void {
    const n = AppStore.getInstance().getUser().nickname
    if (n.length > 0) {
      this.username = n
    }
    // 本机已有账号 → 默认显示登录；没有账号 → 默认显示注册
    AuthService.getInstance().hasAccount().then((has: boolean) => {
      this.mode = has ? 0 : 1
    })
  }

  private switchMode(m: number): void {
    if (this.mode === m) {
      return
    }
    this.mode = m
    this.errorMsg = ''
    this.password = ''
    this.confirm = ''
  }

  private async submit(): Promise<void> {
    if (this.saving) {
      return
    }
    this.errorMsg = ''
    this.saving = true

    const auth = AuthService.getInstance()
    const r = this.mode === 1
      ? await auth.register(this.username, this.password, this.confirm)
      : await auth.login(this.username, this.password)

    if (!r.ok) {
      this.saving = false
      this.errorMsg = r.message
      return
    }
    // 用户名全局生效（首页 / 工作台 / 我的 都会显示它）
    await AppStore.getInstance().applyLoginUser(r.username)

    this.saving = false
    // 没走过目标引导 → 先让用户选目标 + 日期，再进主界面
    const configured = await AppStore.getInstance().isGoalConfigured()
    if (configured) {
      router.replaceUrl({ url: 'pages/Index' })
    } else {
      router.replaceUrl({ url: 'pages/GoalSetup' })
    }
  }

  @Builder
  modeTab(text: string, m: number) {
    Column() {
      Text(text)
        .fontSize(15)
        .fontWeight(this.mode === m ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.mode === m ? Colors.PRIMARY_DARK : Colors.TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .height(38)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.mode === m ? Colors.CARD : Color.Transparent)
    .borderRadius(19)
    .onClick(() => {
      this.switchMode(m)
    })
  }

  @Builder
  fieldLabel(text: string, topMargin: number) {
    Text(text)
      .fontSize(13)
      .fontColor(Colors.TEXT_SECONDARY)
      .width('100%')
      .margin({ top: topMargin })
  }

  build() {
    Scroll() {
      Column() {
        // 品牌区
        Column() {
          Text('iKnow')
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.PRIMARY_DARK)
            .fontStyle(FontStyle.Italic)
          Text('专注感知智能考伴')
            .fontSize(14)
            .fontColor(Colors.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 64, bottom: 28 })

        // 登录 / 注册 卡片
        Column() {
          // 页签
          Row() {
            this.modeTab('登录', 0)
            this.modeTab('注册', 1)
          }
          .width('100%')
          .padding(4)
          .backgroundColor(Colors.BG_ALT)
          .borderRadius(23)
          .margin({ bottom: 22 })

          this.fieldLabel('用户名', 0)
          TextInput({ placeholder: '请输入用户名', text: this.username })
            .fontSize(15)
            .height(48)
            .margin({ top: 8 })
            .backgroundColor(Colors.BG)
            .borderRadius(Radius.MD)
            .maxLength(20)
            .onChange((v: string) => {
              this.username = v
            })

          this.fieldLabel('密码', 16)
          TextInput({ placeholder: '至少 6 位', text: this.password })
            .fontSize(15)
            .height(48)
            .margin({ top: 8 })
            .backgroundColor(Colors.BG)
            .borderRadius(Radius.MD)
            .maxLength(32)
            .type(InputType.Password)
            .onChange((v: string) => {
              this.password = v
            })

          if (this.mode === 1) {
            this.fieldLabel('确认密码', 16)
            TextInput({ placeholder: '再输入一次密码', text: this.confirm })
              .fontSize(15)
              .height(48)
              .margin({ top: 8 })
              .backgroundColor(Colors.BG)
              .borderRadius(Radius.MD)
              .maxLength(32)
              .type(InputType.Password)
              .onChange((v: string) => {
                this.confirm = v
              })
              .onSubmit(() => {
                this.submit()
              })
          } else {
            Text('')
              .height(0)
          }

          if (this.errorMsg.length > 0) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor(Colors.RED)
              .width('100%')
              .margin({ top: 14 })
          }

          Button(this.saving
            ? (this.mode === 1 ? '正在创建…' : '正在登录…')
            : (this.mode === 1 ? '创建账号' : '登录'))
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY_STRONG)
            .borderRadius(Radius.LG)
            .margin({ top: 24 })
            .enabled(!this.saving)
            .onClick(() => {
              this.submit()
            })

          Text(this.mode === 1
            ? '注册后账号只保存在本机，学习数据不会上传'
            : '还没有账号？切换到「注册」创建一个')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 16 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor(Colors.CARD)
        .borderRadius(Radius.XL)
        .shadow({ radius: 24, color: Colors.SHADOW, offsetX: 0, offsetY: 8 })

        Blank().height(40)
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
