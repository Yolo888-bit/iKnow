import { router } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { PrivacyDoc } from '../common/Constants'

/**
 * 隐私保护说明（《用户服务协议》+《隐私政策》）
 *
 * 两个入口：
 *  1. **登录 / 注册页**的勾选项 —— 用户必须先读这份文档并勾选同意，才能建号或登录
 *     （门禁在 `pages/Login` + `AuthService`，本页只负责"说清楚"）；
 *  2. 「我的 → 隐私」与「关于」页 —— 已登录用户随时可以回来查看。
 *
 * 写作原则（重要）：
 *  - **必须与实现一致**。本项目会抓拍画面短片段上传云端识别、会把学习上下文发给大模型服务商、
 *    账号与数据都存在本机 —— 这些都要如实写，不能写成"完全不联网、不保存"；
 *  - 先用「要点速览」讲人话，再给正式条文，避免通篇法律腔导致没人读；
 *  - 文档**版本号在 `PrivacyDoc.VERSION`**，内容改版要一起升版本，
 *    否则老用户的"已同意"不会失效、登录时不会重新征求同意。
 */

/** 文档的一节：小标题 + 若干条正文（条目前的「·」由文案自带，渲染层不做解析） */
class DocSection {
  title: string = ''
  lines: string[] = []

  constructor(title: string, lines: string[]) {
    this.title = title
    this.lines = lines
  }
}

/**
 * 要点速览：先用最直白的话讲清"数据去了哪"。
 * 用户点开文档多半只想确认这几件事，不该让人在条文里找。
 */
const HIGHLIGHTS: string[] = [
  '账号与学习数据都保存在这台设备上，不上传、也不跨设备同步',
  '摄像头只在感知触发时抓拍 2~3 秒短片段，不做持续录像；选「仅计时」则完全不抓拍',
  '画面短片段会上传到云端做「你在做什么」的识别，云端只回状态，不做注意力推断',
  'AI 规划 / 答疑 / 复盘会把必要的学习上下文发给大模型服务商，不发送无关信息',
  '每一项数据都能在「我的 → 隐私」里单独清除，或一次性全部清除'
]

/** 《用户服务协议》各节 */
const AGREEMENT_SECTIONS: DocSection[] = [
  new DocSection('一、服务内容', [
    'iKnow 是一款「专注感知 + AI 陪伴」的学习应用，提供今日任务规划、专注计时与状态感知、AI 答疑、单次与长期学习复盘、桌面服务卡片等功能。',
    '「小伴」是 AI 智能体，不是真人。它可以陪你专注、答疑、复盘，但不能替代老师、医生或心理咨询师。'
  ]),
  new DocSection('二、账号与登录', [
    '· 当前版本使用本机账号：用户名与密码摘要只保存在这台设备上，没有服务端账号体系。',
    '· 因此换设备无法直接登录，需要在新设备上重新注册；本机已有的数据也不会跟随迁移。',
    '· 请自行保管密码。由于校验在本机完成，本应用不承诺账号级的安全防护强度，请勿使用你在其它网站的重要密码。',
    '· 一台设备只保留一个本地账号，用新用户名注册等于在本机切换或重建账号。'
  ]),
  new DocSection('三、使用规范', [
    '· 请勿将本应用用于任何违法违规用途，也请勿输入违法违规内容。',
    '· 请勿试图绕过专注感知的授权流程（例如伪造状态数据）。',
    '· 你需要对自己的使用行为、以及在应用中输入的内容负责。'
  ]),
  new DocSection('四、关于 AI 生成内容', [
    '· 任务规划、答疑、复盘建议与首页语录，部分由大模型生成，部分基于本地规则生成，可能存在错误、遗漏或过时信息。',
    '· AI 回答会标注来源（大模型回答 / 本地模板回答），仅供参考。涉及公式、结论、法条等内容时，请以教材与老师讲授为准。',
    '· 本应用不提供医疗、法律、投资等专业建议；如有心理或健康方面的困扰，请寻求专业人士帮助。'
  ]),
  new DocSection('五、数据与内容归属', [
    '· 你在应用中输入与产生的数据归你所有，保存在你的设备上，处理方式见《隐私政策》。',
    '· 应用本身的界面设计、代码与文案归开发者所有。'
  ]),
  new DocSection('六、服务变更、中断与终止', [
    '· 随着版本迭代，功能可能新增、调整或下线（例如感知能力的升级或降级）。',
    '· 依赖第三方服务（大模型、语音识别、云端画面识别）的功能，可能因服务商调整、网络或额度原因暂时不可用；此时应用会明确提示，并降级到仍然可用的能力（例如仅计时模式）。',
    '· 你可以随时停止使用；卸载应用即视为终止使用，本机数据会一并删除。'
  ]),
  new DocSection('七、免责与责任限制', [
    '· 学习效果取决于你的实际投入，本应用不对考试结果、成绩提升作出任何承诺。',
    '· 「专注 / 分心」的判定是基于可观察状态的估计，不是对你注意力水平的精确测量，请勿据此评价他人。',
    '· 因设备故障、系统升级、第三方服务不可用、网络中断等导致的数据丢失或功能不可用，开发者不承担赔偿责任；重要内容请自行留存。'
  ]),
  new DocSection('八、协议变更与适用', [
    '· 协议内容发生实质变化时，文档版本号会更新，登录时会重新征求你的同意。',
    '· 继续使用即表示你接受变更后的协议；如不接受，可停止使用并清除本机数据。'
  ]),
  new DocSection('九、联系我们', [
    '本应用为 2026 中国高校计算机大赛（鸿蒙赛道）参赛作品，未设立客服邮箱。如对本协议有疑问，可通过赛事平台或项目负责人联系开发者。'
  ])
]

/** 《隐私政策》各节 */
const POLICY_SECTIONS: DocSection[] = [
  new DocSection('一、我们收集哪些信息', [
    '· 账号信息：你设置的用户名，以及密码的不可逆散列摘要。仅保存在这台设备上，不上传、不参与服务端校验。',
    '· 学习数据：目标与考试日期、AI 规划出的任务与时长、每次专注的起止时间、专注与分心时长、状态时间线、复盘记录、练习内容统计。',
    '· 感知数据：开启专注感知时，信号触发会抓拍 2~3 秒的画面短片段，同时记录可观察状态（做题 / 看书 / 看手机 / 趴桌 / 画面无人）。',
    '· 生理数据（可选）：连接标准蓝牙心率设备（手环 / 胸带）时读取心率与 HRV；不连接则不采集。',
    '· 语音数据（可选）：仅在任务规划或专注答疑里按住说话时采集，用于转写成文字。',
    '· 我们不收集：通讯录、短信、通话记录、精确位置、应用列表，也不读取相册。'
  ]),
  new DocSection('二、信息如何被使用', [
    '· 本机处理：专注状态判定、时长统计、复盘图表、练习内容归类，全部在本机完成。',
    '· 云端画面识别：抓拍到的画面短片段会上传到云端服务做「在做什么」的识别，云端只返回可观察状态，不做注意力、情绪或成绩的推断。',
    '· 大模型服务：AI 规划、答疑、复盘建议会把必要的上下文（目标类型、剩余天数、任务清单、你的提问、当前任务名、当天统计数字）发送给第三方大模型服务商。不发送账号密码，也不发送与功能无关的个人信息。',
    '· 桌面服务卡片：会把「今日专注时长 / 净专注率 / 当前建议」写入本机缓存，供桌面卡片读取展示。'
  ]),
  new DocSection('三、存储位置与保存期限', [
    '· 全部数据保存在本机应用沙箱内：结构化数据在本地数据库，少量配置在本地键值缓存。',
    '· 画面短片段保存在应用私有目录，不会出现在系统相册里。',
    '· 保存期限：直到你在「我的 → 隐私」中主动清除，或者卸载应用。卸载会一并删除沙箱内的全部数据。',
    '· 当前版本不提供跨设备同步：换一台设备使用，看到的是一份全新的空数据。'
  ]),
  new DocSection('四、第三方与共享', [
    '· 云端画面识别服务：接收画面短片段，返回状态标签。',
    '· 大模型服务商：接收上文所述的对话上下文，返回文本结果。',
    '· 系统语音识别服务：接收你按住说话时录制的音频，返回文字。',
    '· 我们不会向第三方出售你的数据，也不做广告画像。',
    '· 上述服务商对数据的处理受其自身隐私政策约束；本应用只在实现对应功能所必需的范围内发送数据。'
  ]),
  new DocSection('五、系统权限与用途', [
    '· 网络（系统授予，无需你操作）：仅用于调用云端画面识别与大模型接口。',
    '· 相机：专注感知抓拍。可在系统设置中关闭；关闭后应用会自动降级为「仅计时模式」，不再抓拍。',
    '· 麦克风：语音输入转文字。未授权时输入框照常可以打字，只是没有语音入口。',
    '· 蓝牙：连接心率设备。不连接则不使用。',
    '· 震动：确认分心时震动提醒，可在「我的 → 隐私」里关闭。'
  ]),
  new DocSection('六、你的权利：查看、清除与撤回', [
    '· 查看：产生的数据都能在「首页 / 复盘」中看到。',
    '· 清除：在「我的 → 隐私」里可以分别清除学习数据、已保存的画面片段、生理数据，或一次性清除全部数据。清除操作不可恢复。',
    '· 撤回采集授权：开始专注时选择「仅计时」即本次完全不抓拍、不上传；不连接心率设备即不做生理采集；不使用语音输入，麦克风就不会采集。',
    '· 撤回同意：撤回后，下次登录需要重新阅读并勾选同意。已经保存在本机、尚未清除的数据不受影响，需要你单独清除。'
  ]),
  new DocSection('七、未成年人保护', [
    '本应用面向备考与日常学习人群。若你未满 14 周岁，请在监护人陪同下阅读本政策，并在取得监护人同意后使用；监护人可随时按第六节的方式清除本机数据。'
  ]),
  new DocSection('八、更新与联系', [
    '· 文档版本与生效日期见页首。内容发生实质变化时版本号会更新，登录时会重新征求你的同意。',
    '· 本应用为 2026 中国高校计算机大赛（鸿蒙赛道）参赛作品，未设立客服邮箱。如对隐私处理有疑问，可通过赛事平台或项目负责人联系开发者。'
  ])
]

@Entry
@Component
export struct PrivacyPolicy {
  /** 0 = 用户服务协议，1 = 隐私政策（默认先看隐私政策，与登录页勾选项的顺序相反）
   *  实际初值在 `aboutToAppear` 里按入口设置，见 `PrivacyDoc.TAB_REQUEST`。 */
  @State tab: number = 1
  /** 当前页签对应的文档内容 */
  @State sections: DocSection[] = []

  aboutToAppear(): void {
    // 入口通过 AppStorage 传"要看哪一篇"（与项目里 INDEX_TAB_REQUEST / FOCUS_*_REQUEST 同一套做法，
    // 避免 router.getParams() 的取值与类型转换在各版本上不一致）
    const req: number | undefined = AppStorage.get<number>(PrivacyDoc.TAB_REQUEST)
    if (req !== undefined && (req === 0 || req === 1)) {
      this.tab = req
    }
    this.applyTab()
  }

  private applyTab(): void {
    this.sections = this.tab === 0 ? AGREEMENT_SECTIONS : POLICY_SECTIONS
  }

  private switchTab(m: number): void {
    if (this.tab === m) {
      return
    }
    this.tab = m
    this.applyTab()
  }

  @Builder
  segTab(text: string, m: number) {
    Column() {
      Text(text)
        .fontSize(14)
        .fontWeight(this.tab === m ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.tab === m ? Colors.PRIMARY_DARK : Colors.TEXT_SECONDARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(38)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.tab === m ? Colors.CARD : Color.Transparent)
    .borderRadius(19)
    .onClick(() => {
      this.switchTab(m)
    })
  }

  build() {
    Scroll() {
      Column({ space: Spacing.MD }) {
        // 顶栏：左上角返回（从登录页进来就回登录页，从「我的」进来就回「我的」）
        Row() {
          Text('←')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
          Text('返回')
            .fontSize(15)
            .fontColor(Colors.TEXT_PRIMARY)
            .margin({ left: 4 })
          Blank()
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.back()
        })

        // 标题 + 版本
        Column() {
          Text('隐私保护说明')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')
          Text(`版本 v${PrivacyDoc.VERSION} · 生效日期 ${PrivacyDoc.EFFECTIVE}`)
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .margin({ top: 6 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 页签
        Row() {
          this.segTab(PrivacyDoc.AGREEMENT, 0)
          this.segTab(PrivacyDoc.POLICY, 1)
        }
        .width('100%')
        .padding(4)
        .backgroundColor(Colors.BG_ALT)
        .borderRadius(23)

        // 要点速览：只放在隐私政策下 —— 大家真正想确认的是"我的数据去哪了"
        if (this.tab === 1) {
          Column() {
            Text('一句话看懂')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.PRIMARY_DARK)
              .width('100%')
            ForEach(HIGHLIGHTS, (line: string, i: number) => {
              Row() {
                Text('·')
                  .fontSize(14)
                  .fontColor(Colors.PRIMARY_DARK)
                  .margin({ top: 1 })
                Text(line)
                  .fontSize(13)
                  .fontColor(Colors.TEXT_PRIMARY)
                  .lineHeight(21)
                  .layoutWeight(1)
                  .margin({ left: 6 })
              }
              .width('100%')
              .margin({ top: i === 0 ? 10 : 8 })
              .alignItems(VerticalAlign.Top)
            }, (line: string, i: number) => `hl_${i}`)
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Colors.PRIMARY_TINT)
          .borderRadius(Radius.LG)
          .alignItems(HorizontalAlign.Start)
        }

        // 正文各节
        ForEach(this.sections, (s: DocSection) => {
          Column() {
            Text(s.title)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.PRIMARY_DARK)
              .width('100%')
            ForEach(s.lines, (line: string, i: number) => {
              Text(line)
                .fontSize(13)
                .fontColor(Colors.TEXT_SECONDARY)
                .lineHeight(23)
                .width('100%')
                .margin({ top: i === 0 ? 10 : 8 })
            }, (line: string, i: number) => `${s.title}_${i}`)
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Colors.CARD)
          .borderRadius(Radius.LG)
          .alignItems(HorizontalAlign.Start)
        }, (s: DocSection) => `${this.tab}_${s.title}`)

        // 页脚
        Column() {
          Text(`文档版本 v${PrivacyDoc.VERSION}`)
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
          Text(`生效日期 ${PrivacyDoc.EFFECTIVE}`)
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .margin({ top: 4 })
          Text('文档内容发生实质变化时，版本号会更新，并在你下次登录时重新征求同意。')
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .lineHeight(18)
            .width('100%')
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 4, right: 4 })

        Blank().height(20)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
    .scrollBar(BarState.Off)
  }
}
