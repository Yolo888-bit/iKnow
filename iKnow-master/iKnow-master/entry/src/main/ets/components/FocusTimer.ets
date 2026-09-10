import { Colors } from '../common/Theme'
import { TimeUtils } from '../utils/TimeUtils'

/** 大号计时器显示 */
@Component
export struct FocusTimer {
  @Prop seconds: number = 0
  @Prop big: boolean = true

  build() {
    Text(TimeUtils.formatClock(this.seconds))
      .fontSize(this.big ? 68 : 44)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.TEXT_PRIMARY)
  }
}
