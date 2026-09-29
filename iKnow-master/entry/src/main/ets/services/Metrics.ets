import { FocusState, FocusSource, TaskStatus, PerceptionMode } from '../models/Enums'
import { FocusSession } from '../models/FocusSession'
import { Task } from '../models/Task'
import { StudyPlan } from '../models/StudyPlan'
import { TimeUtils } from '../utils/TimeUtils'
import { FocusTuning } from '../common/FocusTuning'

export interface Last30DaysSummary {
  totalHours: number
  /** 近 30 天净专注总秒数：`totalHours` 只有小时粒度、会丢掉分钟，精细 "xxh xxmin" 展示用它 */
  totalNetSeconds: number
  completedTasks: number
  focusRate: number
  /**
   * 近 30 天逐日「专注度」（100 分制），index 0 = 29 天前、末位 = 今天。
   * 当天多次专注取各次专注度的平均值；没学的那天是 0。
   */
  trend: number[]
}

export interface PracticeSummaryItem {
  subject: string
  /** 该科目下**已完成**的任务数（用户要的口径："数学 2 次"） */
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
  /**
   * 一行概览"最常学的时段"（按累计学习时长取前 2），如
   * `20:00 - 21:00（3 次 · 45 分钟）、21:00 - 22:00（2 次 · 20 分钟）`。
   *
   * 为什么不逐时段列一张表：这一块叫"洞察"，要的是结论，不是数据表。
   * 逐时段铺开会把卡片撑得很长（最多 24 行），重点被数字淹没。
   * 没有任何学习记录时为空串（界面据此走空态）。
   */
  topSummary: string
  /**
   * `advice` 为空时用它：挑最接近门槛的时段，说清还差几次 / 几分钟。
   * 比干巴巴一句"数据不足"可操作。没有任何学习记录时为空串。
   */
  gateNote: string
}

/** 单日学习总结（复盘页日历切换到「某天」时使用） */
export interface DaySummary {
  hasData: boolean
  /**
   * 当天累计学习时长（**秒**）。
   * 用秒而不是分钟：分钟精度下"某天只学了 39 秒"会显示成 `0 分钟`，看着像没数据。
   * 展示一律用 `TimeUtils.formatSec()`。
   */
  studySeconds: number
  focusRate: number
  completedTasks: number
  totalTasks: number
  /** 当天累计答疑时长（秒） */
  qaSeconds: number
  sessionCount: number
  bestPeriod: string
  /**
   * 当天"主会话"（总学习最长的那一次）的结构指标。
   * 用最长的那一次而不是把当天几段拼起来：跨会话算"被打断后多久回来"没有意义。
   */
  structure: SessionStructure
}

/**
 * 单次会话的**结构指标**（从 30 秒粒度的 `timeline` 算出来）。
 *
 * 为什么单独做这一层：timeline 里本来就有"什么时候专注、什么时候分心"的全部信息，
 * 但此前只被用来画色带，一个结构量都没算 —— 于是洞察只能复述"净专注率 78%"，
 * 哪一天都像同一句话。结构指标才是"可对比、可干预"的东西：
 * 进入状态要多久、最长能撑多久、被打断几次、被打断后多久能回来。
 */
export interface SessionStructure {
  /** 开始 → 首次进入专注的分钟数；-1 = 整场都没进入专注 */
  timeToFocus: number
  /** 最长连续专注段（分钟） */
  longestRun: number
  /** 分心段次数（专注 → 非专注的切换次数） */
  bouts: number
  /** 每次分心回到专注的耗时中位数（分钟）；-1 = 没有完整恢复过一次 */
  recoveryMedian: number
  /** level ≥ 80 的采样点占比（0-1） */
  deepRatio: number
  /** 后 1/3 平均 level − 前 1/3 平均 level（负数 = 后段掉下来了，即疲劳拐点） */
  tailDrop: number
}

/**
 * 本人基线（"这次"的对比参照），窗口与门槛见 D7：
 *  - 窗口：近 **7** 天优先；不达门槛扩到近 **30** 天；仍不达则 `ready = false`，不给跨天结论；
 *  - 门槛：窗口内 ≥ `MIN_SAMPLES` 次会话 **且** 累计总学习 ≥ 60 分钟；
 *  - **排除当天**：当天数据会把自己稀释，差值会被腰斩。
 */
export interface Baseline {
  ready: boolean
  /** 还差几次会话（ready = false 时给用户看的数字） */
  needMore: number
  sampleCount: number
  /** 实际采用的时间窗（7 / 30；0 = 两档都不达标） */
  windowDays: number
  timeToFocus: number
  longestRun: number
  bouts: number
  recoveryMedian: number
  deepRatio: number
  netFocusRate: number
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
  /** 计入「抗干扰」的会话数（仅感知开启的会话），0 表示无数据 */
  perceptionCount: number
  /** 计入「执行力」的会话数（仅含任务清单的会话），0 表示无数据 */
  taskCount: number
}

/** 近 7 天 vs 前 7 天（§6.2）。变化幅度不到 10% 一律算"基本持平"，不把波动说成趋势 */
export interface Trend7v7 {
  /** 两个窗口都有数据才为 true；否则只报当天事实 */
  ready: boolean
  curRate: number
  prevRate: number
  /** '上升' | '下降' | '基本持平' | '数据不足' */
  rateTrend: string
  curAvgMinutes: number
  prevAvgMinutes: number
  avgTrend: string
}

/** 规律性：连续学习天数与最长空档（§6.2） */
export interface Streaks {
  /** 连续学习天数（含今天；今天还没学则从昨天起算） */
  currentStreak: number
  /** 近 30 天里最长连续没学的天数 */
  longestGapDays: number
  /** 近 31 天里有学习的天数 */
  studiedDays: number
}

/** 「目标进度」里的单科行。科目来自 `StudyPlan.subjectTargets`，不由任务反推 */
export interface SubjectProgressRow {
  subject: string
  targetMinutes: number
  /** 口径 A 分子：已勾选任务的预计时长之和（分钟） */
  doneEstimatedMinutes: number
  /** 口径 B 分子：实际投入（分钟） */
  actualMinutes: number
  totalTasks: number
  doneTasks: number
  /** OK / NO_TARGET / NO_TASK / OVER */
  state: string
}

/**
 * 长期计划的目标进度。
 * `state`：`NO_PLAN`（没计划）/ `NO_TARGET`（有科目但没填目标）/ `NO_TASK`（有目标但本期无任务）/
 * `OK` / `OVER`（实际投入已超目标）。**任何情况下都不默认显示 100%**。
 */
export interface PlanProgress {
  planTitle: string
  /** 分母 = Σ 各科目标分钟（不含迁移遗留的"未分配"） */
  targetMinutes: number
  /** 口径 A 分子（分钟） */
  doneEstimatedMinutes: number
  /** 口径 B 分子（分钟，主口径） */
  actualMinutes: number
  /** clamp(0,100) */
  completedPercent: number
  /** clamp(0,100) */
  investedPercent: number
  /** 超出目标的分钟数，未超出为 0 */
  overdueMinutes: number
  /** 未分类 / 未归属任务的**实际投入**（分钟）：只展示，不计入百分比 */
  unassignedActualMinutes: number
  unassignedTasks: number
  /** 迁移遗留、还没分到科目的目标分钟（> 0 时进度无法计算） */
  unassignedTargetMinutes: number
  state: string
  subjects: SubjectProgressRow[]
}

export class Metrics {
  /** §6 / §5 统计最小样本数 N>=3（少于此数画像页显示"还在了解你"，禁止显示雷达数值） */
  static readonly MIN_SAMPLES = 3
  /** 时段分析的资格门槛（D7）：桶内至少 2 次会话、累计总学习至少 20 分钟 */
  static readonly HABIT_MIN_SESSIONS = 2
  static readonly HABIT_MIN_STUDY_SEC = 20 * 60
  /** 高峰/低谷的落差门槛（百分点）：不到就不下结论，输出"各时段差别不大" */
  static readonly HABIT_RATE_GAP = 8

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

  /**
   * 参与状态判定的时长 = 净专注 + 分心（秒），**不含答疑 / 休息 / 暂停**。
   *
   * 专注曲线时间轴的横轴用它：总学习里含答疑，而答疑期间状态不变、不该占色带宽度，
   * 拿总学习当横轴会让「专注 : 分心」的视觉比例和复盘里的时长数字对不上。
   */
  static judgedSec(s: FocusSession): number {
    return s.focusDuration + s.distractionDuration
  }

  /** §5 答疑 = QA（计入总，不计净）（秒） */
  static qaSec(s: FocusSession): number {
    return s.qaDuration
  }

  /**
   * 专注率 = **净专注 / 已判定学习时长**（0-1）。
   *
   * 分母刻意用 `judgedSec`（净专注 + 分心），**不含答疑**（也不含休息/暂停）——
   * 答疑期间状态不参与"专注还是分心"的判定，算进分母会把率值压低
   * （用户实测反馈："专注率的计算不太对，应该是专注时间/总时间（抛开答疑时间）"）。
   * 这也是专注曲线色带的比例口径，两者必须一致，否则数字和图形又对不上。
   */
  static netFocusRate(s: FocusSession): number {
    const t = Metrics.judgedSec(s)
    return t > 0 ? s.focusDuration / t : 0
  }

  /** §5 净专注率（百分比整数） */
  static focusRatePercent(s: FocusSession): number {
    return Math.round(Metrics.netFocusRate(s) * 100)
  }

  /** 分心率 = 分心 / 已判定学习时长（0-1）。分母与 `netFocusRate` 一致，两者相加为 1 */
  static distractionRate(s: FocusSession): number {
    const t = Metrics.judgedSec(s)
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
   *
   * 口径统一为「跨会话汇总」，**不用"各会话百分比的算术平均"** —— 后者给一次 1 分钟的会话
   * 和一次 2 小时的会话同样的权重：短会话里有一个任务没打钩就能把分数拉到很低，
   * 于是出现"任务完成度很高、执行力却只有 20 分"。
   *
   *  - concentration  = Σ净专注 / Σ已判定（按时长加权，与复盘页「总体专注率」同一口径）
   *  - efficiency     = 0.6*concentration + 0.4*execution
   *  - execution      = 这些会话里**用户承诺过的任务**现在真正完成的比例。
   *                     按**任务表当前状态**判定 —— 在首页 / 复盘里补勾的也算。否则
   *                     `completedTaskIds` 是会话结束那一刻的快照，之后补勾的完成永远不计入。
   *  - stability      = 各会话专注率的 σ：σ>0.3 → 0；否则 100*(1-σ/0.4)
   *  - antiDistraction= 100*(1-分心率)（**仅**感知开启的会话；没开摄像头时 distractionDuration
   *                     恒为 0，混入会把「没数据」算成「抗干扰满分」，故剔除）
   *
   * @param tasks 任务表（含当前勾选状态）。传入才能把"会话结束后补勾"的完成计入执行力；
   *              不传则退回"会话内已勾选"的口径（仅老调用方兼容用）。
   */
  static fiveDim(sessions: FocusSession[], tasks?: Task[]): FiveDim {
    const finished = sessions.filter((s: FocusSession): boolean => Metrics.totalStudySec(s) > 0)
    if (finished.length === 0) {
      return { efficiency: 0, concentration: 0, stability: 0, execution: 0, antiDistraction: 0,
        perceptionCount: 0, taskCount: 0 }
    }

    // 专注度：Σ净专注 / Σ已判定（按时长加权）；σ 仍按"每次会话的专注率"算（稳定性讲的就是波动）
    let netSec = 0
    let judgedSec = 0
    const rates: number[] = []
    for (const s of finished) {
      netSec += Metrics.netFocusSec(s)
      judgedSec += Metrics.judgedSec(s)
      rates.push(Metrics.netFocusRate(s) * 100)
    }
    const weightedRate = judgedSec > 0 ? (netSec / judgedSec) * 100 : 0
    const sigma = Metrics.stddev(rates) / 100

    // 执行力：只统计「有任务清单」的会话；自由专注（无任务）不拉低、也不计入分母
    const taskSessions = finished.filter((s: FocusSession): boolean => s.taskIds.length > 0)
    const committed: string[] = []
    for (const s of taskSessions) {
      for (const id of s.taskIds) {
        if (committed.indexOf(id) < 0) {
          committed.push(id)
        }
      }
    }
    let execution = 0
    if (committed.length > 0) {
      const doneIds: string[] = []
      if (tasks !== undefined && tasks.length > 0) {
        // 以任务表当前状态为准（补勾也算）
        for (const t of tasks) {
          if (t.done || t.status === TaskStatus.DONE) {
            doneIds.push(t.id)
          }
        }
      } else {
        for (const s of taskSessions) {
          for (const id of s.completedTaskIds) {
            if (doneIds.indexOf(id) < 0) {
              doneIds.push(id)
            }
          }
        }
      }
      let doneCount = 0
      for (const id of committed) {
        if (doneIds.indexOf(id) >= 0) {
          doneCount += 1
        }
      }
      execution = Math.round((doneCount / committed.length) * 100)
    }

    // 抗干扰：只统计**状态真的被判定过**的会话。
    //
    // 判据不能只看 `perceptionMode === PERCEPTION_FULL` —— 那个字段表示"开了**摄像头**感知"，
    // 而无摄像头的环境里状态判定来自模拟状态控制台（同样会落状态事件），
    // 一律排除会让抗干扰永远是"—"（用户反馈"抗干扰直接不见了"）。
    // 反过来，纯计时的会话里 `distractionDuration` 恒为 0，混进来会把"无数据"误算成"满分"，
    // 所以仍然要排除 —— 用"本次有没有产生过状态事件"来区分这两者。
    const perceptionSessions = finished.filter((s: FocusSession): boolean =>
      s.perceptionMode === PerceptionMode.PERCEPTION_FULL || s.events.length > 0)
    const distrs: number[] = perceptionSessions.map((s: FocusSession): number => Metrics.distractionRate(s))
    const avgDistr = distrs.length > 0 ? Metrics.mean(distrs) : 0

    const concentration = Math.round(weightedRate)
    // 效率 = 专注率 + 执行力 加权。**没有任务清单时不把执行力当成 0 扣分** ——
    // 那会把"自由专注、没设任务"的人压到专注率的六成，与上面"自由专注不拉低执行力"的口径
    // 自相矛盾（同一个缺数据，一处豁免、一处扣 40 分）。无执行力数据时权重归一到专注率。
    const efficiency = taskSessions.length > 0
      ? Math.round(0.6 * weightedRate + 0.4 * execution)
      : Math.round(weightedRate)
    const stability = sigma > 0.3 ? 0 : Math.round(100 * (1 - Metrics.clamp(sigma / 0.4, 0, 1)))
    const antiDistraction = Math.round(100 * (1 - Metrics.clamp(avgDistr, 0, 1)))
    return { efficiency, concentration, stability, execution, antiDistraction,
      perceptionCount: perceptionSessions.length, taskCount: taskSessions.length }
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
    let totalDistSec = 0
    const completedIds: string[] = []
    const trend: number[] = []

    // 每日「专注度」（100 分制）：当天多次专注就取各次专注度的**平均值**，没学就是 0。
    // 之前这里是「当天净专注分钟数」，纵轴单位是分钟；现在统一成百分比，纵轴 0~100。
    //
    // 同时记录**每日权重 = 当天净专注时长（秒）**：总体「专注率」不再是"30 天一把抓"的
    // 净专注/已判定，而是**「单日专注率」按当天专注时长加权求平均**（用户明确口径）。
    // 这样 1 分钟的会话与 2 小时的会话不会被同等对待（各次的算术平均会把短会话放大）。
    const dayRates: number[] = []
    const dayWeights: number[] = []
    for (let i = 29; i >= 0; i--) {
      const dayStart = TimeUtils.dayStart(now) - i * dayMs
      const dayEnd = dayStart + dayMs
      let rateSum = 0
      let count = 0
      let dayNet = 0
      for (const s of sessions) {
        if (s.startTime >= dayStart && s.startTime < dayEnd) {
          rateSum += Metrics.focusRatePercent(s)
          count += 1
          dayNet += Metrics.netFocusSec(s)
        }
      }
      const dayRate = count > 0 ? Math.round(rateSum / count) : 0
      trend.push(dayRate)
      dayRates.push(dayRate)
      dayWeights.push(dayNet)
    }

    for (const s of sessions) {
      if (s.startTime >= cutoff) {
        totalNetSec += s.focusDuration
        totalStudySec += Metrics.totalStudySec(s)
        totalDistSec += s.distractionDuration
        for (const id of s.completedTaskIds) {
          if (completedIds.indexOf(id) < 0) {
            completedIds.push(id)
          }
        }
      }
    }

    // 「完成」按**近 30 天**口径统计：会话里完成过的 ∪ 近 30 天内创建且已勾选的。
    // 只用会话会漏掉"在首页 / 复盘直接勾选"的那种完成（它不会进任何会话的 completedTaskIds）；
    // 只用任务表又会把 30 天前的旧勾选也算进来。取并集才与卡片标题的「近 30 天」相符。
    const counted: string[] = completedIds.slice()
    for (const t of tasks) {
      if ((t.done || t.status === TaskStatus.DONE) && t.createdAt >= cutoff
        && counted.indexOf(t.id) < 0) {
        counted.push(t.id)
      }
    }

    // 总体专注率 = Σ(单日专注率 × 当天专注时长) / Σ(当天专注时长)
    // 权重 = 当天净专注秒数；当天无专注（权重 0，含"没学"那天）不参与，分母为 0 时如实给 0。
    let wRateSum = 0
    let wSum = 0
    for (let i = 0; i < dayRates.length; i++) {
      wRateSum += dayRates[i] * dayWeights[i]
      wSum += dayWeights[i]
    }
    const focusRate = wSum > 0 ? Math.round(wRateSum / wSum) : 0
    return { totalHours: Math.round(totalNetSec / 3600), totalNetSeconds: totalNetSec,
      completedTasks: counted.length, focusRate: focusRate, trend: trend }
  }

  // ===================== 长期计划目标进度（§4）=====================
  //
  // 口径说明（用户抱怨"这个进度没有依据"，根因是语义没定义）：
  //  - **分母** = 本期计划各科目标之和（不含"未分配"的旧总额）；
  //  - **主分子（口径 B）** = 任务的实际投入 `actualDuration`（由专注计时自动累计，**不需要用户打钩**）；
  //  - 辅分子（口径 A） = 勾选完成任务的"预计时长"之和；
  //  - 未分类 / 未归属任务**只展示投入与条数，不给百分比** —— 分母里没有它们，给百分比就是伪造。
  //
  // 本函数保持纯函数：任务集与计划都由调用方组装，这里**不读存储**（硬规则 §3）。

  /**
   * 长期计划的目标进度。
   * @param tasks 全量任务（内部按 `planId` 过滤出本期任务集，并按 id 去重）
   * @param plan 长期计划；`null` = 还没设置 → 返回 `NO_PLAN`
   */
  static planProgress(tasks: Task[], plan: StudyPlan | null): PlanProgress {
    const subjects: SubjectProgressRow[] = []
    if (plan === null) {
      return {
        planTitle: '',
        targetMinutes: 0,
        doneEstimatedMinutes: 0,
        actualMinutes: 0,
        completedPercent: 0,
        investedPercent: 0,
        overdueMinutes: 0,
        unassignedActualMinutes: 0,
        unassignedTasks: 0,
        unassignedTargetMinutes: 0,
        state: 'NO_PLAN',
        subjects: subjects
      }
    }
    const unassignedTarget = StudyPlan.unassignedMinutes(plan)
    // 本期任务集：归属本计划 + 按 id 去重
    const picked: Task[] = []
    const seen: string[] = []
    for (const t of tasks) {
      if (t.planId !== plan.id || seen.indexOf(t.id) >= 0) {
        continue
      }
      seen.push(t.id)
      picked.push(t)
    }

    let doneEst = 0
    let actual = 0
    for (const st of plan.subjectTargets) {
      if (st.subject.length === 0) {
        continue
      }
      let doneEstS = 0
      let actualS = 0
      let totalS = 0
      let doneS = 0
      for (const t of picked) {
        if (t.subject !== st.subject) {
          continue
        }
        totalS++
        if (t.done) {
          doneS++
          doneEstS += t.estimatedDuration
        }
        actualS += t.actualDuration
      }
      doneEst += doneEstS
      actual += actualS
      const actualMin = Math.round(actualS / 60)
      let stState = 'OK'
      if (st.targetMinutes <= 0) {
        stState = 'NO_TARGET'
      } else if (totalS === 0) {
        stState = 'NO_TASK'
      } else if (actualMin > st.targetMinutes) {
        stState = 'OVER'
      }
      subjects.push({
        subject: st.subject,
        targetMinutes: st.targetMinutes,
        doneEstimatedMinutes: doneEstS,
        actualMinutes: actualMin,
        totalTasks: totalS,
        doneTasks: doneS,
        state: stState
      })
    }

    // 未分类 / 未归属：只统计，不给百分比
    let unassignedActual = 0
    let unassignedCount = 0
    for (const t of picked) {
      let matched = false
      for (const st of plan.subjectTargets) {
        if (st.subject.length > 0 && st.subject === t.subject) {
          matched = true
          break
        }
      }
      if (!matched) {
        unassignedActual += t.actualDuration
        unassignedCount++
      }
    }

    const targetMinutes = StudyPlan.assignedMinutes(plan)
    const actualMin = Math.round(actual / 60)
    const doneEstMin = doneEst
    const investedPercent = targetMinutes > 0 ? Math.min(100, Math.round(actualMin / targetMinutes * 100)) : 0
    const completedPercent = targetMinutes > 0 ? Math.min(100, Math.round(doneEstMin / targetMinutes * 100)) : 0
    const overdue = actualMin > targetMinutes ? actualMin - targetMinutes : 0
    let state = 'OK'
    if (targetMinutes <= 0) {
      state = 'NO_TARGET'
    } else if (picked.length === 0) {
      state = 'NO_TASK'
    } else if (overdue > 0) {
      state = 'OVER'
    }
    return {
      planTitle: plan.title,
      targetMinutes: targetMinutes,
      doneEstimatedMinutes: doneEstMin,
      actualMinutes: actualMin,
      completedPercent: completedPercent,
      investedPercent: investedPercent,
      overdueMinutes: overdue,
      unassignedActualMinutes: Math.round(unassignedActual / 60),
      unassignedTasks: unassignedCount,
      unassignedTargetMinutes: unassignedTarget,
      state: state,
      subjects: subjects
    }
  }

  /**
   * 单日学习总结：汇总某一天（dayStart 起 24h 内）全部专注会话。
   * 学习时长 / 专注率 / 任务完成 / 答疑 / 最佳时段 / 当日专注曲线，
   * 全部走统一口径，页面不得自行计算（硬规则 §3）。
   *
   * **所有数字都是"当天累计"**（用户明确要求）：
   *  - 学习时长 = 当天各次会话 `totalStudySec` 之和（墙钟 − 休息 − 暂停，含答疑）；
   *  - 专注率 = **按"已判定学习时长"加权的平均**：Σ净专注 / Σ(净专注 + 分心)。
   *    分母刻意不含答疑（与单次会话、与专注曲线色带同一口径）。
   *    不能对每次会话的专注率直接取算术平均 —— 那样 3 分钟那次和 60 分钟那次一样重，
   *    数字会飘；
   *  - 任务完成 = **按任务 id 去重**后计数：同一条任务跨多次会话出现只算一次，
   *    否则"今天 3 个任务"会被算成 3×次数的假分母；
   *  - 答疑 = 当天累计时长（分钟）+ 有过答疑的会话数。
   *
   * @param todayTasks 当所选日期**就是今天**时，调用方传当天计划（`AppStore.todayTasks()`）：
   *   首页勾选完成的任务不属于任何会话，只统计会话会漏掉它们；
   *   传进来后「任务完成」与首页「今日数据」完全一致。
   *   历史日期没有这份信息，传空数组即可，退回按当天会话去重统计。
   */
  static daySummary(sessions: FocusSession[], dayStart: number, todayTasks: Task[]): DaySummary {
    const dayEnd = dayStart + 24 * 3600 * 1000
    const daySessions: FocusSession[] = []
    for (const s of sessions) {
      if (s.startTime >= dayStart && s.startTime < dayEnd) {
        daySessions.push(s)
      }
    }

    let netSec = 0
    let distractSec = 0
    let studySec = 0
    let qaSec = 0
    // 任务去重：当天多次会话里出现的同一条任务只算一次
    const seenTaskIds: string[] = []
    const seenDoneIds: string[] = []

    for (const s of daySessions) {
      netSec += s.focusDuration
      distractSec += s.distractionDuration
      studySec += Metrics.totalStudySec(s)
      qaSec += Metrics.qaSec(s)
      for (const id of s.taskIds) {
        if (seenTaskIds.indexOf(id) < 0) {
          seenTaskIds.push(id)
        }
      }
      for (const id of s.completedTaskIds) {
        if (seenDoneIds.indexOf(id) < 0) {
          seenDoneIds.push(id)
        }
        // 完成过但没出现在 taskIds 里的（历史数据/自由专注里勾选的）也要计入分母，
        // 否则会出现「完成 3 / 共 1」这种自相矛盾的数
        if (seenTaskIds.indexOf(id) < 0) {
          seenTaskIds.push(id)
        }
      }
    }

    // 平均专注率 = Σ净专注 / Σ(净专注 + 分心)，即"按除答疑时长加权"的平均值。
    // 变量名避开 `judgedSec`（那是本类的静态方法名），免得读代码时混淆
    const dayJudged = netSec + distractSec
    const focusRate = dayJudged > 0 ? Math.round(netSec / dayJudged * 100) : 0

    // 任务完成：今天用当天计划（与首页「今日数据」一致），历史日期退回会话去重统计
    let done = 0
    let total = 0
    if (todayTasks.length > 0) {
      total = todayTasks.length
      for (const t of todayTasks) {
        if (t.done || t.status === TaskStatus.DONE) {
          done += 1
        }
      }
    } else {
      total = seenTaskIds.length
      done = seenDoneIds.length
    }
    // 只看这一天自己的 timeline —— 不再复用 goldenWindow（它按 2 小时桶统计、还硬过滤最近 14 天，
    // 看 14 天以前任意一天时恒为空，页面只能回退成一句没有时间的空话）
    const best = Metrics.bestPeriodOfDay(daySessions, dayStart)
    return {
      hasData: daySessions.length > 0,
      studySeconds: studySec,
      focusRate: focusRate,
      completedTasks: done,
      totalTasks: total,
      qaSeconds: qaSec,
      sessionCount: daySessions.length,
      bestPeriod: best,
      structure: Metrics.primarySessionStructure(daySessions),
    }
  }

  /**
   * 单次会话的结构指标（纯函数，只看这一场自己的 timeline）。
   *
   * 采样间隔 = `FocusTuning.TIMELINE_SAMPLE_MS`（30 s）。注意状态切换时会**额外补采**一个点，
   * 所以连续采样点在时间上并不严格等距 —— "最长连续段"按**采样点数 × 采样间隔**估算，
   * 这是本函数唯一的近似，宁可能用、也没有编造。
   */
  static sessionStructure(s: FocusSession): SessionStructure {
    const stepMin = FocusTuning.TIMELINE_SAMPLE_MS / 60000
    const n = s.timeline.length
    if (n === 0) {
      return { timeToFocus: -1, longestRun: 0, bouts: 0, recoveryMedian: -1, deepRatio: 0, tailDrop: 0 }
    }
    let timeToFocus = -1
    let run = 0
    let longest = 0
    let bouts = 0
    let deepCount = 0
    /** 最近一次"从专注掉出去"的采样点索引；< 0 = 当前没在等待恢复 */
    let fellAt = -1
    const recoveries: number[] = []
    const levels: number[] = []
    for (let i = 0; i < n; i++) {
      const p = s.timeline[i]
      levels.push(p.level)
      if (p.level >= 80) {
        deepCount++
      }
      if (p.state === 'FOCUSED') {
        if (timeToFocus < 0) {
          timeToFocus = p.minute
        }
        run++
        if (run > longest) {
          longest = run
        }
        if (fellAt >= 0) {
          recoveries.push((i - fellAt) * stepMin)
          fellAt = -1
        }
      } else {
        if (run > 0) {
          bouts++
          fellAt = i
        }
        run = 0
      }
    }
    // 疲劳拐点：后 1/3 与前 1/3 的平均 level 之差（比"第一个 level<45"稳得多）
    const third = Math.floor(n / 3)
    let tailDrop = 0
    if (third > 0) {
      let head = 0
      for (let i = 0; i < third; i++) {
        head += levels[i]
      }
      let tail = 0
      for (let i = n - third; i < n; i++) {
        tail += levels[i]
      }
      tailDrop = Math.round(tail / third - head / third)
    }
    let deepRatio = Math.round(deepCount / n * 100) / 100
    return {
      timeToFocus: timeToFocus,
      longestRun: Math.round(longest * stepMin),
      bouts: bouts,
      recoveryMedian: Metrics.median(recoveries),
      deepRatio: deepRatio,
      tailDrop: tailDrop
    }
  }

  /**
   * 当天"主会话"的结构指标 = 总学习时长最长的那一次；当天没有会话时返回空结构。
   * 单日洞察讲的是"这一天"，但结构量（进入状态耗时、被打断后多久回来）只能按**单次会话**算，
   * 所以取最长的那一次作为代表，并在文案里写明"当天最长的一次"。
   */
  static primarySessionStructure(daySessions: FocusSession[]): SessionStructure {
    let main: FocusSession | null = null
    let mainSec = -1
    for (const s of daySessions) {
      const sec = Metrics.totalStudySec(s)
      if (sec > mainSec) {
        mainSec = sec
        main = s
      }
    }
    if (main === null) {
      return { timeToFocus: -1, longestRun: 0, bouts: 0, recoveryMedian: -1, deepRatio: 0, tailDrop: 0 }
    }
    return Metrics.sessionStructure(main)
  }

  /**
   * 本人基线：近 7 天（不达标扩到近 30 天）**排除当天**的结构指标中位数 + 净专注率中位数。
   * 窗口与门槛见 D7；不达标时 `ready = false` 并给出"还差几次会话"，调用方据此只报当天事实。
   */
  static baseline(sessions: FocusSession[], excludeSessionId: string, now: number): Baseline {
    const todayStart = TimeUtils.dayStart(now)
    let picked: FocusSession[] = []
    let windowDays = 0
    const windows: number[] = [7, 30]
    for (const days of windows) {
      const since = todayStart - days * 24 * 3600 * 1000
      const list: FocusSession[] = []
      let studySec = 0
      for (const s of sessions) {
        // 排除当次与当天，并限定窗口
        if (s.id === excludeSessionId || s.startTime < since || s.startTime >= todayStart) {
          continue
        }
        list.push(s)
        studySec += Metrics.totalStudySec(s)
      }
      picked = list
      if (list.length >= Metrics.MIN_SAMPLES && studySec >= 60 * 60) {
        windowDays = days
        break
      }
    }
    const timeToFocusArr: number[] = []
    const longestArr: number[] = []
    const boutsArr: number[] = []
    const recoveryArr: number[] = []
    const deepArr: number[] = []
    const rateArr: number[] = []
    for (const s of picked) {
      const st = Metrics.sessionStructure(s)
      if (st.timeToFocus >= 0) {
        timeToFocusArr.push(st.timeToFocus)
      }
      longestArr.push(st.longestRun)
      boutsArr.push(st.bouts)
      if (st.recoveryMedian >= 0) {
        recoveryArr.push(st.recoveryMedian)
      }
      deepArr.push(st.deepRatio)
      rateArr.push(Metrics.focusRatePercent(s))
    }
    const need = Metrics.MIN_SAMPLES - picked.length
    return {
      ready: windowDays > 0,
      needMore: need > 0 ? need : 1,
      sampleCount: picked.length,
      windowDays: windowDays,
      timeToFocus: Metrics.median(timeToFocusArr),
      longestRun: Metrics.median(longestArr),
      bouts: Metrics.median(boutsArr),
      recoveryMedian: Metrics.median(recoveryArr),
      deepRatio: Metrics.median(deepArr),
      netFocusRate: Metrics.median(rateArr)
    }
  }

  /**
   * 当天最佳时段：当天**平均专注等级最高的那一段连续专注**，换算成真实时钟返回
   * （形如 `09:30–09:52`）。
   *
   * 与 `goldenWindow` 的分工：后者是"按 2 小时桶统计高峰时段、且硬过滤最近 14 天"，
   * 用于画像等长期场景；本函数只看指定这一天自己的 timeline，因此**任何一天都能给出结论**，
   * 不会再出现"看 14 天前那天时恒为空"。
   */
  static bestPeriodOfDay(daySessions: FocusSession[], dayStart: number): string {
    if (daySessions.length === 0) {
      return ''
    }
    // 先找 ≥10 分钟的段（有代表性）；整体都很短时放宽到任意长度 ——
    // 宁可给一段短的，也不要给"没有时间"的空话
    const minMinutesList: number[] = [10, 0]
    for (const minMinutes of minMinutesList) {
      let bestClock = ''
      let bestAvg = -1
      let bestLen = 0
      for (const s of daySessions) {
        const run = Metrics.bestFocusedRun(s, minMinutes)
        if (run.length === 0) {
          continue
        }
        const avg = run[2]
        const len = run[1] - run[0]
        if (avg > bestAvg || (avg === bestAvg && len > bestLen)) {
          bestAvg = avg
          bestLen = len
          const from = Metrics.clockAtSample(s, run[0])
          const to = Metrics.clockAtSample(s, run[1] + 1)
          bestClock = `${Metrics.clock(from)}–${Metrics.clock(to)}`
        }
      }
      if (bestClock.length > 0) {
        return bestClock
      }
    }
    return ''
  }

  /**
   * 会话内"平均 level 最高的一段连续专注"。
   * @returns `[起始采样索引, 结束采样索引, 平均 level]`；没有满足长度要求的段时返回 `[]`
   */
  private static bestFocusedRun(s: FocusSession, minMinutes: number): number[] {
    const stepMin = FocusTuning.TIMELINE_SAMPLE_MS / 60000
    const n = s.timeline.length
    let bestStart = -1
    let bestEnd = -1
    let bestAvg = -1
    let start = -1
    let sum = 0
    let count = 0
    // i == n 时视为"非专注"，用来收尾最后一段
    for (let i = 0; i <= n; i++) {
      const focused = i < n && s.timeline[i].state === 'FOCUSED'
      if (focused) {
        if (start < 0) {
          start = i
          sum = 0
          count = 0
        }
        sum += s.timeline[i].level
        count++
        continue
      }
      if (start >= 0) {
        const end = i - 1
        const lenMin = (end - start + 1) * stepMin
        if (lenMin >= minMinutes) {
          const avg = sum / count
          if (avg > bestAvg || (avg === bestAvg && (end - start) > (bestEnd - bestStart))) {
            bestAvg = avg
            bestStart = start
            bestEnd = end
          }
        }
        start = -1
        sum = 0
        count = 0
      }
    }
    if (bestStart < 0) {
      return []
    }
    return [bestStart, bestEnd, bestAvg]
  }

  /** 采样点索引 → 该时刻的"当天分钟数"（用会话真实起始时间推算，不是累计学习分钟） */
  private static clockAtSample(s: FocusSession, index: number): number {
    const stepMin = FocusTuning.TIMELINE_SAMPLE_MS / 60000
    const d = new Date(s.startTime + index * stepMin * 60000)
    return d.getHours() * 60 + d.getMinutes()
  }

  /**
   * 中位数；**空数组返回 -1**（调用方据此判断"没有样本"——例如"整场都没恢复过一次专注"）。
   * 保留一位小数。调用方要么先确认非空，要么把 -1 当成"无数据"处理。
   */
  private static median(values: number[]): number {
    if (values.length === 0) {
      return -1
    }
    const sorted = values.slice()
    sorted.sort((a: number, b: number): number => a - b)
    const mid = Math.floor(sorted.length / 2)
    if (sorted.length % 2 === 1) {
      return Math.round(sorted[mid] * 10) / 10
    }
    return Math.round((sorted[mid - 1] + sorted[mid]) / 2 * 10) / 10
  }

  /** 科目名的统一口径：空 → 「未标注科目」。卡片与明细页必须同口径，否则两处分组对不上 */
  private static subjectName(raw: string): string {
    return raw.trim().length > 0 ? raw.trim() : '未标注科目'
  }

  /**
   * 练习明细：列出所有被完成过的任务（供「练习内容总结 → 查看全部」）。
   *
   * 口径**必须与 `practiceSummary` 一致**，否则会出现"卡片写「数学 3 次」、点进去只有 1 项"：
   *  - ① 会话里完成过的任务（有会话时间）；
   *  - ② 任务表里已打勾、但没进过任何会话的（在首页 / 复盘直接勾选的那种）。
   *
   * 排序：**完成次数降序**（用户要求）→ 同次数按最近完成时间降序。
   * `lastDoneMs = 0` 表示只有勾选、没有会话时间，展示层据此只写次数、不写日期。
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
        const name = Metrics.subjectName(t.subject)
        const key = `${name}|${id}`
        const exist = map.get(key)
        if (exist === undefined) {
          map.set(key, {
            subject: name,
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
    // ② 只打过勾、没进过会话的（口径对齐 practiceSummary，别让它们凭空消失）
    for (const t of tasks) {
      if (!(t.done || t.status === TaskStatus.DONE)) {
        continue
      }
      const name = Metrics.subjectName(t.subject)
      const key = `${name}|${t.id}`
      if (map.get(key) === undefined) {
        map.set(key, { subject: name, title: t.title, lastDoneMs: 0, times: 1 })
      }
    }
    const list: PracticeDetailItem[] = []
    map.forEach((v: PracticeDetailItem) => {
      list.push(v)
    })
    list.sort((a: PracticeDetailItem, b: PracticeDetailItem): number => {
      if (b.times !== a.times) {
        return b.times - a.times
      }
      return b.lastDoneMs - a.lastDoneMs
    })
    return list
  }

  /** 归一化：去掉空白与常见标点，只用于"判断是不是同一项练习"，不改展示文案 */
/** 练习内容总结的一项：某科目**一共完成了几个任务** */
  /**
   * 一次会话涉及的**全部科目**（去重，保持任务在 `taskIds` 里的先后）。
   *
   * 为什么需要：学习记录列表原来只显示 `session.title`，那是"**主要任务**"的标题 ——
   * 一次专注里先做数学、再做英语，列表里也只写一个，用户会觉得"莫名只给一个科目"。
   * 现在按会话的 `taskIds` 找回各任务的 `subject`，拼成「数学·英语」。
   * 空科目归到「未标注科目」，不让它悄悄消失；`subject` 为空的会话返回空数组。
   */
  static sessionSubjects(s: FocusSession, tasks: Task[]): string[] {
    const map = new Map<string, string>()
    for (const t of tasks) {
      map.set(t.id, t.subject)
    }
    const out: string[] = []
    for (const id of s.taskIds) {
      const raw = map.get(id)
      if (raw === undefined) {
        continue
      }
      const name = raw.trim().length > 0 ? raw.trim() : '未标注科目'
      if (out.indexOf(name) < 0) {
        out.push(name)
      }
    }
    return out
  }

  /**
   * 一次会话的**科目标签**（列表里直接显示的那一串）：
   *  • 有科目 → 用「·」连接，如「数学·英语」；
   *  • 没有挂任务（自由专注）→ 退回 `session.title`，标题也为空就写「自由专注」。
   *
   * 学习记录列表与复盘「当日专注明细」共用这一个方法，避免两处各写一遍 fallback。
   */
  static sessionSubjectLabel(s: FocusSession, tasks: Task[]): string {
    const subs = Metrics.sessionSubjects(s, tasks)
    if (subs.length > 0) {
      return subs.join('·')
    }
    return s.title.length > 0 ? s.title : '自由专注'
  }

  /**
   * 练习内容总结：**按科目统计"一共完成了几个任务"**。
   *
   * 用户明确的口径：「数学 2 次」这种，**不需要把每条任务逐条罗列**
   * （逐条既长、又看不出每个科目实际投入了多少）。
   * 次数 = 该科目下**已完成**的任务数，按次数降序。
   *
   * 数据源必须与「任务进度」是同一份（调用方传 `AppStore.mergedTasks()`）——
   * 否则会出现"任务进度 7/7，这里只统计到 5 个"这种对不上的情况（实测反馈过）。
   */
  static practiceSummary(sessions: FocusSession[], tasks: Task[]): PracticeSummaryItem[] {
    const taskMap = new Map<string, Task>()
    for (const t of tasks) {
      taskMap.set(t.id, t)
    }
    // 同一个任务可能跨多个会话被标记完成，按任务 id 去重，避免次数被重复放大
    const counted = new Set<string>()
    const doneSubjects: string[] = []

    // ① 会话里完成过的
    for (const s of sessions) {
      for (const id of s.completedTaskIds) {
        const t = taskMap.get(id)
        if (t !== undefined && !counted.has(t.id)) {
          counted.add(t.id)
          doneSubjects.push(t.subject)
        }
      }
    }
    // ② 任务表里已经打勾的也算"练过"。
    // 为什么必须补这一步：复盘页「未完成清单」和首页今日任务都能直接勾选完成，
    // 那种勾选**不会**进任何会话的 completedTaskIds —— 只统计会话的话，
    // 用户勾完任务，这里的「练习内容总结」纹丝不动，看着就像没生效。
    for (const t of tasks) {
      if ((t.done || t.status === TaskStatus.DONE) && !counted.has(t.id)) {
        counted.add(t.id)
        doneSubjects.push(t.subject)
      }
    }

    // 按科目聚合计数（科目为空时归到「未标注科目」，不让它悄悄消失）
    const out: PracticeSummaryItem[] = []
    for (const raw of doneSubjects) {
      const name = Metrics.subjectName(raw)
      let hit = false
      for (const it of out) {
        if (it.subject === name) {
          it.count += 1
          hit = true
          break
        }
      }
      if (!hit) {
        out.push({ subject: name, count: 1 })
      }
    }
    out.sort((a: PracticeSummaryItem, b: PracticeSummaryItem): number => b.count - a.count)
    return out.slice(0, 8)
  }

  /**
   * 学习习惯洞察（**近 30 天**）：高效时段、低谷时段与可操作建议。
   *
   * 四条口径（都是上一版踩过的坑）：
   *  1. **1 小时桶（24 档）**：2 小时桶全天只有 12 档，"08:00–10:00" 必然反复出现；
   *  2. **按专注率选峰/选谷**，不是按"学得久" —— 时长只当门槛，否则"学得久"被当成"效率高"；
   *  3. 资格门槛（D7）：桶内 **≥2 次会话 且 累计总学习 ≥20 分钟**；资格桶不足时不下结论；
   *  4. 落差门槛：`bestRate - lowRate ≥ 8` 个百分点才区分高峰/低谷，否则输出"各时段差别不大"
   *     —— 这同时修掉了旧实现的 `bestWindow === lowWindow` 自相矛盾（多个桶时长相等时会出现）。
   * 窗口固定近 30 天并在文案里写明（此前传全量 sessions，一次成型后几乎不再变化）。
   */
  static habitInsights(sessions: FocusSession[]): HabitInsight {
    const since = TimeUtils.dayStart(Date.now()) - 29 * 24 * 3600 * 1000
    const bucketsStudy = new Array<number>(24).fill(0)
    const bucketsNet = new Array<number>(24).fill(0)
    const bucketsCount = new Array<number>(24).fill(0)
    for (const s of sessions) {
      if (s.startTime < since) {
        continue
      }
      const study = Metrics.totalStudySec(s)
      if (study <= 0) {
        continue
      }
      const idx = new Date(s.startTime).getHours()
      if (idx < 0 || idx >= 24) {
        continue
      }
      bucketsStudy[idx] += study
      bucketsNet[idx] += Metrics.netFocusSec(s)
      bucketsCount[idx] += 1
    }
    // 一行概览：最常学的两个时段（不管有没有出结论都给，界面因此不会一片空白）
    const topSummary = Metrics.topWindowSummary(bucketsCount, bucketsStudy)
    // 资格桶：会话数与时长的门槛都过，才有资格参与评比
    const qualified: number[] = []
    for (let i = 0; i < 24; i++) {
      if (bucketsCount[i] >= Metrics.HABIT_MIN_SESSIONS && bucketsStudy[i] >= Metrics.HABIT_MIN_STUDY_SEC) {
        qualified.push(i)
      }
    }
    if (qualified.length === 0) {
      return {
        bestWindow: '',
        bestRate: 0,
        lowWindow: '',
        lowNote: '',
        advice: '',
        topSummary: topSummary,
        gateNote: Metrics.habitGateNote(bucketsCount, bucketsStudy)
      }
    }
    let peak = qualified[0]
    let low = qualified[0]
    for (const i of qualified) {
      const r = Metrics.bucketRate(bucketsStudy[i], bucketsNet[i])
      if (r > Metrics.bucketRate(bucketsStudy[peak], bucketsNet[peak])) {
        peak = i
      }
      if (r < Metrics.bucketRate(bucketsStudy[low], bucketsNet[low])) {
        low = i
      }
    }
    const bestWindow = Metrics.hourWindow(peak)
    const bestRate = Metrics.bucketRate(bucketsStudy[peak], bucketsNet[peak])
    const bestStudyMin = Math.round(bucketsStudy[peak] / 60)
    if (qualified.length === 1) {
      return {
        bestWindow: bestWindow,
        bestRate: bestRate,
        lowWindow: '',
        lowNote: '',
        advice: `近 30 天里只有 ${bestWindow} 这一个时段达到统计门槛（专注率 ${bestRate}%，累计 ${bestStudyMin} 分钟）。` +
          '再多几个时段、每段至少 2 次专注，我才能比较出低谷。',
        topSummary: topSummary,
        gateNote: ''
      }
    }
    const lowWindow = Metrics.hourWindow(low)
    const lowRate = Metrics.bucketRate(bucketsStudy[low], bucketsNet[low])
    const gap = bestRate - lowRate
    if (gap < Metrics.HABIT_RATE_GAP) {
      return {
        bestWindow: '',
        bestRate: 0,
        lowWindow: '',
        lowNote: '',
        advice: `近 30 天各时段的专注率差别不大（最高 ${bestRate}% 与最低 ${lowRate}% 只差 ${gap} 个百分点，` +
          `不到 ${Metrics.HABIT_RATE_GAP} 个百分点），所以不区分高峰与低谷。`,
        topSummary: topSummary,
        gateNote: ''
      }
    }
    return {
      bestWindow: bestWindow,
      bestRate: bestRate,
      lowWindow: lowWindow,
      lowNote: lowRate + 10 < bestRate ? '容易分心' : '投入偏少',
      advice: `近 30 天的高效时段是 ${bestWindow}（专注率 ${bestRate}%，累计 ${bestStudyMin} 分钟）；` +
        `${lowWindow} 偏低（专注率 ${lowRate}%）。建议把需要深度思考的任务放在 ${bestWindow}，` +
        `${lowWindow} 留给复习与轻量整理。`,
      topSummary: topSummary,
      gateNote: ''
    }
  }

  /** 第 i 个小时桶的时钟区间（23 点那一桶的右端点回到 00:00） */
  private static hourWindow(i: number): string {
    return `${Metrics.clock(i * 60)} - ${Metrics.clock(i * 60 + 60)}`
  }

  /**
   * 一行概览"最常学的时段"：按累计学习时长排序取前 2 个，形如
   * `20:00 - 21:00（3 次 · 45 分钟）、21:00 - 22:00（2 次 · 20 分钟）`。
   *
   * 只给概览、不铺表：这一块是"洞察"，重点在结论；逐时段铺开最多 24 行，
   * 数字会把结论淹掉。没有学习记录时返回空串。
   */
  private static topWindowSummary(counts: number[], study: number[]): string {
    const idxs: number[] = []
    for (let i = 0; i < 24; i++) {
      if (counts[i] > 0 && study[i] > 0) {
        idxs.push(i)
      }
    }
    idxs.sort((a: number, b: number): number => study[b] - study[a])
    const parts: string[] = []
    const n = Math.min(2, idxs.length)
    for (let k = 0; k < n; k++) {
      const i = idxs[k]
      parts.push(`${Metrics.hourWindow(i)}（${counts[i]} 次 · ${Math.round(study[i] / 60)} 分钟）`)
    }
    return parts.join('、')
  }

  /**
   * 还没到评比门槛时的说明：挑**最接近门槛**的时段，说清还差几次 / 几分钟。
   *
   * 不在这里给高峰低谷的结论 —— 样本不足就只报事实，这与其他模块的口径一致
   *（例如专注画像样本不够时显示"还在了解你"，不硬给结论）。
   */
  private static habitGateNote(counts: number[], study: number[]): string {
    let best = -1
    let bestProgress = -1
    for (let i = 0; i < 24; i++) {
      if (counts[i] === 0 || study[i] <= 0) {
        continue
      }
      // 两个条件各自的完成度相加，取最接近的那个时段
      const p = Math.min(counts[i], Metrics.HABIT_MIN_SESSIONS) / Metrics.HABIT_MIN_SESSIONS
        + Math.min(study[i], Metrics.HABIT_MIN_STUDY_SEC) / Metrics.HABIT_MIN_STUDY_SEC
      if (p > bestProgress) {
        bestProgress = p
        best = i
      }
    }
    if (best < 0) {
      return ''
    }
    const window = Metrics.hourWindow(best)
    const needSessions = Math.max(0, Metrics.HABIT_MIN_SESSIONS - counts[best])
    const needMinutes = Math.max(0, Math.ceil((Metrics.HABIT_MIN_STUDY_SEC - study[best]) / 60))
    if (needSessions > 0 && needMinutes > 0) {
      return `最接近门槛的是 ${window}：再完成 ${needSessions} 次专注、并把该时段累计到 `
        + `${Math.round(Metrics.HABIT_MIN_STUDY_SEC / 60)} 分钟，就能给出高峰与低谷。`
    }
    if (needSessions > 0) {
      return `最接近门槛的是 ${window}：再完成 ${needSessions} 次专注就够了。`
    }
    return `最接近门槛的是 ${window}：该时段再累计 ${needMinutes} 分钟就够了。`
  }

  /**
   * 近 7 天 vs 前 7 天：净专注率与日均净专注分钟。
   * 变化幅度 ≥10% 才说"上升/下降"，否则"基本持平" —— 避免把随机波动说成趋势。
   */
  static trend7v7(sessions: FocusSession[], now: number): Trend7v7 {
    const dayMs = 24 * 3600 * 1000
    const todayStart = TimeUtils.dayStart(now)
    const curStart = todayStart - 6 * dayMs
    const prevStart = curStart - 7 * dayMs
    let curNet = 0
    let curStudy = 0
    let prevNet = 0
    let prevStudy = 0
    for (const s of sessions) {
      if (s.startTime >= curStart && s.startTime <= now) {
        curNet += Metrics.netFocusSec(s)
        curStudy += Metrics.totalStudySec(s)
      } else if (s.startTime >= prevStart && s.startTime < curStart) {
        prevNet += Metrics.netFocusSec(s)
        prevStudy += Metrics.totalStudySec(s)
      }
    }
    const curRate = Metrics.bucketRate(curStudy, curNet)
    const prevRate = Metrics.bucketRate(prevStudy, prevNet)
    const curAvg = Math.round(curNet / 60 / 7)
    const prevAvg = Math.round(prevNet / 60 / 7)
    return {
      ready: curStudy > 0 && prevStudy > 0,
      curRate: curRate,
      prevRate: prevRate,
      rateTrend: Metrics.trendWord(curRate, prevRate),
      curAvgMinutes: curAvg,
      prevAvgMinutes: prevAvg,
      avgTrend: Metrics.trendWord(curAvg, prevAvg)
    }
  }

  /** 连续学习天数（含今天；今天还没学则从昨天起算）与近 30 天最长空档 */
  static streaks(sessions: FocusSession[], now: number): Streaks {
    const dayMs = 24 * 3600 * 1000
    const todayStart = TimeUtils.dayStart(now)
    /** 索引 = 距今天数（0 = 今天），窗口 31 天 */
    const has: boolean[] = new Array<boolean>(31).fill(false)
    for (const s of sessions) {
      if (Metrics.totalStudySec(s) <= 0) {
        continue
      }
      const back = Math.round((todayStart - TimeUtils.dayStart(s.startTime)) / dayMs)
      if (back >= 0 && back <= 30) {
        has[back] = true
      }
    }
    let currentStreak = 0
    let i = has[0] ? 0 : 1
    while (i <= 30 && has[i]) {
      currentStreak++
      i++
    }
    let longestGap = 0
    let run = 0
    let studiedDays = 0
    for (let d = 0; d <= 30; d++) {
      if (has[d]) {
        studiedDays++
        if (d > 0) {
          run = 0
        }
      } else {
        run++
        if (run > longestGap) {
          longestGap = run
        }
      }
    }
    return { currentStreak: currentStreak, longestGapDays: longestGap, studiedDays: studiedDays }
  }

  /** 变化词：±10% 以内算"基本持平"；任一侧没有数据则明确说"数据不足" */
  private static trendWord(cur: number, prev: number): string {
    if (prev <= 0 || cur <= 0) {
      return '数据不足'
    }
    const d = (cur - prev) / prev
    if (d >= 0.1) {
      return '上升'
    }
    if (d <= -0.1) {
      return '下降'
    }
    return '基本持平'
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
    // 原实现取"第一个 DISTRACTED 或 level<45"，太松 —— 第 1 分钟一波动就报"疲劳信号出现"。
    // 现在先要求整场确实走下坡（后 1/3 平均 level 比前 1/3 低 10 分以上），
    // 再跳过前 1/3 去找那一次掉队；不满足就返回 0（= 没有疲劳信号）。
    const st = Metrics.sessionStructure(s)
    if (st.tailDrop > -10) {
      return 0
    }
    const from = Math.max(1, Math.floor(s.timeline.length / 3))
    for (let i = from; i < s.timeline.length; i++) {
      const p = s.timeline[i]
      if (p.state === FocusState.DISTRACTED || p.level < 45) {
        return p.minute
      }
    }
    return 0
  }

  /**
   * 分心触发源（去重，最多 3 条）。
   * 标签按信号来源区分：手机侧（切到其他应用）、手表（生理唤醒）、摄像头（画面）、手动/模拟。
   * 之前一律写成"视线离开屏幕"或"状态波动"，会把真实的手机使用伪装成视觉判定的结论。
   */
  static distractionTriggers(s: FocusSession): string[] {
    const seen: string[] = []
    for (const e of s.events) {
      if (e.state === FocusState.SLIGHTLY_DISTRACTED || e.state === FocusState.DISTRACTED) {
        const label = Metrics.sourceLabel(e.source)
        if (seen.indexOf(label) < 0 && seen.length < 3) {
          seen.push(label)
        }
      }
    }
    if (seen.length === 0 && s.distractionDuration > 0) {
      seen.push('状态波动')
    }
    return seen
  }

  /** 信号来源 → 用户能看懂的说法（不要在页面上出现内部枚举名） */
  static sourceLabel(source: FocusSource): string {
    if (source === FocusSource.PHONE) {
      return '切到其他应用（手机使用）'
    }
    if (source === FocusSource.WATCH) {
      return '心率/HRV 波动'
    }
    if (source === FocusSource.MANUAL) {
      return '手动标记'
    }
    if (source === FocusSource.AI) {
      return 'AI 判断'
    }
    return '视线离开屏幕'
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

  // 注：原先这里还有一个"空数组返回 0"的 median()，已删除 —— 空数组返回 0 无法区分
  // "没有样本"与"真实的 0"，而基线/结构量必须能区分（-1 = 没有样本）。
  // 现在统一用上面那个返回 -1 哨兵的 median()；调用方要么保证非空，要么按 -1 处理。

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
