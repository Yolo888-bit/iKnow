import { FocusState } from '../models/Enums'
import { FocusSession } from '../models/FocusSession'
import { Task } from '../models/Task'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusTuning } from '../common/FocusTuning'

export interface Last30DaysSummary {
  totalHours: number
  completedTasks: number
  focusRate: number
  trend: number[]
}

export interface PracticeSummaryItem {
  subject: string
  content: string
  count: number
}

/** 练习明细的一项（供"点开看全部练习内容"用） */
export interface PracticeDetailItem {
  subject: string
  title: string
  /** 最近一次完成该任务的会话开始时间 */
  lastDoneMs: number
  /** 被完成过的次数（同一任务跨会话通常为 1） */
  times: number
}

export interface HabitInsight {
  bestWindow: string
  bestRate: number
  lowWindow: string
  lowNote: string
  advice: string
}

/** 单日学习总结（复盘页日历切换到「某天」时使用） */
export interface DaySummary {
  hasData: boolean
  studyMinutes: number
  focusRate: number
  completedTasks: number
  totalTasks: number
  qaSessions: number
  sessionCount: number
  bestPeriod: string
  levels: number[]
  states: string[]
  /** 与 levels 一一对应的横轴位置（当天累计分钟），供曲线按真实时间排布 */
  minutes: number[]
  /** 一天内多次专注时，相邻会话之间的分钟分界（供曲线画虚线分隔） */
  separators: number[]
}

/**
 * 指标字典 —— 全局唯一指标计算事实源（PRD §5 / §6）
 *
 * 设计原则（硬规则 §3）：
 *  - 全部为纯函数 `(FocusSession | FocusSession[]) => number/object`，不持状态、不读写存储。
 *  - 任何页面 / Service 不得自行解释指标口径；需要指标时一律调用本类。
 *  - 每个函数顶部 JSDoc 标注对应 PRD 行号，便于审计。
 *  - 除零一律返回 0，避免 NaN 污染 UI。
 *  - ArkTS 合规：静态方法内一律用 Metrics.xxx 而非 this.xxx。
 */
export interface FiveDim {
  efficiency: number
  concentration: number
  stability: number
  execution: number
  antiDistraction: number
}

export class Metrics {
  /** §6 / §5 统计最小样本数 N>=3（少于此数画像页显示"还在了解你"，禁止显示雷达数值） */
  static readonly MIN_SAMPLES = 3

  // ===================== §5 基础口径 =====================

  /** §5 墙钟 = 会话 running 期间全部流逝时间（秒） */
  static wallClock(s: FocusSession): number {
    return s.totalDuration
  }

  /** §5 休息 = 休息时长（秒） */
  static restSec(s: FocusSession): number {
    return s.breakDuration
  }

  /** §5 暂停 = 暂停时长（秒） */
  static pauseSec(s: FocusSession): number {
    return s.pausedDuration
  }

  /** §5 总学习 = 墙钟 − 休息 − 暂停（秒） */
  static totalStudySec(s: FocusSession): number {
    return Math.max(0, s.totalDuration - s.breakDuration - s.pausedDuration)
  }

  /** §5 净专注 = GREEN 累计（秒） */
  static netFocusSec(s: FocusSession): number {
    return s.focusDuration
  }

  /** §5 分心 = YELLOW + RED 累计（秒） */
  static distractionSec(s: FocusSession): number {
    return s.distractionDuration
  }

  /** §5 答疑 = QA（计入总，不计净）（秒） */
  static qaSec(s: FocusSession): number {
    return s.qaDuration
  }

  /** §5 净专注率 = 净专注 / 总学习（0-1） */
  static netFocusRate(s: FocusSession): number {
    const t = Metrics.totalStudySec(s)
    return t > 0 ? s.focusDuration / t : 0
  }

  /** §5 净专注率（百分比整数） */
  static focusRatePercent(s: FocusSession): number {
    return Math.round(Metrics.netFocusRate(s) * 100)
  }

  /** §5 分心率 = 分心 / 总学习（0-1） */
  static distractionRate(s: FocusSession): number {
    const t = Metrics.totalStudySec(s)
    return t > 0 ? s.distractionDuration / t : 0
  }

  /**
   * §5 完成率：优先按 estimatedDuration 加权，无权重信息时按任务数。
   * @param estMap 任务 id → 预计时长（分钟），可选；缺失时退化为任务数口径
   */
  static completionRate(s: FocusSession, estMap?: Map<string, number>): number {
    if (s.taskIds.length === 0) {
      // 自由专注未设定任务：不返回 100，避免「自由专注 = 100% 完成」的假象
      return 0
    }
    const done = s.completedTaskIds
    if (estMap !== undefined && estMap.size > 0) {
      let total = 0
      let comp = 0
      for (const id of s.taskIds) {
        const e = estMap.get(id)
        total += e ?? 0
        if (done.indexOf(id) >= 0) {
          comp += e ?? 0
        }
      }
      return total > 0 ? Math.round((comp / total) * 100) : 0
    }
    return Math.round((done.length / s.taskIds.length) * 100)
  }

  // ===================== §5 跨会话指标 =====================

  /**
   * §5 黄金时段：最近 14 天，按 2 小时滑动窗口统计总学习时长，返回峰值窗口的时钟区间。
   * 无数据返回空串。
   */
  static goldenWindow(sessions: FocusSession[]): string {
    const now = Date.now()
    const dayMs = 24 * 3600 * 1000
    const buckets = new Array<number>(12).fill(0) // 12 个 2h 窗口
    let found = false
    for (const s of sessions) {
      if (now - s.startTime > 14 * dayMs || s.startTime > now) {
        continue
      }
      const d = new Date(s.startTime)
      const idx = Math.floor((d.getHours() * 60 + d.getMinutes()) / 120)
      if (idx >= 0 && idx < 12) {
        buckets[idx] += Metrics.totalStudySec(s)
        found = true
      }
    }
    if (!found) {
      return ''
    }
    let peak = 0
    for (let i = 0; i < 12; i++) {
      if (buckets[i] > buckets[peak]) {
        peak = i
      }
    }
    if (buckets[peak] <= 0) {
      return ''
    }
    const startMin = peak * 120
    const endMin = startMin + 120
    return `${Metrics.clock(startMin)} - ${Metrics.clock(endMin)}`
  }

  /**
   * §5 专注阈值：最近 N(>=3) 次会话中，每次"最长连续 GREEN 段（分钟）"的中位数。
   * 样本不足返回 0。
   */
  static focusThreshold(sessions: FocusSession[]): number {
    const runs: number[] = []
    for (const s of sessions) {
      let best = 0
      let cur = 0
      for (const p of s.timeline) {
        if (p.state === FocusState.FOCUSED) {
          cur += 1
        } else {
          best = Math.max(best, cur)
          cur = 0
        }
      }
      best = Math.max(best, cur)
      runs.push(Metrics.samplesToMinutes(best))
    }
    const last = runs.slice(-Metrics.MIN_SAMPLES)
    if (last.length < Metrics.MIN_SAMPLES) {
      return 0
    }
    return Math.round(Metrics.median(last))
  }

  // ===================== §6 五维画像 =====================

  /**
   * §6 五维（纯计算，不含样本门禁）。
   * 调用方须先用 canShowProfile(sampleCount) 判断是否达到 N>=3，未达请勿渲染数值。
   *  - efficiency     = 0.6*净专注率均值 + 0.4*完成率均值
   *  - concentration  = 净专注率均值
   *  - stability      = 净专注率序列 σ：σ>0.3 → 0；否则 100*(1-σ/0.4)
   *  - execution      = 完成率均值
   *  - antiDistraction= 100*(1-分心率均值)
   */
  static fiveDim(sessions: FocusSession[]): FiveDim {
    const finished = sessions.filter((s: FocusSession): boolean => Metrics.totalStudySec(s) > 0)
    if (finished.length === 0) {
      return { efficiency: 0, concentration: 0, stability: 0, execution: 0, antiDistraction: 0 }
    }
    const rates: number[] = finished.map((s: FocusSession): number => Metrics.netFocusRate(s) * 100)
    const comps: number[] = finished.map((s: FocusSession): number => Metrics.completionRate(s))
    const distrs: number[] = finished.map((s: FocusSession): number => Metrics.distractionRate(s))
    const avgRate = Metrics.mean(rates)
    const avgComp = Metrics.mean(comps)
    const avgDistr = Metrics.mean(distrs)
    const sigma = Metrics.stddev(rates) / 100

    const efficiency = Math.round(0.6 * avgRate + 0.4 * avgComp)
    const concentration = Math.round(avgRate)
    const stability = sigma > 0.3 ? 0 : Math.round(100 * (1 - Metrics.clamp(sigma / 0.4, 0, 1)))
    const execution = Math.round(avgComp)
    const antiDistraction = Math.round(100 * (1 - Metrics.clamp(avgDistr, 0, 1)))
    return { efficiency, concentration, stability, execution, antiDistraction }
  }

  /** §6 是否达到展示门槛（N>=3） */
  static canShowProfile(sampleCount: number): boolean {
    return sampleCount >= Metrics.MIN_SAMPLES
  }

  // ===================== 长期复盘聚合（§5 派生，统一走 Metrics）=====================

  /** 最近 30 天学习表现汇总：总学习小时、完成任务数、平均专注率、每日净专注分钟趋势 */
  static last30DaysSummary(sessions: FocusSession[], tasks: Task[], now: number): Last30DaysSummary {
    const dayMs = 24 * 3600 * 1000
    const cutoff = now - 30 * dayMs
    let totalNetSec = 0
    let totalStudySec = 0
    const completedIds: string[] = []
    const trend: number[] = []

    for (let i = 29; i >= 0; i--) {
      const dayStart = TimeUtils.dayStart(now) - i * dayMs
      const dayEnd = dayStart + dayMs
      let net = 0
      for (const s of sessions) {
        if (s.startTime >= dayStart && s.startTime < dayEnd) {
          net += s.focusDuration
        }
      }
      trend.push(Math.round(net / 60))
    }

    for (const s of sessions) {
      if (s.startTime >= cutoff) {
        totalNetSec += s.focusDuration
        totalStudySec += Metrics.totalStudySec(s)
        for (const id of s.completedTaskIds) {
          if (completedIds.indexOf(id) < 0) {
            completedIds.push(id)
          }
        }
      }
    }

    const focusRate = totalStudySec > 0 ? Math.round(totalNetSec / totalStudySec * 100) : 0
    return { totalHours: Math.round(totalNetSec / 3600), completedTasks: completedIds.length, focusRate: focusRate, trend: trend }
  }

  /**
   * 单日学习总结：汇总某一天（dayStart 起 24h 内）全部专注会话。
   * 学习时长 / 专注率 / 任务完成 / 答疑会话数 / 最佳时段 / 当日专注曲线，
   * 全部走统一口径，页面不得自行计算（硬规则 §3）。
   */
  static daySummary(sessions: FocusSession[], dayStart: number): DaySummary {
    const dayEnd = dayStart + 24 * 3600 * 1000
    const daySessions: FocusSession[] = []
    for (const s of sessions) {
      if (s.startTime >= dayStart && s.startTime < dayEnd) {
        daySessions.push(s)
      }
    }

    let netSec = 0
    let studySec = 0
    let done = 0
    let total = 0
    let qaSessions = 0
    const levels: number[] = []
    const states: string[] = []
    const minutes: number[] = []
    const separators: number[] = []
    let dayOffset = 0

    for (const s of daySessions) {
      netSec += s.focusDuration
      studySec += Metrics.totalStudySec(s)
      done += s.completedTaskIds.length
      total += s.taskIds.length
      if (Metrics.qaSec(s) > 0) {
        qaSessions++
      }
      for (const p of s.timeline) {
        levels.push(p.level)
        states.push(p.state)
        minutes.push(dayOffset + p.minute)
      }
      dayOffset += Math.round(Metrics.totalStudySec(s) / 60)
      separators.push(dayOffset)
    }
    // 末尾那根就是曲线终点，不需要画分隔线
    if (separators.length > 0) {
      separators.pop()
    }

    const focusRate = studySec > 0 ? Math.round(netSec / studySec * 100) : 0
    const best = daySessions.length > 0 ? Metrics.goldenWindow(daySessions) : ''
    return {
      hasData: daySessions.length > 0,
      studyMinutes: Math.round(studySec / 60),
      focusRate: focusRate,
      completedTasks: done,
      totalTasks: total,
      qaSessions: qaSessions,
      sessionCount: daySessions.length,
      bestPeriod: best,
      levels: levels,
      states: states,
      minutes: minutes,
      separators: separators
    }
  }

  /**
   * 练习明细：列出所有被完成过的任务（按学科分组、按最近完成时间倒序）。
   * 与 `practiceSummary` 的区别：summary 只给每科"一个代表标题 + 次数"（用在窄卡片里），
   * 这里给**完整列表**，供"点开看全部练习内容"。
   */
  static practiceDetail(sessions: FocusSession[], tasks: Task[]): PracticeDetailItem[] {
    const taskMap = new Map<string, Task>()
    for (const t of tasks) {
      taskMap.set(t.id, t)
    }
    const map = new Map<string, PracticeDetailItem>()
    // 会话按时间升序处理，最后一次会覆盖 lastDoneMs，得到"最近完成"
    const sorted = sessions.slice()
    sorted.sort((a: FocusSession, b: FocusSession): number => a.startTime - b.startTime)
    for (const s of sorted) {
      for (const id of s.completedTaskIds) {
        const t = taskMap.get(id)
        if (t === undefined) {
          continue
        }
        const key = `${t.subject}|${id}`
        const exist = map.get(key)
        if (exist === undefined) {
          map.set(key, {
            subject: t.subject,
            title: t.title,
            lastDoneMs: s.startTime,
            times: 1
          })
        } else {
          exist.lastDoneMs = s.startTime
          exist.times += 1
        }
      }
    }
    const list: PracticeDetailItem[] = []
    map.forEach((v: PracticeDetailItem) => {
      list.push(v)
    })
    list.sort((a: PracticeDetailItem, b: PracticeDetailItem): number => b.lastDoneMs - a.lastDoneMs)
    return list
  }

  /** 练习内容总结：按学科统计已完成任务次数，返回前 5 项 */
  static practiceSummary(sessions: FocusSession[], tasks: Task[]): PracticeSummaryItem[] {
    const taskMap = new Map<string, Task>()
    for (const t of tasks) {
      taskMap.set(t.id, t)
    }
    const groups = new Map<string, PracticeSummaryItem>()
    // 同一个任务可能跨多个会话都被标记完成，这里按任务 id 去重，避免"次数"被重复放大
    const counted = new Set<string>()
    for (const s of sessions) {
      for (const id of s.completedTaskIds) {
        if (counted.has(id)) {
          continue
        }
        counted.add(id)
        const t = taskMap.get(id)
        if (t !== undefined) {
          let g = groups.get(t.subject)
          if (g === undefined) {
            g = { subject: t.subject, content: t.title, count: 0 }
            groups.set(t.subject, g)
          }
          g.count++
        }
      }
    }
    const result: PracticeSummaryItem[] = []
    groups.forEach((value: PracticeSummaryItem, key: string) => {
      result.push(value)
    })
    result.sort((a: PracticeSummaryItem, b: PracticeSummaryItem): number => b.count - a.count)
    return result.slice(0, 5)
  }

  /**
   * 学习习惯洞察：黄金时段、低谷时段与可操作建议。
   * 全部由真实数据推导（无硬编码）；样本不足时返回空串，由页面显示空态。
   */
  static habitInsights(sessions: FocusSession[]): HabitInsight {
    const bucketsStudy = new Array<number>(12).fill(0)
    const bucketsNet = new Array<number>(12).fill(0)
    const used: number[] = []
    for (const s of sessions) {
      const study = Metrics.totalStudySec(s)
      if (study <= 0) {
        continue
      }
      const d = new Date(s.startTime)
      const idx = Math.floor((d.getHours() * 60 + d.getMinutes()) / 120)
      if (idx < 0 || idx >= 12) {
        continue
      }
      if (bucketsStudy[idx] === 0) {
        used.push(idx)
      }
      bucketsStudy[idx] += study
      bucketsNet[idx] += Metrics.netFocusSec(s)
    }
    if (used.length === 0) {
      return { bestWindow: '', bestRate: 0, lowWindow: '', lowNote: '', advice: '' }
    }

    let peak = used[0]
    let low = used[0]
    for (const i of used) {
      if (bucketsStudy[i] > bucketsStudy[peak]) {
        peak = i
      }
      if (bucketsStudy[i] < bucketsStudy[low]) {
        low = i
      }
    }
    const bestWindow = Metrics.bucketWindow(peak)
    const bestRate = Metrics.bucketRate(bucketsStudy[peak], bucketsNet[peak])

    if (used.length === 1) {
      return {
        bestWindow: bestWindow,
        bestRate: bestRate,
        lowWindow: '',
        lowNote: '',
        advice: `目前只统计到 ${bestWindow} 这一个时段（专注率 ${bestRate}%）。` +
          '再多几次其他时段的专注，我才能比较出低谷。'
      }
    }
    const lowWindow = Metrics.bucketWindow(low)
    const lowRate = Metrics.bucketRate(bucketsStudy[low], bucketsNet[low])
    const lowNote = lowRate + 10 < bestRate ? '容易分心' : '投入偏少'
    return {
      bestWindow: bestWindow,
      bestRate: bestRate,
      lowWindow: lowWindow,
      lowNote: lowNote,
      advice: `你的高效时段集中在 ${bestWindow}（专注率 ${bestRate}%）；${lowWindow} 偏低（${lowRate}%），` +
        `建议把需要深度思考的任务放在 ${bestWindow}，${lowWindow} 留给复习与轻量整理。`
    }
  }

  /** 第 i 个 2 小时桶的时钟区间 */
  private static bucketWindow(i: number): string {
    return `${Metrics.clock(i * 120)} - ${Metrics.clock(i * 120 + 120)}`
  }

  /** 桶内净专注率（%） */
  private static bucketRate(studySec: number, netSec: number): number {
    return studySec > 0 ? Math.round(netSec / studySec * 100) : 0
  }

  // ===================== 复盘辅助（§5 派生，统一走 Metrics）=====================

  /** 单次会话最佳专注时段：最长"高专注(>=70)连续段"对应的时钟区间 */
  static bestFocusPeriod(s: FocusSession): string {
    const tl = s.timeline
    if (tl.length === 0) {
      return ''
    }
    let bestStart = 0
    let bestLen = 0
    let curStart = 0
    let curLen = 0
    for (let i = 0; i < tl.length; i++) {
      const p = tl[i]
      if (p.level >= 70) {
        if (curLen === 0) {
          curStart = p.minute
        }
        curLen++
        if (curLen > bestLen) {
          bestLen = curLen
          bestStart = curStart
        }
      } else {
        curLen = 0
      }
    }
    if (bestLen === 0) {
      return ''
    }
    // p.minute 是"会话内相对分钟"，必须叠加会话起始的当天分钟数才是真实时钟，
    // 否则会输出 00:25 - 00:30 这类错值。
    const started = new Date(s.startTime)
    const baseMin = started.getHours() * 60 + started.getMinutes()
    // bestLen 是采样点个数，按采样间隔折算成分钟（否则 30s 采样时长度翻倍）
    const spanMinutes = Math.max(1, Math.round(Metrics.samplesToMinutes(bestLen)))
    const startClock = Metrics.clock(baseMin + bestStart)
    const endClock = Metrics.clock(baseMin + bestStart + spanMinutes)
    return `${startClock} - ${endClock}`
  }

  /** 采样点个数 → 分钟（采样间隔见 FocusTuning.TIMELINE_SAMPLE_MS） */
  private static samplesToMinutes(points: number): number {
    return points * FocusTuning.TIMELINE_SAMPLE_MS / 60000
  }

  /** 疲劳点：首次出现分心/低专注等级的分钟 */
  static fatigueMinute(s: FocusSession): number {
    for (const p of s.timeline) {
      if (p.state === FocusState.DISTRACTED || p.level < 45) {
        return p.minute
      }
    }
    return 0
  }

  /** 分心触发源（去重，最多 3 条） */
  static distractionTriggers(s: FocusSession): string[] {
    const seen: string[] = []
    for (const e of s.events) {
      if (e.state === FocusState.SLIGHTLY_DISTRACTED || e.state === FocusState.DISTRACTED) {
        const label = e.source === 'CAMERA' ? '视线离开屏幕' : '状态波动'
        if (seen.indexOf(label) < 0 && seen.length < 3) {
          seen.push(label)
        }
      }
    }
    if (seen.length === 0 && s.distractionDuration > 0) {
      seen.push('视线离开屏幕')
    }
    return seen
  }

  // ===================== 内部工具 =====================

  private static clamp(v: number, lo: number, hi: number): number {
    return Math.max(lo, Math.min(hi, v))
  }

  private static mean(arr: number[]): number {
    if (arr.length === 0) {
      return 0
    }
    let sum = 0
    for (const v of arr) {
      sum += v
    }
    return sum / arr.length
  }

  private static stddev(arr: number[]): number {
    if (arr.length === 0) {
      return 0
    }
    const m = Metrics.mean(arr)
    let acc = 0
    for (const v of arr) {
      acc += (v - m) * (v - m)
    }
    return Math.sqrt(acc / arr.length)
  }

  private static median(arr: number[]): number {
    if (arr.length === 0) {
      return 0
    }
    const a = arr.slice().sort((x: number, y: number): number => x - y)
    const mid = Math.floor(a.length / 2)
    return a.length % 2 === 0 ? (a[mid - 1] + a[mid]) / 2 : a[mid]
  }

  private static clock(totalMin: number): string {
    const h = Math.floor(totalMin / 60) % 24
    const m = totalMin % 60
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`
  }

  /** 由任务列表构建 id → 预计时长(分钟) 映射，供 completionRate 加权使用 */
  static buildEstMap(tasks: Task[]): Map<string, number> {
    const m = new Map<string, number>()
    for (const t of tasks) {
      m.set(t.id, t.estimatedDuration)
    }
    return m
  }
}
