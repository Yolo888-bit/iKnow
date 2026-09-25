/**
 * 时间格式化工具
 */
export class TimeUtils {
  /** 秒 → "2h 36min"（用于概览） */
  static formatHMin(seconds: number): string {
    const s = Math.max(0, Math.floor(seconds))
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    if (h > 0) {
      return `${h}h ${m}min`
    }
    return `${m}min`
  }

  /**
   * 秒 → "1h 2min 36s" / "2min 36s" / "36s"（**统计用，精确到秒**）。
   *
   * 为什么不用 `formatHMin`：它只到分钟，于是"本次专注 39 秒"会显示成 `0min` ——
   * 测试和短时专注里看起来就像没数据。凡是**展示一段时长**的地方都用这个，
   * 只用小时量级的长期累计（"近 30 天累计 12h 30min"）才用 `formatHMin`。
   */
  static formatSec(seconds: number): string {
    const s = Math.max(0, Math.round(seconds))
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const sec = s % 60
    if (h > 0) {
      return `${h}h ${m}min ${sec}s`
    }
    if (m > 0) {
      return `${m}min ${sec}s`
    }
    return `${sec}s`
  }

  /** 秒 → "42:36" 或 "1:17:36"（用于大号倒计时） */
  static formatClock(seconds: number): string {
    const s = Math.max(0, Math.floor(seconds))
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const sec = s % 60
    const mm = m < 10 ? `0${m}` : `${m}`
    const ss = sec < 10 ? `0${sec}` : `${sec}`
    if (h > 0) {
      return `${h}:${mm}:${ss}`
    }
    return `${mm}:${ss}`
  }

  /** 秒 → "1h 52min" */
  static formatDuration(seconds: number): string {
    return TimeUtils.formatHMin(seconds)
  }

  /** 分钟 → "48 min" */
  static formatMin(minutes: number): string {
    return `${Math.round(minutes)} min`
  }

  /**
   * 时间戳 → "9/20"。
   * 给「近 7 天」这类**滚动窗口**的横轴用：柱子是从 6 天前排到今天，
   * 用固定的「一~日」星期标签会让星期二下面站着星期五的数据。
   */
  static formatMonthDay(timestamp: number): string {
    const d = new Date(timestamp)
    return `${d.getMonth() + 1}/${d.getDate()}`
  }

  /** 当天 0 点时间戳 */
  static dayStart(timestamp: number): number {
    const d = new Date(timestamp)
    d.setHours(0, 0, 0, 0)
    return d.getTime()
  }

  /**
   * 本周起点（自然周，周一 0 点）。
   * 「本周累计」用它；「近 7 天」用 dayStart(now) − 6 天。两者是不同的口径，不要混用。
   */
  static weekStart(timestamp: number): number {
    const d = new Date(timestamp)
    // getDay(): 0=周日 … 6=周六 → 换算成"距离本周一过了几天"
    const offset = (d.getDay() + 6) % 7
    return TimeUtils.dayStart(timestamp) - offset * 24 * 3600 * 1000
  }

  /** 是否同一天 */
  static isSameDay(a: number, b: number): boolean {
    const da = new Date(a)
    const db = new Date(b)
    return da.getFullYear() === db.getFullYear()
      && da.getMonth() === db.getMonth()
      && da.getDate() === db.getDate()
  }

  /** 距离目标日期的天数 */
  static daysUntil(targetDate: number, now: number): number {
    const oneDay = 24 * 3600 * 1000
    const diff = TimeUtils.dayStart(targetDate) - TimeUtils.dayStart(now)
    return Math.max(0, Math.round(diff / oneDay))
  }

  /** 按当前时间生成问候语 */
  static greeting(now: number): string {
    const h = new Date(now).getHours()
    if (h < 6) {
      return '夜深了'
    }
    if (h < 11) {
      return '早上好'
    }
    if (h < 14) {
      return '中午好'
    }
    if (h < 18) {
      return '下午好'
    }
    return '晚上好'
  }

  /** 分钟 → "09:30" */
  static minuteToClock(minuteOfDay: number): string {
    const h = Math.floor(minuteOfDay / 60)
    const m = minuteOfDay % 60
    const hh = h < 10 ? `0${h}` : `${h}`
    const mm = m < 10 ? `0${m}` : `${m}`
    return `${hh}:${mm}`
  }

  /**
   * 从自然语言里解析时长（分钟），解析不出来返回 0（= 不做时长约束）。
   * 支持：「2 小时」「两个小时」「半小时」「30 分钟」「1.5 小时」「1 小时 20 分钟」
   */
  static parseDurationMinutes(text: string): number {
    let minutes = 0
    const hourIdx = text.indexOf('小时')
    if (hourIdx > 0) {
      minutes += Math.round(TimeUtils.quantityBefore(text, hourIdx) * 60)
    }
    const minIdx = text.indexOf('分钟')
    if (minIdx > 0) {
      minutes += Math.round(TimeUtils.quantityBefore(text, minIdx))
    }
    return minutes
  }

  /** 取 pos 之前紧跟的数量（阿拉伯数字 / 一~十 / 半），允许中间夹「个、多、来、空格」 */
  private static quantityBefore(text: string, pos: number): number {
    let p = pos
    while (p > 0) {
      const ch = text.charAt(p - 1)
      if (ch === '个' || ch === '多' || ch === '来' || ch === ' ' || ch === '\t') {
        p--
      } else {
        break
      }
    }
    if (p === 0) {
      return 0
    }
    const cn = TimeUtils.cnDigit(text.charAt(p - 1))
    if (cn > 0) {
      return cn
    }
    let start = p
    while (start > 0) {
      const ch = text.charAt(start - 1)
      if ((ch >= '0' && ch <= '9') || ch === '.') {
        start--
      } else {
        break
      }
    }
    if (start === p) {
      return 0
    }
    const v = Number(text.substring(start, p))
    return Number.isNaN(v) ? 0 : v
  }

  private static cnDigit(ch: string): number {
    if (ch === '一') {
      return 1
    }
    if (ch === '两' || ch === '二') {
      return 2
    }
    if (ch === '三') {
      return 3
    }
    if (ch === '四') {
      return 4
    }
    if (ch === '五') {
      return 5
    }
    if (ch === '六') {
      return 6
    }
    if (ch === '七') {
      return 7
    }
    if (ch === '八') {
      return 8
    }
    if (ch === '九') {
      return 9
    }
    if (ch === '十') {
      return 10
    }
    if (ch === '半') {
      return 0.5
    }
    return 0
  }
}
