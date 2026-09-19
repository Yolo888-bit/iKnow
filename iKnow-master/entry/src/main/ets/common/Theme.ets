/**
 * iKnow 设计令牌
 *
 * 设计语言：**清爽绿白** —— 浅绿白底 (#F4F8F5) + 纯白卡片 + 清新绿主色 (#1FA463)，
 * 大圆角、柔和阴影、低饱和状态色；全站同一绿色系，不再混入橙/蓝等异色。
 * 视觉参考：《01-作品说明文档_uDefine.pdf》第 7 页的四张设计稿
 * （AI 任务规划 / 实时陪伴 / 学习复盘 / 长期学习总结）。
 */

export class Colors {
  // ---------- 主色 —— 薄荷绿（对齐 WorkBuddy 品牌绿 #1DC78A）----------
  /**
   * 品牌绿：进度条、选中态、徽标、图形、浅色点缀。
   * 注意它偏亮，**白字压不住**（对比度仅约 2.2:1），
   * 所以带文字的实心块请用 PRIMARY_STRONG。
   */
  static readonly PRIMARY = '#1DC78A'
  /** 实心填充（主按钮）：品牌绿压深一档，白字可读（约 3.5:1） */
  static readonly PRIMARY_STRONG = '#0B9C6C'
  /** 强调文字 / 数字：白底上对比度约 5.4:1，可用于小字 */
  static readonly PRIMARY_DARK = '#067A52'
  /** 浅主色：选中态底色、浅色徽标 */
  static readonly PRIMARY_SOFT = '#DFF7EE'
  /** 更浅的绿调底：整块浅色卡片（如提示条、AI 气泡底） */
  static readonly PRIMARY_TINT = '#EFFBF6'

  // ---------- 背景与卡片 ----------
  static readonly BG = '#F5FAF9'
  /** 次级背景：页面里需要与白卡区分的内嵌块 */
  static readonly BG_ALT = '#EBF5F3'
  static readonly CARD = '#FFFFFF'
  static readonly LINE = '#E3EFEC'

  // ---------- 文本（带一点绿调的深灰，和白卡对比清晰） ----------
  static readonly TEXT_PRIMARY = '#1F2E2B'
  static readonly TEXT_SECONDARY = '#778C88'
  static readonly TEXT_TERTIARY = '#A9BDB8'

  // ---------- 状态色 ----------
  /** 正常 / 完成 / 在线 */
  static readonly GREEN = '#1DC78A'
  static readonly GREEN_SOFT = '#DFF7EE'
  /** 提醒 / 待处理 */
  static readonly YELLOW = '#D9A333'
  static readonly YELLOW_SOFT = '#FBF2DC'
  /** 异常 / 删除 / 分心 */
  static readonly RED = '#DE6B5E'
  static readonly RED_SOFT = '#FBEBE8'

  // ---------- 合规 —— 摄像头红色指示灯 ----------
  static readonly CAMERA_RED = '#E4564B'

  // ---------- 对话气泡（AI 规划 / 答疑，微信式一来一回） ----------
  /** AI 侧气泡：极浅薄荷灰，白卡上也能看出边界 */
  static readonly BUBBLE_AI = '#EEF7F4'
  /** 用户侧气泡：浅薄荷绿 */
  static readonly BUBBLE_USER = '#D6F4E8'
  /** 对话页主按钮 */
  static readonly CHAT_ACTION = '#0B9C6C'
  /** AI 头像底色：深墨绿（比纯黑柔和） */
  static readonly AI_AVATAR_BG = '#25352F'
  /** 「AI 在线」徽标底 / 状态点 */
  static readonly ONLINE_SOFT = '#DFF7EE'
  static readonly ONLINE_DOT = '#1DC78A'

  // ---------- 答疑页配色（同色系，用深绿与规划页区分，避免异色） ----------
  static readonly QA_ACCENT = '#067A52'
  static readonly QA_SOFT = '#DFF7EE'

  // ---------- 阴影 ----------
  /** 卡片柔和阴影 */
  static readonly SHADOW = '#12000000'
  /** 浮层 / 下拉面板阴影 */
  static readonly SHADOW_LAYER = '#2622302A'
}

export class Radius {
  static readonly SM = 12
  static readonly MD = 18
  static readonly LG = 26
  /** 大区块 / 底部弹层 */
  static readonly XL = 32
}

export class Spacing {
  static readonly XS = 4
  static readonly SM = 8
  static readonly MD = 16
  static readonly LG = 24
  static readonly XL = 32
}
