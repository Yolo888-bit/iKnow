import { FocusStateUi } from '../common/FocusStateUi'

/**
 * 状态呼吸灯：柔和光晕随状态颜色轻微呼吸，不打扰、无监控感
 */
@Component
export struct BreathingLight {
  @Prop state: string = 'FOCUSED'
  @State breathe: boolean = false
  onTap: () => void = () => {
  }
  private timerId: number = -1

  aboutToAppear(): void {
    this.timerId = setInterval(() => {
      this.breathe = !this.breathe
    }, 1400)
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  build() {
    Stack() {
      Circle()
        .width(150)
        .height(150)
        .fill(FocusStateUi.softColor(this.state))
        .opacity(this.breathe ? 0.35 : 0.75)
        .animation({ duration: 1400, curve: Curve.EaseInOut })

      Circle()
        .width(72)
        .height(72)
        .fill(FocusStateUi.color(this.state))
        .shadow({ radius: 18, color: FocusStateUi.softColor(this.state), offsetX: 0, offsetY: 0 })

      Text(FocusStateUi.dot(this.state))
        .fontSize(22)
    }
    .width(150)
    .height(150)
    .onClick(() => {
      this.onTap()
    })
  }
}
