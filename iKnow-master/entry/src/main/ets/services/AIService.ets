import { Task } from '../models/Task'
import { FocusSession } from '../models/FocusSession'
import { StudyReport } from '../models/StudyReport'
import { FocusProfile } from '../models/FocusProfile'
import { AIPersonality } from '../models/Enums'
import { IdUtils } from '../utils/IdUtils'
import { TimeUtils } from '../utils/TimeUtils'

/**
 * AI 服务 —— Mock 盘古（Pangu）
 * 未来替换为真实大模型 API 时，仅需替换本类内部实现，接口保持不变。
 * 人格：有温度、有陪伴感，但不假装真人；不指责、不说教、不制造焦虑。
 */
export class AIService {
  private static inst: AIService | null = null
  private personality: AIPersonality = AIPersonality.GENTLE

  static getInstance(): AIService {
    if (AIService.inst === null) {
      AIService.inst = new AIService()
    }
    return AIService.inst
  }

  setPersonality(p: AIPersonality): void {
    this.personality = p
  }

  getPersonality(): AIPersonality {
    return this.personality
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, ms)
    })
  }

  /** 学伴固定开场（身份透明必须保留） */
  companionIntro(): string {
    return '你好，我是你的 AI 学伴小伴，不是真人，但会一直陪你。'
  }

  /** 对话式规划开场白 */
  openPlanning(): string {
    return '今天想学点什么？先告诉我一个大概的目标，我帮你拆成几个具体的小任务。'
  }

  /** 对话式规划的追问 */
  nextPlanningQuestion(step: number): string {
    if (step === 0) {
      return '好的，大概有多少时间可以学习呢？'
    }
    if (step === 1) {
      return '有没有特别想优先完成的部分？'
    }
    return '好的，我帮你安排一下。'
  }

  /** 根据目标文本生成结构化任务（Mock 盘古） */
  async planTasks(input: string): Promise<Task[]> {
    await this.delay(550)
    return this.buildTasksFromText(input)
  }

  private buildTasksFromText(input: string): Task[] {
    const tasks: Task[] = []
    const now = Date.now()
    const mk = (title: string, subject: string, min: number, order: number): Task => {
      const t = new Task()
      t.id = IdUtils.uuid()
      t.title = title
      t.subject = subject
      t.estimatedDuration = min
      t.sortOrder = order
      t.createdAt = now
      return t
    }

    if (input.indexOf('高数') >= 0 || input.indexOf('数学') >= 0 || input.indexOf('极限') >= 0 || input.indexOf('导数') >= 0) {
      tasks.push(mk('复习极限章节', '高等数学', 30, 0))
      tasks.push(mk('完成极限练习题 10 道', '高等数学', 30, 1))
      tasks.push(mk('复习导数章节', '高等数学', 30, 2))
      tasks.push(mk('完成导数练习题 10 道', '高等数学', 30, 3))
    } else if (input.indexOf('英语') >= 0 || input.indexOf('单词') >= 0) {
      tasks.push(mk('背诵 50 个核心单词', '英语', 25, 0))
      tasks.push(mk('精读 1 篇阅读理解', '英语', 35, 1))
      tasks.push(mk('整理今日生词与长难句', '英语', 20, 2))
    } else if (input.indexOf('政治') >= 0) {
      tasks.push(mk('梳理马原第一章框架', '政治', 40, 0))
      tasks.push(mk('完成 20 道选择题', '政治', 30, 1))
      tasks.push(mk('错题复盘', '政治', 20, 2))
    } else {
      tasks.push(mk(`复习「${input}」核心概念`, '综合', 40, 0))
      tasks.push(mk(`「${input}」专项练习`, '综合', 40, 1))
      tasks.push(mk('错题与笔记整理', '综合', 20, 2))
    }
    return tasks
  }

  /** 通用学伴对话 */
  async chat(input: string): Promise<string> {
    await this.delay(420)
    if (input.indexOf('状态不好') >= 0 || input.indexOf('累') >= 0 || input.indexOf('焦虑') >= 0) {
      return '状态有起伏很正常，不用逼自己。我们先从最小的一步开始：把今天要做的第一件事缩小到 15 分钟就能完成的量，好吗？'
    }
    if (input.indexOf('分心') >= 0 || input.indexOf('走神') >= 0 || input.indexOf('专注') >= 0) {
      return '容易分心通常不是意志力的问题，而是任务和节奏没匹配。我建议把任务切成更小的块，每 25-45 分钟安排一次短暂休息。要我现在帮你重新排一下吗？'
    }
    if (input.indexOf('计划') >= 0 || input.indexOf('规划') >= 0 || input.indexOf('安排') >= 0) {
      return '好呀，你可以去「首页 → 开始专注」进入 AI 规划，或者直接告诉我今天想学什么，我来帮你拆解。'
    }
    if (input.indexOf('你好') >= 0 || input.indexOf('嗨') >= 0) {
      return '你好呀，我是小伴。不是真人，但会一直陪着你。'
    }
    return '我在听着。你可以问我知识点、让我调整计划，或者只是说说今天的感受。'
  }

  /** 答疑（Mock 知识库） */
  async answerQuestion(q: string): Promise<string> {
    await this.delay(620)
    if (q.indexOf('洛必达') >= 0) {
      return '洛必达法则适用于 0/0 或 ∞/∞ 型未定式：当分子分母都趋于 0（或都趋于无穷）时，可以对分子、分母分别求导再取极限。使用前要确认满足可导与未定式条件，且求导后的极限存在。'
    }
    if (q.indexOf('导数') >= 0 || q.indexOf('链式') >= 0) {
      return '链式法则是复合函数求导的核心：若 y = f(g(x))，则 y\' = f\'(g(x)) · g\'(x)。由外向内一层层求导再相乘。'
    }
    if (q.indexOf('极限') >= 0) {
      return '求极限先判断类型：能直接代入就先代入；出现 0/0 型，优先考虑等价无穷小替换、因式分解或洛必达法则。'
    }
    return '这个问题我记下了。按我目前的模拟知识库，先给你一个方向：把它拆成「定义 → 适用条件 → 典型例题」三步逐步击破。回到专注后，我会把它写进本次复盘。'
  }

  /** 复盘洞察文案 */
  async reviewInsight(session: FocusSession, report: StudyReport): Promise<string> {
    await this.delay(420)
    let text = `本次一共学习了 ${TimeUtils.formatDuration(session.totalDuration)}，净专注率 ${Math.round(report.focusRate)}%。`
    if (report.bestFocusPeriod.length > 0) {
      text += ` 你的最佳专注时段出现在 ${report.bestFocusPeriod}，这段时间状态很稳，几乎没有明显分心。`
    }
    if (report.fatiguePoint > 0) {
      const nextRest = Math.max(25, report.fatiguePoint - 5)
      text += ` 大概在第 ${report.fatiguePoint} 分钟左右开始出现疲劳信号，下一次可以提前到 ${nextRest} 分钟左右安排一次短暂休息。`
    }
    return text
  }

  /** 复盘优化建议（具体、可执行，不空洞） */
  reviewSuggestions(session: FocusSession, report: StudyReport): string[] {
    const list: string[] = []
    list.push('每 45 分钟左右主动休息一次，起来喝口水、活动一下')
    if (report.completionRate < 90) {
      list.push('下次把任务切得更小一些，完成感会更足')
    }
    if (report.distractionTriggers.length > 0) {
      list.push('把手机放到视线之外，减少被动打断')
    }
    list.push('练习题建议分两批完成，中间留出缓冲')
    return list
  }

  /** 长期画像更新（根据历史会话重算五维） */
  updateProfile(profile: FocusProfile, sessions: FocusSession[]): FocusProfile {
    const finished: FocusSession[] = sessions.filter((s: FocusSession): boolean => s.totalDuration > 0)
    if (finished.length === 0) {
      return profile
    }
    let totalFocus = 0
    let totalTime = 0
    for (const s of finished) {
      totalFocus += s.focusDuration
      totalTime += s.totalDuration
    }
    const count = finished.length
    const avgFocusMin = Math.round(totalFocus / count / 60)
    const overallRate = totalTime > 0 ? Math.round(totalFocus / totalTime * 100) : 0

    profile.averageFocusDuration = Math.max(20, avgFocusMin)
    profile.focusThreshold = Math.max(25, Math.round(avgFocusMin * 1.05))
    profile.concentration = Math.min(98, Math.round(overallRate * 0.9))
    profile.stability = Math.min(98, Math.round(60 + avgFocusMin * 0.4))
    profile.efficiency = Math.min(98, Math.round(70 + avgFocusMin * 0.3))
    profile.execution = Math.min(98, 78 + Math.round(count * 1.5))
    profile.antiDistraction = Math.min(98, Math.round(65 + overallRate * 0.3))
    profile.updatedAt = Date.now()
    return profile
  }

  /** 首页主动建议文案 */
  proactive(goldenTime: string): string {
    return `你通常在 ${goldenTime} 专注效率最高。要不要现在开始一个 45 分钟的专注？`
  }

  /** 长期分析文案 */
  longTermAnalysis(profile: FocusProfile, hardestSubject: string): string {
    return `最近两周，你的上午学习效率明显提高。相比阅读类任务，你在${hardestSubject}中更容易出现注意力下降。建议下周将${hardestSubject}任务安排在上午第一个学习时段，并配合 45 分钟左右的专注节奏。`
  }
}
