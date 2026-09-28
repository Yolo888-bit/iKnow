/**
 * 分心提醒的文案与语音包 —— **唯一事实源**。
 *
 * 为什么单独放一个模块：同一句提醒既要以文字出现在干预卡片上，又要以录音播出来
 *（`resources/rawfile/` 下的 mp3）。文字在 AI 层（`MockAIService`）、音频在
 * `FeedbackService`，两处各存一份「人格 × 级别 → 内容」的映射迟早会漂移，
 * 所以表只有这一份，两边都从这里取。
 *
 * ⚠️ 录音文件名是**首句文字的拼音首字母**（沿用你录制的语音包命名），
 * 例如 `strict-zssjjc.mp3` = 「走神时间较长，请迅速收回注意力。」
 * 目前只录了**重度**两套；轻度没有录音 → `file` 为空串，表示"这一条只出文字，不出声"。
 *
 * 极简安静型（QUIET）按产品要求**完全没有话术**：界面只出状态徽标，
 * 不出声也不震动（它原本的设计是手表轻震/强震，但当前设备没有手表，
 * 按项目"绝不假装震动"的口径就只有徽标），所以它的 text 就是徽标本身。
 */

/** 一条提醒：文字 + 对应录音文件（'' = 没有录音，只出文字） */
export interface ReminderLine {
  text: string
  file: string
}

/** 提醒的粒度：黄灯=轻度，红灯=重度 */
export type ReminderLevel = 'LIGHT' | 'HEAVY'

const STRICT_LIGHT: ReminderLine[] = [
  { text: '注意力出现偏移，请及时收心。', file: '' },
  { text: '检测到走神，请回归学习任务。', file: '' },
  { text: '已产生分心，稳住学习节奏。', file: '' }
]

const STRICT_HEAVY: ReminderLine[] = [
  { text: '走神时间较长，请迅速收回注意力。', file: 'strict-zssjjc.mp3' },
  { text: '专注力持续涣散，请尽快进入状态。', file: 'strict-zzlcxhs.mp3' },
  { text: '当前状态松懈，请投入当前任务。', file: 'strict-dqztsx.mp3' }
]

const GENTLE_LIGHT: ReminderLine[] = [
  { text: '是不是有点累，试着把思绪拉回来好不好？', file: '' },
  { text: '偶尔走神没关系，稍微调整下可以吗。', file: '' },
  { text: '稍稍收下心，我们接着学习吧。', file: '' }
]

const GENTLE_HEAVY: ReminderLine[] = [
  { text: '走神有一会了，要不要短暂歇一下再继续？', file: 'gentle-zsyyll.mp3' },
  { text: '感觉有些疲惫，想坚持还是稍微放松会儿？', file: 'gentle-gjyxpb.mp3' },
  { text: '思绪飘远啦，休息片刻，还是接着学习？', file: 'gentle-sxpyl.mp3' }
]

/** 极简安静型：只有徽标，没有文字话术、没有录音 */
const QUIET_LIGHT: ReminderLine[] = [{ text: '⚠️轻度分心', file: '' }]
const QUIET_HEAVY: ReminderLine[] = [{ text: '🔴重度分心', file: '' }]

/**
 * 未知人格（含界面不可选的 ADAPTIVE）按温和陪伴型处理 ——
 * 与 `Prompts.toneOf()` / `MockAIService.WORDING` 的兜底口径保持一致。
 */
function rowsOf(personality: string, level: ReminderLevel): ReminderLine[] {
  const strict = personality === 'STRICT'
  const quiet = personality === 'QUIET'
  if (strict) {
    return level === 'HEAVY' ? STRICT_HEAVY : STRICT_LIGHT
  }
  if (quiet) {
    return level === 'HEAVY' ? QUIET_HEAVY : QUIET_LIGHT
  }
  return level === 'HEAVY' ? GENTLE_HEAVY : GENTLE_LIGHT
}

/** 轮换游标：key = `人格|级别`，value = 下一条要用的下标（只在真正发声时推进） */
const CURSOR: Map<string, number> = new Map<string, number>()

export class ReminderLines {
  /**
   * 取**界面要显示**的那一条：同一人格同一级别固定用第一条。
   *
   * 为什么不跟着轮换：卡片文字会被反复重绘（状态评估每次都可能拿到新文案），
   * 若每次都推进游标，文字会几秒钟换一句、还会和实际播出的录音对不上。
   * 轮换只发生在**真正播出声音**的时候（见 `nextForVoice()`）。
   */
  static textOf(personality: string, level: ReminderLevel): string {
    const rows = rowsOf(personality, level)
    return rows.length > 0 ? rows[0].text : ''
  }

  /**
   * 取**本次要播**的那一条，并推进轮换游标。
   * 只在确实要发声时调用一次 —— 同人格的多段录音轮流用，避免每次都是同一句。
   */
  static nextForVoice(personality: string, level: ReminderLevel): ReminderLine | null {
    const rows = rowsOf(personality, level)
    if (rows.length === 0) {
      return null
    }
    const key = `${personality}|${level}`
    const raw = CURSOR.get(key)
    const start = raw === undefined ? 0 : raw
    // 从当前下标起找第一条**有录音**的 —— 没录音的条目要跳过，否则会"播了但没声音"
    for (let i = 0; i < rows.length; i++) {
      const at = (start + i) % rows.length
      if (rows[at].file.length > 0) {
        CURSOR.set(key, (at + 1) % rows.length)
        return rows[at]
      }
    }
    return null
  }

  /** 该人格该级别有没有录音（页面用它如实说明"这一档会不会出声"） */
  static hasVoice(personality: string, level: ReminderLevel): boolean {
    for (const r of rowsOf(personality, level)) {
      if (r.file.length > 0) {
        return true
      }
    }
    return false
  }
}
