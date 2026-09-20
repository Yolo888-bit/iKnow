import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { User } from '../models/User'
import { Task, LearningGoal } from '../models/Task'
import { FocusSession } from '../models/FocusSession'
import { StudyReport } from '../models/StudyReport'
import { FocusProfile } from '../models/FocusProfile'
import { Dashboard, SubjectProgress } from '../models/Dashboard'
import { AIPersonality, TaskStatus, SessionStatus } from '../models/Enums'
import { StorageService } from '../services/StorageService'
import { AIService } from '../services/AIService'
import { ReportService } from '../services/ReportService'
import { FocusController } from '../services/FocusController'
import { PermissionService } from '../services/PermissionService'
import { SensorService } from '../services/SensorService'
import { Metrics } from '../services/Metrics'
import { StorageKey } from '../common/Constants'
import { IdUtils } from '../utils/IdUtils'
import { TimeUtils } from '../utils/TimeUtils'

/** 计划任务的持久化结构（KV 里存 JSON，避免直接序列化 @Observed 对象） */
interface PlanTaskJson {
  id: string
  title: string
  subject: string
  estimatedDuration: number
  actualDuration: number
  status: string
  done: boolean
  sortOrder: number
  sessionId: string
  createdAt: number
}

/**
 * AppStore —— 单一事实源（Vuex 风格）
 * 所有读写都经过这里，并同步到 StorageService 持久化 + AppStorage 响应式。
 * 页面只与 AppStore / Service 交互，不直接写死 Mock 数据。
 */
export class AppStore {
  private static inst: AppStore | null = null
  private user: User = new User()
  private goal: LearningGoal = new LearningGoal()
  private tasks: Task[] = []
  private sessions: FocusSession[] = []
  private profile: FocusProfile = new FocusProfile()
  private dashboard: Dashboard = new Dashboard()
  private currentPlan: Task[] = []
  private currentReport: StudyReport | null = null
  private currentSession: FocusSession | null = null
  private initialized: boolean = false
  private initPromise: Promise<void> | null = null

  static getInstance(): AppStore {
    if (AppStore.inst === null) {
      AppStore.inst = new AppStore()
    }
    return AppStore.inst
  }

  async init(context: common.Context): Promise<void> {
    if (this.initPromise === null) {
      // 失败必须把缓存清掉：否则一次异常就让 initPromise 永久 rejected，
      // 同一进程内再调 init() 只是把同一个失败原样抛回，永远没有重试的机会
      this.initPromise = this.doInit(context).catch((e: Error) => {
        this.initPromise = null
        throw e
      })
    }
    return this.initPromise
  }

  private async doInit(context: common.Context): Promise<void> {
    if (this.initialized) {
      return
    }
    await StorageService.getInstance().init(context)
    await PermissionService.getInstance().init()
    // 读回手表佩戴状态（否则用户切了开关，重启就变回未佩戴）
    await SensorService.getInstance().init()
    AppStorage.setOrCreate<number>(StorageKey.METRICS_MIN_SAMPLES, Metrics.MIN_SAMPLES)
    this.initAppStorageDefaults()
    const user = await StorageService.getInstance().loadUser()
    if (user === null) {
      await this.seed()
    } else {
      this.user = user
      this.tasks = await StorageService.getInstance().loadTasks()
      this.sessions = await StorageService.getInstance().loadSessions()
      const g = await StorageService.getInstance().loadGoal()
      this.goal = g !== null ? g : new LearningGoal()
      const p = await StorageService.getInstance().loadProfile()
      this.profile = p !== null ? p : new FocusProfile()
    }
    // 登录用户名全局生效：重新启动（自动登录）时也要把持久化昵称写回 AppStorage，
    // 否则会用 initAppStorageDefaults 的默认值，首页问候语显示成默认名。
    if (this.user.nickname.length > 0) {
      AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, this.user.nickname)
    }
    // 恢复上次的计划（含勾选进度），否则重启后「今日任务」是空的
    await this.restorePlan()
    // PRD FR-15：人格必须生效 → 启动即把持久化人格同步给 AI 层
    AIService.getInstance().setPersonality(this.user.aiPersonality)
    await this.refreshAggregates()
    this.initialized = true
  }

  private initAppStorageDefaults(): void {
    AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, '')
    AppStorage.setOrCreate<string>(StorageKey.USER_AVATAR, '🧑‍🎓')
    AppStorage.setOrCreate<string>(StorageKey.USER_PERSONALITY, AIPersonality.GENTLE)
    AppStorage.setOrCreate<number>(StorageKey.TODAY_FOCUS_SEC, 0)
    AppStorage.setOrCreate<number>(StorageKey.TODAY_NET_FOCUS_SEC, 0)
    AppStorage.setOrCreate<number>(StorageKey.TODAY_DONE_TASKS, 0)
    AppStorage.setOrCreate<number>(StorageKey.TODAY_TOTAL_TASKS, 0)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_RATE, 0)
    AppStorage.setOrCreate<number>(StorageKey.WEEK_FOCUS_SEC, 0)
    AppStorage.setOrCreate<string>(StorageKey.WEEK_TREND, '[]')
    AppStorage.setOrCreate<number>(StorageKey.EXAM_DAYS, 0)
    AppStorage.setOrCreate<number>(StorageKey.DATA_VERSION, 0)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_ELAPSED, 0)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_NET, 0)
    AppStorage.setOrCreate<string>(StorageKey.FOCUS_STATE, 'FOCUSED')
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_QA_ELAPSED, 0)
  }

  // ---------- 首次启动种子数据（空模板，硬规则 §5：冷启动不得伪造五维/会话）----------
  private async seed(): Promise<void> {
    const now = Date.now()

    const u = new User()
    u.id = IdUtils.uuid()
    u.nickname = ''
    u.avatar = '🧑‍🎓'
    u.aiPersonality = AIPersonality.GENTLE
    u.createdAt = now
    await StorageService.getInstance().saveUser(u)
    this.user = u

    // 目标与昵称由首次引导页设置，不预置任何假目标（否则首屏倒计时是编造的）
    const g = new LearningGoal()
    g.id = IdUtils.uuid()
    g.title = ''
    g.examType = ''
    g.targetDate = 0
    g.subjects = []
    await StorageService.getInstance().saveGoal(g)
    this.goal = g

    // 画像保持空模板：sampleCount = 0，五维全 0，UI 显示"还在了解你"
    const p = new FocusProfile()
    p.id = IdUtils.uuid()
    p.updatedAt = now
    await StorageService.getInstance().saveProfile(p)
    this.profile = p

    // 不预置任何会话 / 任务：用户首次跑通后才会产生真实数据
    this.sessions = []
    this.tasks = []
  }

  // ---------- Getters ----------
  getUser(): User {
    return this.user
  }

  /** 本地体验模式下的用户标识（问答记忆按它归属；预留多档案隔离） */
  getUserId(): string {
    return this.user.id
  }

  getGoal(): LearningGoal {
    return this.goal
  }

  getTasks(): Task[] {
    return this.tasks
  }

  getSessions(): FocusSession[] {
    return this.sessions
  }

  getProfile(): FocusProfile {
    return this.profile
  }

  getDashboard(): Dashboard {
    return this.dashboard
  }

  getCurrentPlan(): Task[] {
    return this.currentPlan
  }

  getCurrentReport(): StudyReport | null {
    return this.currentReport
  }

  getCurrentSession(): FocusSession | null {
    return this.currentSession
  }

  // ---------- 用户 & 目标 ----------
  async saveUserNickname(nickname: string): Promise<void> {
    this.user.nickname = nickname
    await StorageService.getInstance().saveUser(this.user)
    AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, nickname)
  }

  async saveUserPersonality(p: AIPersonality): Promise<void> {
    this.user.aiPersonality = p
    AIService.getInstance().setPersonality(p)
    await StorageService.getInstance().saveUser(this.user)
    AppStorage.setOrCreate<string>(StorageKey.USER_PERSONALITY, p)
  }

  /** 修改头像（emoji 标识）→ 持久化到用户并全局生效 */
  async saveUserAvatar(avatar: string): Promise<void> {
    this.user.avatar = avatar
    await StorageService.getInstance().saveUser(this.user)
    AppStorage.setOrCreate<string>(StorageKey.USER_AVATAR, avatar)
  }

  /**
   * 登录成功后调用：把「登录用户名」写入用户昵称并全局生效。
   * 首页/我的等页面通过 @StorageProp(USER_NICKNAME) 响应，无需各自改动。
   */
  async applyLoginUser(username: string): Promise<void> {
    if (this.user.id.length === 0) {
      this.user.id = IdUtils.uuid()
      this.user.createdAt = Date.now()
    }
    this.user.nickname = username
    await StorageService.getInstance().saveUser(this.user)
    AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, username)
  }

  async saveGoal(goal: LearningGoal): Promise<void> {
    this.goal = goal
    await StorageService.getInstance().saveGoal(goal)
    this.pushAggregates()
  }

  /** 是否已走过「目标 + 日期」引导（显式标记，避免被历史残留的目标数据误判） */
  async isGoalConfigured(): Promise<boolean> {
    try {
      return (await StorageService.getInstance().loadKv(StorageKey.GOAL_CONFIGURED)) === '1'
    } catch (e) {
      return false
    }
  }

  /** 目标引导完成 → 打标，之后启动直接进主界面 */
  async markGoalConfigured(): Promise<void> {
    await StorageService.getInstance().saveKv(StorageKey.GOAL_CONFIGURED, '1')
  }

  /**
   * 勾选 / 取消勾选某个任务（工作台「总体进度」的未完成清单用）。
   * 改动全量任务列表里的那一条 → 落库 → 重算聚合，
   * 这样进度数字、今日统计会跟着一起变（不只是勾上了 UI 不动数据）。
   */
  async toggleTaskDone(id: string): Promise<void> {
    let target: Task | null = null
    for (const t of this.tasks) {
      if (t.id === id) {
        target = t
      }
    }
    if (target === null) {
      // 全量表里没有 → 说明这条只存在于「当前计划」（还没进过专注）。
      // 勾上就算"做过一次"，纳入全量表，后续任务总结/进度才看得到。
      for (const t of this.currentPlan) {
        if (t.id === id) {
          target = t
        }
      }
      if (target !== null) {
        this.tasks.push(target)
      }
    }
    if (target === null) {
      return
    }
    target.done = !target.done
    target.status = target.done ? TaskStatus.DONE : TaskStatus.TODO
    // 「当前计划」里的同一条同步勾选状态，避免首页与工作台两处不一致
    for (const t of this.currentPlan) {
      if (t.id === id) {
        t.done = target.done
        t.status = target.status
      }
    }
    await StorageService.getInstance().saveTask(target)
    await this.savePlan()
    await this.refreshAggregates()
  }

  // ---------- 规划 ----------
  async planTasks(input: string): Promise<Task[]> {
    return await AIService.getInstance().planTasks(input)
  }

  setCurrentPlan(tasks: Task[]): void {
    this.currentPlan = tasks
    this.savePlan()
  }

  /** 把当前计划落库（KV 存 JSON）：重启 App 后「今日任务」与勾选进度都还在 */
  async savePlan(): Promise<void> {
    try {
      const arr: PlanTaskJson[] = []
      for (const t of this.currentPlan) {
        arr.push({
          id: t.id,
          title: t.title,
          subject: t.subject,
          estimatedDuration: t.estimatedDuration,
          actualDuration: t.actualDuration,
          status: t.status,
          done: t.done,
          sortOrder: t.sortOrder,
          sessionId: t.sessionId,
          createdAt: t.createdAt
        })
      }
      await StorageService.getInstance().saveKv(StorageKey.CURRENT_PLAN, JSON.stringify(arr))
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Store', '保存当前计划失败：%{public}s', e.message)
    }
  }

  /** 启动时恢复当前计划；读不到就当没有计划（不编造） */
  private async restorePlan(): Promise<void> {
    try {
      const raw = await StorageService.getInstance().loadKv(StorageKey.CURRENT_PLAN)
      if (raw.length === 0) {
        this.currentPlan = []
        return
      }
      const arr = JSON.parse(raw) as PlanTaskJson[]
      const list: Task[] = []
      for (const j of arr) {
        const t = new Task()
        t.id = j.id
        t.title = j.title
        t.subject = j.subject
        t.estimatedDuration = j.estimatedDuration
        t.actualDuration = j.actualDuration
        t.status = AppStore.statusOf(j.status)
        t.done = j.done
        t.sortOrder = j.sortOrder
        t.sessionId = j.sessionId
        t.createdAt = j.createdAt
        list.push(t)
      }
      this.currentPlan = list
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Store', '恢复当前计划失败：%{public}s', e.message)
      this.currentPlan = []
    }
  }

  /** 字符串 → TaskStatus（避免直接强转枚举，坏数据也兜得住） */
  private static statusOf(v: string): TaskStatus {
    if (v === TaskStatus.DONE) {
      return TaskStatus.DONE
    }
    if (v === TaskStatus.DOING) {
      return TaskStatus.DOING
    }
    return TaskStatus.TODO
  }

  /**
   * 规划确认即把任务落库。
   *
   * 原来规划结果只进内存 `currentPlan`，要等"结束一次专注"才写库 ——
   * 于是首次专注结束前，工作台的「总体进度」「科目进度」恒为 0/0 + "还没有任何任务"，
   * 用户会觉得这两个卡片坏了（或数据没依据）。落库后当场成立。
   */
  async persistPlan(tasks: Task[]): Promise<void> {
    for (const t of tasks) {
      await StorageService.getInstance().saveTask(t)
    }
    this.tasks = await StorageService.getInstance().loadTasks()
    await this.refreshAggregates()
  }

  addPlanTask(title: string, subject: string, minutes: number): void {
    const t = new Task()
    t.id = IdUtils.uuid()
    t.title = title
    t.subject = subject
    t.estimatedDuration = minutes
    t.sortOrder = this.currentPlan.length
    t.createdAt = Date.now()
    this.currentPlan.push(t)
    this.savePlan()
  }

  removePlanTask(id: string): void {
    const next: Task[] = []
    for (const t of this.currentPlan) {
      if (t.id !== id) {
        next.push(t)
      }
    }
    this.currentPlan = next
    this.savePlan()
  }

  togglePlanTask(id: string): void {
    for (const t of this.currentPlan) {
      if (t.id === id) {
        t.done = !t.done
        t.status = t.done ? TaskStatus.DONE : TaskStatus.TODO
      }
    }
  }

  /** 计划内任务被就地修改（如专注页勾选完成）后广播一次响应式刷新 */
  syncPlan(): void {
    this.pushAggregates()
  }

  // ---------- 结束会话 → 复盘 → 画像 → 工作台联动 ----------
  async endSession(): Promise<StudyReport | null> {
    const controller = FocusController.getInstance()
    if (!controller.isRunning()) {
      // 没有进行中的会话也要刷新一次：否则调用方以为"结束过了"，界面上还是旧统计
      await this.syncAfterSession()
      return this.currentReport
    }
    const session = controller.finalize()
    const questions = controller.getQuestions()
    const tasks = controller.getTasks()
    let report: StudyReport | null = null

    // 注意：这一段里任何一步失败都不能让"同步统计"被跳过 ——
    // 之前没有 try/finally，一次落库异常就会导致退出专注后今日数据仍是旧值。
    try {
      report = await ReportService.getInstance().buildReport(session, questions)
      await StorageService.getInstance().saveSession(session)
      for (const t of tasks) {
        await StorageService.getInstance().saveTask(t)
      }
      for (const q of questions) {
        await StorageService.getInstance().saveQuestion(q)
      }
      await StorageService.getInstance().saveReport(report)
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Store', '保存本次专注失败：%{public}s', e.message)
    }

    // 无论保存是否完整成功，统计都要跟着本次会话更新（数据以库里实际存到的为准）
    await this.syncAfterSession()
    // 画像更新依赖最新会话列表，因此必须排在 syncAfterSession 之后；失败不影响统计
    try {
      this.profile = AIService.getInstance().updateProfile(this.profile, this.sessions)
      await StorageService.getInstance().saveProfile(this.profile)
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Store', '画像更新失败：%{public}s', e.message)
    }
    this.currentSession = session
    this.currentReport = report
    // 未完成任务保留在计划中（E1：不静默清空，支持跨会话延续）
    return report
  }

  /**
   * 会话结束后的统一同步：重读会话 / 任务 / 今日计划 → 重算聚合 → 广播响应式刷新。
   *
   * 为什么要单独抽出来：退出专注的入口有 4 个（专注页结束、休息页结束、根页横幅结束、
   * 规划页结束），任何一条路径漏掉同步，用户看到的就是"退出了但今日数据没变"。
   * 计划也要重读 —— 专注中勾选完成的任务必须立刻反映到首页/工作台的今日任务上。
   */
  async syncAfterSession(): Promise<void> {
    try {
      this.sessions = await StorageService.getInstance().loadSessions()
      this.tasks = await StorageService.getInstance().loadTasks()
      // 今日计划重读：专注中勾选完成的任务必须立刻反映到首页/工作台的今日任务上。
      // 库里是权威副本，按 id 换成本次读回来的对象（找不到就保留原对象）。
      if (this.currentPlan.length > 0) {
        const byId: Map<string, Task> = new Map<string, Task>()
        for (const t of this.tasks) {
          byId.set(t.id, t)
        }
        const next: Task[] = []
        for (const old of this.currentPlan) {
          const fresh = byId.get(old.id)
          next.push(fresh !== undefined ? fresh : old)
        }
        this.currentPlan = next
      }
      hilog.info(0x0000, 'iKnow.Store', '会话结束同步：%{public}d 条会话 / %{public}d 个任务',
        this.sessions.length, this.tasks.length)
    } catch (e) {
      hilog.error(0x0000, 'iKnow.Store', '重读数据失败，仍继续重算统计：%{public}s', e.message)
    }
    // 计划也要落库：专注中勾选/新增的任务，重启后必须还在
    await this.savePlan()
    await this.refreshAggregates()
  }

  // ---------- 聚合 & 响应式刷新 ----------
  async refreshAggregates(): Promise<void> {
    const now = Date.now()
    let todayFocus = 0
    let todayNet = 0
    let todayStudy = 0
    let weekFocus = 0
    // 「本周」= 自然周（周一 0 点起）。原来用的是"今天往前 6 天"的滚动窗口，
    // 却挂着「本周累计」的标签 —— 名实不符。近 7 天的图表另有 computeWeekTrend。
    const weekStart = TimeUtils.weekStart(now)

    for (const s of this.sessions) {
      if (TimeUtils.isSameDay(s.startTime, now)) {
        todayFocus += Metrics.wallClock(s)
        todayNet += Metrics.netFocusSec(s)
        todayStudy += Metrics.totalStudySec(s)
      }
      if (s.startTime >= weekStart) {
        weekFocus += Metrics.netFocusSec(s)
      }
    }

    // 今日任务口径：优先按「今日计划」（跨天延续的任务也算今天要做的事），
    // 之前只按 createdAt 是今天的任务统计，导致昨天建的计划今天显示 0/0
    let done = 0
    let total = 0
    if (this.currentPlan.length > 0) {
      for (const t of this.currentPlan) {
        total += 1
        if (t.done) {
          done += 1
        }
      }
    } else {
      for (const t of this.tasks) {
        if (TimeUtils.isSameDay(t.createdAt, now)) {
          total += 1
          if (t.done) {
            done += 1
          }
        }
      }
    }

    const d = new Dashboard()
    d.todayFocusSeconds = todayFocus
    d.todayNetFocusSeconds = todayNet
    // 口径与复盘页一致：净专注率 = 净专注 / 总学习（总学习 = 墙钟 − 休息 − 暂停）
    d.focusRate = todayStudy > 0 ? Math.round(todayNet / todayStudy * 100) : 0
    d.weekFocusSeconds = weekFocus
    d.weekTrend = this.computeWeekTrend(now)
    d.todayCompletedTasks = done
    d.todayTotalTasks = total
    d.subjectProgress = this.computeSubjectProgress()
    this.dashboard = d
    this.pushAggregates()
  }

  private computeWeekTrend(now: number): number[] {
    const arr: number[] = []
    for (let day = 6; day >= 0; day--) {
      const dayStart = TimeUtils.dayStart(now) - day * 24 * 3600 * 1000
      const dayEnd = dayStart + 24 * 3600 * 1000
      let net = 0
      for (const s of this.sessions) {
        if (s.startTime >= dayStart && s.startTime < dayEnd) {
          net += s.focusDuration
        }
      }
      arr.push(Math.round(net / 60))
    }
    return arr
  }

  private computeSubjectProgress(): SubjectProgress[] {
    const map: Map<string, SubjectProgress> = new Map<string, SubjectProgress>()
    // 只统计近 30 天的任务：之前遍历全部历史任务，分母无限增长，进度几乎不动
    const since = TimeUtils.dayStart(Date.now()) - 29 * 24 * 3600 * 1000
    for (const t of this.tasks) {
      if (t.createdAt < since) {
        continue
      }
      let sp = map.get(t.subject)
      if (sp === undefined) {
        sp = new SubjectProgress()
        sp.subject = t.subject
        map.set(t.subject, sp)
      }
      sp.total += 1
      if (t.done) {
        sp.completed += 1
      }
    }
    const list: SubjectProgress[] = []
    map.forEach((value: SubjectProgress, key: string) => {
      value.percent = value.total > 0 ? Math.round(value.completed / value.total * 100) : 0
      list.push(value)
    })
    return list
  }

  private pushAggregates(): void {
    AppStorage.setOrCreate<number>(StorageKey.TODAY_FOCUS_SEC, this.dashboard.todayFocusSeconds)
    AppStorage.setOrCreate<number>(StorageKey.TODAY_NET_FOCUS_SEC, this.dashboard.todayNetFocusSeconds)
    AppStorage.setOrCreate<number>(StorageKey.TODAY_DONE_TASKS, this.dashboard.todayCompletedTasks)
    AppStorage.setOrCreate<number>(StorageKey.TODAY_TOTAL_TASKS, this.dashboard.todayTotalTasks)
    AppStorage.setOrCreate<number>(StorageKey.FOCUS_RATE, this.dashboard.focusRate)
    AppStorage.setOrCreate<number>(StorageKey.WEEK_FOCUS_SEC, this.dashboard.weekFocusSeconds)
    AppStorage.setOrCreate<string>(StorageKey.WEEK_TREND, JSON.stringify(this.dashboard.weekTrend))
    AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, this.user.nickname)
    AppStorage.setOrCreate<string>(StorageKey.USER_AVATAR, this.user.avatar)
    AppStorage.setOrCreate<string>(StorageKey.USER_PERSONALITY, this.user.aiPersonality)
    const days = TimeUtils.daysUntil(this.goal.targetDate, Date.now())
    AppStorage.setOrCreate<number>(StorageKey.EXAM_DAYS, days)

    let ver = 0
    const cur: number | undefined = AppStorage.get<number>(StorageKey.DATA_VERSION)
    if (cur !== undefined) {
      ver = cur
    }
    AppStorage.setOrCreate<number>(StorageKey.DATA_VERSION, ver + 1)

    // 服务卡片快照：卡片进程读不到主进程内存，只能靠落库的这几个键
    const svc = StorageService.getInstance()
    svc.saveKv(StorageKey.CARD_TODAY, TimeUtils.formatHMin(this.dashboard.todayFocusSeconds)).catch(() => {})
    svc.saveKv(StorageKey.CARD_RATE, `${this.dashboard.focusRate}%`).catch(() => {})
    svc.saveKv(StorageKey.CARD_ADVICE, this.cardAdvice()).catch(() => {})
  }

  /** 桌面上卡片给的一句建议：由真实数据推导，不写死 */
  private cardAdvice(): string {
    let left = 0
    for (const t of this.currentPlan) {
      if (!t.done) {
        left += 1
      }
    }
    if (left > 0) {
      return `今天还有 ${left} 个任务没完成`
    }
    if (this.dashboard.todayFocusSeconds <= 0) {
      return '开始一段专注吧'
    }
    return '今天的任务都完成了，休息一下'
  }

  // ---------- 数据清除（合规） ----------
  async clearAll(): Promise<void> {
    // E15：先终止正在进行的会话，否则清完数据回专注页点结束会把刚删的数据写回
    FocusController.getInstance().abort()
    await StorageService.getInstance().clearAll()
    // 帧文件放在记录之后删：反过来一旦删文件失败，库里会留下指向不存在图片的记录，
    // 复盘时间线渲染出空白图 —— "销毁了但还能看到残留"是最差的观感
    AppStore.removeObservationDir()
    // 重置为与首次启动完全一致的空模板（复用 seed()，不再另写一套"陌生人的默认值"）。
    // 原先这里写回 nickname='刘灿' + '考研上岸' 128 天，用户清完数据重启会看到别人的目标。
    await this.seed()
    this.currentPlan = []
    this.currentReport = null
    this.currentSession = null
    this.dashboard = new Dashboard()
    this.pushAggregates()
  }

  /** 删除已保存的画面片段目录（合规：一键清除必须连带删掉帧文件） */
  static removeObservationDir(): void {
    try {
      const dir = `${StorageService.getInstance().filesDir()}/obs`
      if (fileIo.accessSync(dir)) {
        fileIo.rmdirSync(dir)
      }
    } catch (e) {
      // 目录不存在或删除失败都不影响主流程
    }
  }

  async clearLearningData(): Promise<void> {
    // 只清学习记录：原先这里直接走 clearAll()，会连身份与授权一起清掉，
    // 并写回一个陌生人的默认昵称与目标（'刘灿' / '考研上岸' 128 天）。
    // 用户点了「清除学习数据」重启，看到的是"这 App 里有别人的数据"。
    FocusController.getInstance().abort()
    await StorageService.getInstance().clearLearningTables()
    AppStore.removeObservationDir()
    this.sessions = []
    this.tasks = []
    this.currentPlan = []
    this.currentReport = null
    this.currentSession = null
    // 画像由会话派生：会话清了，画像必须跟着回到空模板，否则页面显示的还是旧结论
    this.profile = new FocusProfile()
    await this.refreshAggregates()
  }

  /** 清除画面片段：先清空库里的图片引用，再删帧文件（顺序反了会留下指向不存在图片的记录） */
  async clearImages(): Promise<void> {
    await StorageService.getInstance().clearObservationImages()
    AppStore.removeObservationDir()
  }

  async clearPhysioData(): Promise<void> {
    // 手表事件（rmssd / hr）是**真实落库**的（FocusController.finalize → saveWatchEvents），
    // 之前这里是空实现 + "无持久化生理数据"的提示，属于不实
    await StorageService.getInstance().clearWatchEvents()
  }
}
