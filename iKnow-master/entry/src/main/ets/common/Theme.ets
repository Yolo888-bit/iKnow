/**
 * iKnow 设计令牌
 * 设计语言：暖橙 / 米白、大量留白、柔和阴影、低饱和状态色
 */

export class Colors {
  // 主色 —— 暖橙
  static readonly PRIMARY = '#E8875A'
  static readonly PRIMARY_DARK = '#CF7047'
  static readonly PRIMARY_SOFT = '#F7E5DB'

  // 背景与卡片
  static readonly BG = '#FAF6F1'
  static readonly CARD = '#FFFFFF'
  static readonly LINE = '#EFE9E2'

  // 文本
  static readonly TEXT_PRIMARY = '#2F2A26'
  static readonly TEXT_SECONDARY = '#9A9188'
  static readonly TEXT_TERTIARY = '#C6BDB4'

  // 状态色（低饱和）
  static readonly GREEN = '#7FBF97'
  static readonly GREEN_SOFT = '#E4F1E9'
  static readonly YELLOW = '#E3C26B'
  static readonly YELLOW_SOFT = '#F9F0D9'
  static readonly RED = '#DD8E85'
  static readonly RED_SOFT = '#F9E7E4'

  // 合规 —— 摄像头红色指示灯
  static readonly CAMERA_RED = '#E4564B'

  // 柔和阴影
  static readonly SHADOW = '#14000000'
}

export class Radius {
  static readonly SM = 12
  static readonly MD = 18
  static readonly LG = 26
}

export class Spacing {
  static readonly XS = 4
  static readonly SM = 8
  static readonly MD = 16
  static readonly LG = 24
  static readonly XL = 32
}
