import { openAppAction } from '../CardActions'

/**
 * 服务卡片之二：**长期数据**（2*2 / 2*4）—— 桌面 / 负一屏上的「坚持了多久」
 *
 * 与「今日数据」卡是**两张独立的卡片**，用户添加时自己选一张
 * （见 `resources/base/profile/form_config.json`，两个 form 共用同一个 EntryFormAbility，
 * 由 `formInfo.FormParam.NAME_KEY` 区分该注入哪一组数据）。
 *
 * 数据同样由 `EntryFormAbility` 注入 LocalStorage，卡片侧只读 3 个键：
 *   · ltTotal  累计净专注时长（全部会话之和）
 *   · ltStreak 连续学习天数（含今天；今天还没学则从昨天起算）
 *   · ltDays   近 31 天里有学习的天数
 * 口径都来自 `Metrics.streaks` 与 `Metrics.netFocusSec`，与复盘页同一套。
 *
 * 点整张卡 → 打开 App 并落到「复盘」Tab（这张卡讲的是长期表现，落在长期页最顺）。
 */
@Entry
@Component
struct LongTermCard {
  @LocalStorageProp('ltTotal') ltTotal: string = '0min'
  @LocalStorageProp('ltStreak') ltStreak: string = '0'
  @LocalStorageProp('ltDays') ltDays: string = '0'

  build() {
    Column() {
      Text('iKnow · 累计专注')
        .fontSize(12)
        .fontColor('#9A9188')
        .width('100%')

      Text(this.ltTotal)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F2A26')
        .width('100%')
        .margin({ top: 6 })

      Text(`连续 ${this.ltStreak} 天`)
        .fontSize(12)
        .fontColor('#7C9A78')
        .width('100%')
        .margin({ top: 2 })

      // 收成一行：2*2 卡片本来就矮
      Text(`近 30 天学习 ${this.ltDays} 天`)
        .fontSize(11)
        .fontColor('#C6BDB4')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FAF6F1')
    .onClick(() => {
      postCardAction(this, openAppAction('review'))
    })
  }
}
