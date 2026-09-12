import { Colors } from '../common/Theme'

/**
 * 通用用户头像组件
 *
 *  - 两种形态统一渲染，页面无需区分：
 *      1) emoji 字符（默认，如 '🧑‍🎓' / '🦊'）→ 文字
 *      2) 相册照片（保存为 `file://` 前缀的 sandbox 路径）→ Image
 *  - 页面只需把 AppStorage 的 USER_AVATAR 透传进来即可。
 */
@Component
export struct UserAvatar {
  @Prop avatar: string = '🧑‍🎓'
  /** 直径（px）。注意不能命名为 size —— 会与 ArkUI 通用属性 size() 冲突 */
  @Prop diameter: number = 40
  /** 圆角：<=0 时按圆形（diameter / 2），>0 时按给定圆角（截图里用户头像为圆角方形） */
  @Prop radius: number = 0
  @Prop bg: string = Colors.PRIMARY_SOFT

  /** 判定是否为照片路径（兼容 file:// 与绝对路径） */
  private isPhoto(): boolean {
    const a: string = this.avatar
    return a.indexOf('file://') === 0 || a.indexOf('/') === 0 || a.indexOf('://') > 0
  }

  private corner(): number {
    return this.radius > 0 ? this.radius : this.diameter / 2
  }

  build() {
    if (this.isPhoto()) {
      Image(this.avatar)
        .width(this.diameter)
        .height(this.diameter)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.corner())
        .backgroundColor(this.bg)
    } else {
      Text(this.avatar)
        .fontSize(Math.round(this.diameter * 0.56))
        .width(this.diameter)
        .height(this.diameter)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.bg)
        .borderRadius(this.corner())
    }
  }
}
