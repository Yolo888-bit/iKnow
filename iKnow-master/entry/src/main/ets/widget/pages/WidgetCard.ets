/**
 * 服务卡片（2*2 / 2*4）—— 桌面 / 负一屏上的「今日专注」概览
 *
 * 数据由 `EntryFormAbility` 通过 formBindingData 注入到 LocalStorage，
 * 卡片侧只读这 3 个键，不直接访问数据库。
 *
 * 「开始专注」按钮走 `postCardAction({action:'call'})` → 拉起 EntryAbility，
 * 参数与意图框架、`hdc aa start` **完全同一套**（取名见 `common/Constants.ets` 的
 * `StorageKey.IK_ACTION`，取值见 `insightintent/ExternalEntry.ets`）。
 * 三个入口驱动同一段代码；卡片不 import 那两个模块 —— 它在独立进程里跑，
 * 不该把 AppStore / StorageService 一起拉进来，所以这里字段名只能写字面量。
 */

/** 拉起 Ability 时携带的参数（ArkTS 不允许未类型化的对象字面量，显式声明） */
class CardCallParams {
  /** = StorageKey.IK_ACTION */
  ik_action: string = 'start_focus'
}

class CardCallAction {
  action: string = 'call'
  abilityName: string = 'EntryAbility'
  moduleName: string = 'entry'
  params: CardCallParams = new CardCallParams()
}

@Entry
@Component
struct WidgetCard {
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
          postCardAction(this, new CardCallAction())
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FAF6F1')
  }
}
