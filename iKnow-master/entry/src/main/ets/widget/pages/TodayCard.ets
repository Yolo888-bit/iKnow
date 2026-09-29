import { openAppAction, startFocusAction } from '../CardActions'

/**
 * 服务卡片之一：**今日数据**（2*2 / 2*4）—— 桌面 / 负一屏上的「今日专注」概览
 *
 * 数据由 `EntryFormAbility` 通过 formBindingData 注入到 LocalStorage，
 * 卡片侧只读这 3 个键，不直接访问数据库（卡片跑在独立进程，读不到主进程内存）。
 *
 * 两种交互都走 `postCardAction({action:'call'})` 拉起 EntryAbility（见 `CardActions.ets`）：
 *   · 点整张卡 → 打开 App 并落到「首页」
 *   · 点「开始专注」→ 直接起一段会话（是否开摄像头由专注页弹确认，卡片不替用户决定）
 */

@Entry
@Component
struct TodayCard {
  @LocalStorageProp('todayFocus') todayFocus: string = '0min'
  @LocalStorageProp('focusRate') focusRate: string = '0%'
  @LocalStorageProp('advice') advice: string = '开始一段专注吧'

  build() {
    Column() {
      Text('iKnow · 今日专注')
        .fontSize(12)
        .fontColor('#9A9188')
        .width('100%')

      Text(this.todayFocus)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F2A26')
        .width('100%')
        .margin({ top: 6 })

      Text(`净专注率 ${this.focusRate}`)
        .fontSize(12)
        .fontColor('#9A9188')
        .width('100%')
        .margin({ top: 2 })

      // 收成一行：2*2 卡片本来就矮，加了按钮之后两行建议会被裁掉
      Text(this.advice)
        .fontSize(11)
        .fontColor('#C6BDB4')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })

      // 一键开始专注：不需要打开 App 就能起一段会话。
      // 是否开启摄像头**不在这里决定** —— 专注页会弹一次感知确认（授权点唯一）。
      Text('开始专注')
        .fontSize(13)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(30)
        .backgroundColor('#7C9A78')
        .borderRadius(15)
        .margin({ top: 8 })
        .onClick(() => {
          postCardAction(this, startFocusAction())
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FAF6F1')
    // 点整张卡 = 打开 App 落到首页（按钮的点击不会冒泡到这里，各走各的）
    .onClick(() => {
      postCardAction(this, openAppAction('home'))
    })
  }
}
