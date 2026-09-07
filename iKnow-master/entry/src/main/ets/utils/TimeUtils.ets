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

  /** 当天 0 点时间戳 */
  static dayStart(timestamp: number): number {
    const d = new Date(timestamp)
    d.setHours(0, 0, 0, 0)
    return d.getTime()
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
}
