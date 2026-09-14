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

  // 对话气泡（AI 规划页 · 微信式一来一回）
  static readonly BUBBLE_AI = '#F1ECE3'      // AI 侧气泡：暖米色
  static readonly BUBBLE_USER = '#DCEBD1'    // 用户侧气泡：浅绿
  static readonly CHAT_ACTION = '#7FA65F'    // 对话页主按钮：低饱和橄榄绿
  static readonly AI_AVATAR_BG = '#2E2E2E'   // AI 头像底色：深灰
  static readonly ONLINE_SOFT = '#E4F0DA'    // "AI 助手在线" 徽标底
  static readonly ONLINE_DOT = '#5FA84E'     // "在线" 状态点

  // 答疑页配色：低饱和蓝，与规划页的橄榄绿区分开（避免两页被当成同一个页）
  static readonly QA_ACCENT = '#6E93B8'
  static readonly QA_SOFT = '#E8EFF6'

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
