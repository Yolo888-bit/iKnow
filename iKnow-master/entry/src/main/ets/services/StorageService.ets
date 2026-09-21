import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { User } from '../models/User'
import { LearningGoal, Task } from '../models/Task'
import { FocusSession, FocusEvent, FocusTimelinePoint } from '../models/FocusSession'
import { SessionSnapshot } from '../models/SessionSnapshot'
import { InterventionEvent } from '../models/InterventionEvent'
import { TaskTimelinePoint } from '../models/TaskTimeline'
import { StudyPlan, SubjectTarget } from '../models/StudyPlan'
import { Authorization } from '../models/Authorization'
import { QuestionRecord } from '../models/QuestionRecord'
import { StudyReport } from '../models/StudyReport'
import { FocusProfile } from '../models/FocusProfile'
import { AIPersonality, TaskStatus, SessionStatus, InterventionLevel, FeedbackAction, FocusSource } from '../models/Enums'
import { ObservationRecord, WatchEvent } from '../models/WatchSignal'

const DB_NAME = 'iKnow.db'

/**
 * 持久化层 —— 基于 @ohos.data.relationalStore（经 @kit.ArkData 暴露）
 * 所有学习数据、画像、会话、快照、干预、授权均落库，App 重启后仍保留。
 */
export class StorageService {
  private static inst: StorageService | null = null
  private rdb: relationalStore.RdbStore | null = null
  private filesDirPath: string = ''
  private ctx: common.Context | null = null

  static getInstance(): StorageService {
    if (StorageService.inst === null) {
      StorageService.inst = new StorageService()
    }
    return StorageService.inst
  }

  private get store(): relationalStore.RdbStore {
    if (this.rdb === null) {
      throw new Error('StorageService not initialized')
    }
    return this.rdb
  }

  async init(context: common.Context): Promise<void> {
    if (this.rdb !== null) {
      return
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }
    this.rdb = await relationalStore.getRdbStore(context, config)
    // 画面片段需要落盘（决策：上传并保存供复盘），这里记住应用文件目录
    this.filesDirPath = context.filesDir
    this.ctx = context
    await this.createTables()
  }

  /** 应用文件目录（画面片段存放根目录） */
  filesDir(): string {
    return this.filesDirPath
  }

  /** 应用上下文：供需要 Context 的服务（相机采集）复用，避免到处传参 */
  appContext(): common.Context | null {
    return this.ctx
  }

  private async createTables(): Promise<void> {
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS user (
      id TEXT PRIMARY KEY, nickname TEXT, avatar TEXT, ai_personality TEXT, created_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS learning_goal (
      id TEXT PRIMARY KEY, title TEXT, exam_type TEXT, target_date INTEGER, subjects TEXT)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS task (
      id TEXT PRIMARY KEY, title TEXT, subject TEXT, estimated_duration INTEGER,
      actual_duration INTEGER, status TEXT, done INTEGER, sort_order INTEGER,
      session_id TEXT, created_at INTEGER, plan_id TEXT)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS focus_session (
      id TEXT PRIMARY KEY, title TEXT, start_time INTEGER, end_time INTEGER,
      total_duration INTEGER, focus_duration INTEGER, distraction_duration INTEGER,
      qa_duration INTEGER, break_duration INTEGER, paused_duration INTEGER, planned_duration INTEGER,
      task_ids TEXT, completed_task_ids TEXT, timeline TEXT, task_timeline TEXT,
      events TEXT, interventions TEXT, snapshots_count INTEGER, last_snapshot_at INTEGER,
      perception_mode TEXT, status TEXT, updated_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS question (
      id TEXT PRIMARY KEY, user_id TEXT, session_id TEXT, question TEXT, answer TEXT, created_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS study_report (
      session_id TEXT PRIMARY KEY, completion_rate REAL, focus_rate REAL,
      best_focus_period TEXT, fatigue_point INTEGER, distraction_triggers TEXT,
      suggestions TEXT, insights TEXT, questions TEXT, created_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS focus_profile (
      id TEXT PRIMARY KEY, best_focus_time TEXT, average_focus_duration INTEGER,
      focus_threshold INTEGER, efficiency INTEGER, concentration INTEGER,
      stability INTEGER, execution INTEGER, anti_distraction INTEGER,
      weekly_trend TEXT, monthly_trend TEXT, sample_count INTEGER,
      recent_concentrations TEXT, recent_distraction_rates TEXT, updated_at INTEGER)`)

    // ---- 新增表（Phase 0）----
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS authorization (
      id TEXT PRIMARY KEY, camera INTEGER, microphone INTEGER, health INTEGER,
      notification INTEGER, updated_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS session_snapshot (
      session_id TEXT, ts INTEGER, total_sec INTEGER, focus_sec INTEGER,
      distraction_sec INTEGER, qa_sec INTEGER, break_sec INTEGER,
      current_task_id TEXT, state TEXT, perception_mode TEXT, start_time INTEGER,
      PRIMARY KEY(session_id, ts))`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS intervention_event (
      id TEXT PRIMARY KEY, session_id TEXT, ts INTEGER, level TEXT, channel TEXT,
      message TEXT, source TEXT, user_feedback TEXT, recovered_focus INTEGER, payload_json TEXT)`)
    // 单记录表：id 固定为 StudyPlan.PLAN_SINGLETON_ID。
    // 不再有 exam_type（考试类型只属于 LearningGoal）与 tasks（AI 输出只是 DTO，不入库）。
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS study_plan (
      id TEXT PRIMARY KEY, title TEXT, total_estimated_minutes INTEGER, created_at INTEGER,
      subject_targets TEXT, period_start INTEGER, period_end INTEGER, updated_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS task_timeline (
      session_id TEXT, minute_offset INTEGER, task_id TEXT, level INTEGER,
      PRIMARY KEY(session_id, minute_offset))`)

    // 轻量键值表（用于持久化进行中会话 id 等需要跨崩溃保留的标记）
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS app_kv (
      key TEXT PRIMARY KEY, value TEXT)`)

    // 手表事件（合成信号触发的事件；含被节流拦下的）与云端观察记录
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS watch_event (
      id TEXT PRIMARY KEY, session_id TEXT, t_ms INTEGER, kind TEXT,
      rmssd REAL, hr REAL, accel_var REAL, reason TEXT, triggered INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS observation (
      id TEXT PRIMARY KEY, session_id TEXT, event_id TEXT, t_ms INTEGER,
      activity TEXT, handheld INTEGER, facing_desk INTEGER,
      confidence REAL, evidence TEXT, image_paths TEXT)`)

    // ---- 迁移：为已存在的旧表补列（忽略失败）----
    const alters: string[] = [
      'ALTER TABLE focus_session ADD COLUMN paused_duration INTEGER',
      'ALTER TABLE focus_session ADD COLUMN task_timeline TEXT',
      'ALTER TABLE focus_session ADD COLUMN interventions TEXT',
      'ALTER TABLE focus_session ADD COLUMN snapshots_count INTEGER',
      'ALTER TABLE focus_session ADD COLUMN last_snapshot_at INTEGER',
      'ALTER TABLE focus_session ADD COLUMN perception_mode TEXT',
      'ALTER TABLE focus_session ADD COLUMN updated_at INTEGER',
      'ALTER TABLE focus_profile ADD COLUMN sample_count INTEGER',
      'ALTER TABLE focus_profile ADD COLUMN recent_concentrations TEXT',
      'ALTER TABLE focus_profile ADD COLUMN recent_distraction_rates TEXT',
      'ALTER TABLE question ADD COLUMN user_id TEXT',
      'ALTER TABLE session_snapshot ADD COLUMN start_time INTEGER',
      // 任务归属 + 长期计划新结构（老库必须 ALTER，CREATE TABLE IF NOT EXISTS 只对新装用户有效）
      'ALTER TABLE task ADD COLUMN plan_id TEXT',
      'ALTER TABLE study_plan ADD COLUMN subject_targets TEXT',
      'ALTER TABLE study_plan ADD COLUMN period_start INTEGER',
      'ALTER TABLE study_plan ADD COLUMN period_end INTEGER',
      'ALTER TABLE study_plan ADD COLUMN updated_at INTEGER'
    ]
    for (const sql of alters) {
      try {
        await this.store.executeSql(sql)
      } catch (e) {
        // 列已存在则忽略
      }
    }
  }

  // ---------- 结果集读取辅助 ----------
  private getString(rs: relationalStore.ResultSet, col: string): string {
    const i = rs.getColumnIndex(col)
    return i >= 0 ? rs.getString(i) : ''
  }

  private getNum(rs: relationalStore.ResultSet, col: string): number {
    const i = rs.getColumnIndex(col)
    return i >= 0 ? rs.getLong(i) : 0
  }

  private getReal(rs: relationalStore.ResultSet, col: string): number {
    const i = rs.getColumnIndex(col)
    return i >= 0 ? rs.getDouble(i) : 0
  }

  private getBool(rs: relationalStore.ResultSet, col: string): boolean {
    return this.getNum(rs, col) === 1
  }

  // ---------- JSON 解析辅助 ----------
  private parseStringArray(json: string): string[] {
    try {
      const a = JSON.parse(json) as string[]
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  private parseNumberArray(json: string): number[] {
    try {
      const a = JSON.parse(json) as number[]
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  private parseTimeline(json: string): FocusTimelinePoint[] {
    try {
      const a = JSON.parse(json) as FocusTimelinePoint[]
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  private parseTaskTimeline(json: string): TaskTimelinePoint[] {
    try {
      const a = JSON.parse(json) as TaskTimelinePoint[]
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  private parseEvents(json: string): FocusEvent[] {
    try {
      const a = JSON.parse(json) as FocusEvent[]
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  private parseInterventions(json: string): InterventionEvent[] {
    try {
      const a = JSON.parse(json) as InterventionEvent[]
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  private parseQuestions(json: string): QuestionRecord[] {
    try {
      const a = JSON.parse(json) as QuestionRecord[]
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  /** 解析 subject_targets JSON；脏数据一律返回 []，不抛（与其它 parseXxx 一致） */
  private parseSubjectTargets(json: string): SubjectTarget[] {
    if (json.length === 0) {
      return []
    }
    try {
      const a = JSON.parse(json) as SubjectTarget[]
      if (!Array.isArray(a)) {
        return []
      }
      const out: SubjectTarget[] = []
      for (const item of a) {
        if (item === null || item === undefined) {
          continue
        }
        const t = new SubjectTarget()
        t.subject = typeof item.subject === 'string' ? item.subject : ''
        t.targetMinutes = typeof item.targetMinutes === 'number' ? item.targetMinutes : 0
        if (t.targetMinutes > 0) {
          out.push(t)
        }
      }
      return out
    } catch (e) {
      return []
    }
  }

  // ---------- User ----------
  async loadUser(): Promise<User | null> {
    const rs = await this.store.query(new relationalStore.RdbPredicates('user'))
    if (!rs.goToNextRow()) {
      rs.close()
      return null
    }
    const u = new User()
    u.id = this.getString(rs, 'id')
    u.nickname = this.getString(rs, 'nickname')
    u.avatar = this.getString(rs, 'avatar')
    u.aiPersonality = this.getString(rs, 'ai_personality') as AIPersonality
    u.createdAt = this.getNum(rs, 'created_at')
    rs.close()
    return u
  }

  async saveUser(u: User): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': u.id,
      'nickname': u.nickname,
      'avatar': u.avatar,
      'ai_personality': u.aiPersonality,
      'created_at': u.createdAt
    }
    await this.store.insert('user', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- LearningGoal ----------
  async loadGoal(): Promise<LearningGoal | null> {
    const rs = await this.store.query(new relationalStore.RdbPredicates('learning_goal'))
    if (!rs.goToNextRow()) {
      rs.close()
      return null
    }
    const g = new LearningGoal()
    g.id = this.getString(rs, 'id')
    g.title = this.getString(rs, 'title')
    g.examType = this.getString(rs, 'exam_type')
    g.targetDate = this.getNum(rs, 'target_date')
    g.subjects = this.parseStringArray(this.getString(rs, 'subjects'))
    rs.close()
    return g
  }

  async saveGoal(g: LearningGoal): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': g.id,
      'title': g.title,
      'exam_type': g.examType,
      'target_date': g.targetDate,
      'subjects': JSON.stringify(g.subjects)
    }
    await this.store.insert('learning_goal', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- Task ----------
  async loadTasks(): Promise<Task[]> {
    const rs = await this.store.query(new relationalStore.RdbPredicates('task').orderByAsc('sort_order'))
    const list: Task[] = []
    while (rs.goToNextRow()) {
      const t = new Task()
      t.id = this.getString(rs, 'id')
      t.title = this.getString(rs, 'title')
      t.subject = this.getString(rs, 'subject')
      t.estimatedDuration = this.getNum(rs, 'estimated_duration')
      t.actualDuration = this.getNum(rs, 'actual_duration')
      t.status = this.getString(rs, 'status') as TaskStatus
      t.done = this.getBool(rs, 'done')
      t.sortOrder = this.getNum(rs, 'sort_order')
      t.sessionId = this.getString(rs, 'session_id')
      t.createdAt = this.getNum(rs, 'created_at')
      t.planId = this.getString(rs, 'plan_id')
      list.push(t)
    }
    rs.close()
    return list
  }

  async saveTask(t: Task): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': t.id,
      'title': t.title,
      'subject': t.subject,
      'estimated_duration': t.estimatedDuration,
      'actual_duration': t.actualDuration,
      'status': t.status,
      'done': t.done ? 1 : 0,
      'sort_order': t.sortOrder,
      'session_id': t.sessionId,
      'created_at': t.createdAt,
      'plan_id': t.planId
    }
    await this.store.insert('task', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  async deleteTask(id: string): Promise<void> {
    const p = new relationalStore.RdbPredicates('task')
    p.equalTo('id', id)
    await this.store.delete(p)
  }

  // ---------- FocusSession ----------
  async loadSessions(): Promise<FocusSession[]> {
    const rs = await this.store.query(new relationalStore.RdbPredicates('focus_session').orderByDesc('start_time'))
    const list: FocusSession[] = []
    while (rs.goToNextRow()) {
      const s = new FocusSession()
      s.id = this.getString(rs, 'id')
      s.title = this.getString(rs, 'title')
      s.startTime = this.getNum(rs, 'start_time')
      s.endTime = this.getNum(rs, 'end_time')
      s.totalDuration = this.getNum(rs, 'total_duration')
      s.focusDuration = this.getNum(rs, 'focus_duration')
      s.distractionDuration = this.getNum(rs, 'distraction_duration')
      s.qaDuration = this.getNum(rs, 'qa_duration')
      s.breakDuration = this.getNum(rs, 'break_duration')
      s.pausedDuration = this.getNum(rs, 'paused_duration')
      s.plannedDuration = this.getNum(rs, 'planned_duration')
      s.taskIds = this.parseStringArray(this.getString(rs, 'task_ids'))
      s.completedTaskIds = this.parseStringArray(this.getString(rs, 'completed_task_ids'))
      s.timeline = this.parseTimeline(this.getString(rs, 'timeline'))
      s.taskTimeline = this.parseTaskTimeline(this.getString(rs, 'task_timeline'))
      s.events = this.parseEvents(this.getString(rs, 'events'))
      s.interventions = this.parseInterventions(this.getString(rs, 'interventions'))
      s.snapshotsCount = this.getNum(rs, 'snapshots_count')
      s.lastSnapshotAt = this.getNum(rs, 'last_snapshot_at')
      s.perceptionMode = this.getString(rs, 'perception_mode') || 'PERCEPTION_FULL'
      s.status = this.getString(rs, 'status') as SessionStatus
      s.updatedAt = this.getNum(rs, 'updated_at')
      list.push(s)
    }
    rs.close()
    return list
  }

  async saveSession(s: FocusSession): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': s.id,
      'title': s.title,
      'start_time': s.startTime,
      'end_time': s.endTime,
      'total_duration': s.totalDuration,
      'focus_duration': s.focusDuration,
      'distraction_duration': s.distractionDuration,
      'qa_duration': s.qaDuration,
      'break_duration': s.breakDuration,
      'paused_duration': s.pausedDuration,
      'planned_duration': s.plannedDuration,
      'task_ids': JSON.stringify(s.taskIds),
      'completed_task_ids': JSON.stringify(s.completedTaskIds),
      'timeline': JSON.stringify(s.timeline),
      'task_timeline': JSON.stringify(s.taskTimeline),
      'events': JSON.stringify(s.events),
      'interventions': JSON.stringify(s.interventions),
      'snapshots_count': s.snapshotsCount,
      'last_snapshot_at': s.lastSnapshotAt,
      'perception_mode': s.perceptionMode,
      'status': s.status,
      'updated_at': s.updatedAt
    }
    await this.store.insert('focus_session', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- Question ----------
  async loadQuestions(sessionId: string): Promise<QuestionRecord[]> {
    const p = new relationalStore.RdbPredicates('question')
    p.equalTo('session_id', sessionId)
    const rs = await this.store.query(p)
    const list: QuestionRecord[] = []
    while (rs.goToNextRow()) {
      const q = new QuestionRecord()
      q.id = this.getString(rs, 'id')
      q.userId = this.getString(rs, 'user_id')
      q.sessionId = this.getString(rs, 'session_id')
      q.question = this.getString(rs, 'question')
      q.answer = this.getString(rs, 'answer')
      q.createdAt = this.getNum(rs, 'created_at')
      list.push(q)
    }
    rs.close()
    return list
  }

  /** 某用户最近问过的问题（新→旧），用于跨会话答疑记忆 */
  async loadRecentQuestions(userId: string, limit: number): Promise<QuestionRecord[]> {
    const p = new relationalStore.RdbPredicates('question')
    p.equalTo('user_id', userId)
    p.orderByDesc('created_at')
    p.limitAs(limit)
    const rs = await this.store.query(p)
    const list: QuestionRecord[] = []
    while (rs.goToNextRow()) {
      const q = new QuestionRecord()
      q.id = this.getString(rs, 'id')
      q.userId = this.getString(rs, 'user_id')
      q.sessionId = this.getString(rs, 'session_id')
      q.question = this.getString(rs, 'question')
      q.answer = this.getString(rs, 'answer')
      q.createdAt = this.getNum(rs, 'created_at')
      list.push(q)
    }
    rs.close()
    return list
  }

  async saveQuestion(q: QuestionRecord): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': q.id,
      'user_id': q.userId,
      'session_id': q.sessionId,
      'question': q.question,
      'answer': q.answer,
      'created_at': q.createdAt
    }
    await this.store.insert('question', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- 手表事件 & 观察记录 ----------
  async saveWatchEvents(list: WatchEvent[]): Promise<void> {
    for (const e of list) {
      const v: relationalStore.ValuesBucket = {
        'id': e.id,
        'session_id': e.sessionId,
        't_ms': e.tMs,
        'kind': e.kind.toString(),
        'rmssd': e.rmssd,
        'hr': e.hr,
        'accel_var': e.accelVar,
        'reason': e.reason,
        'triggered': e.triggered ? 1 : 0
      }
      await this.store.insert('watch_event', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
    }
  }

  async saveObservation(o: ObservationRecord): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': o.id,
      'session_id': o.sessionId,
      'event_id': o.eventId,
      't_ms': o.tMs,
      'activity': o.activity,
      'handheld': o.handheld ? 1 : 0,
      'facing_desk': o.facingDesk ? 1 : 0,
      'confidence': o.confidence,
      'evidence': o.evidence,
      'image_paths': JSON.stringify(o.imagePaths)
    }
    await this.store.insert('observation', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  /** 某次会话的观察记录（复盘时间线用），按时间升序 */
  async loadObservations(sessionId: string): Promise<ObservationRecord[]> {
    const p = new relationalStore.RdbPredicates('observation')
    p.equalTo('session_id', sessionId)
    p.orderByAsc('t_ms')
    const rs = await this.store.query(p)
    const list: ObservationRecord[] = []
    while (rs.goToNextRow()) {
      const o = new ObservationRecord()
      o.id = this.getString(rs, 'id')
      o.sessionId = this.getString(rs, 'session_id')
      o.eventId = this.getString(rs, 'event_id')
      o.tMs = this.getNum(rs, 't_ms')
      o.activity = this.getString(rs, 'activity')
      o.handheld = this.getNum(rs, 'handheld') === 1
      o.facingDesk = this.getNum(rs, 'facing_desk') === 1
      o.confidence = this.getNum(rs, 'confidence')
      o.evidence = this.getString(rs, 'evidence')
      o.imagePaths = this.parseStringArray(this.getString(rs, 'image_paths'))
      list.push(o)
    }
    rs.close()
    return list
  }

  /**
   * 清空画面片段的图片引用（观察记录本身保留 —— 它们同时是复盘的"干扰事件"）。
   * 「清除已保存的画面片段」只删帧文件是不够的：库里还留着路径，时间线会渲染出空白图。
   */
  async clearObservationImages(): Promise<void> {
    const v: relationalStore.ValuesBucket = { 'image_paths': '[]' }
    await this.store.update(v, new relationalStore.RdbPredicates('observation'))
  }

  // ---------- StudyReport ----------
  async loadReport(sessionId: string): Promise<StudyReport | null> {
    const p = new relationalStore.RdbPredicates('study_report')
    p.equalTo('session_id', sessionId)
    const rs = await this.store.query(p)
    if (!rs.goToNextRow()) {
      rs.close()
      return null
    }
    const r = new StudyReport()
    r.sessionId = this.getString(rs, 'session_id')
    r.completionRate = this.getReal(rs, 'completion_rate')
    r.focusRate = this.getReal(rs, 'focus_rate')
    r.bestFocusPeriod = this.getString(rs, 'best_focus_period')
    r.fatiguePoint = this.getNum(rs, 'fatigue_point')
    r.distractionTriggers = this.parseStringArray(this.getString(rs, 'distraction_triggers'))
    r.suggestions = this.parseStringArray(this.getString(rs, 'suggestions'))
    r.insights = this.getString(rs, 'insights')
    r.questions = this.parseQuestions(this.getString(rs, 'questions'))
    r.createdAt = this.getNum(rs, 'created_at')
    rs.close()
    return r
  }

  async saveReport(r: StudyReport): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'session_id': r.sessionId,
      'completion_rate': r.completionRate,
      'focus_rate': r.focusRate,
      'best_focus_period': r.bestFocusPeriod,
      'fatigue_point': r.fatiguePoint,
      'distraction_triggers': JSON.stringify(r.distractionTriggers),
      'suggestions': JSON.stringify(r.suggestions),
      'insights': r.insights,
      'questions': JSON.stringify(r.questions),
      'created_at': r.createdAt
    }
    await this.store.insert('study_report', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- FocusProfile ----------
  async loadProfile(): Promise<FocusProfile | null> {
    const rs = await this.store.query(new relationalStore.RdbPredicates('focus_profile'))
    if (!rs.goToNextRow()) {
      rs.close()
      return null
    }
    const f = new FocusProfile()
    f.id = this.getString(rs, 'id')
    f.bestFocusTime = this.getString(rs, 'best_focus_time')
    f.averageFocusDuration = this.getNum(rs, 'average_focus_duration')
    f.focusThreshold = this.getNum(rs, 'focus_threshold')
    f.efficiency = this.getNum(rs, 'efficiency')
    f.concentration = this.getNum(rs, 'concentration')
    f.stability = this.getNum(rs, 'stability')
    f.execution = this.getNum(rs, 'execution')
    f.antiDistraction = this.getNum(rs, 'anti_distraction')
    f.weeklyTrend = this.parseNumberArray(this.getString(rs, 'weekly_trend'))
    f.monthlyTrend = this.parseNumberArray(this.getString(rs, 'monthly_trend'))
    f.sampleCount = this.getNum(rs, 'sample_count')
    f.recentConcentrations = this.parseNumberArray(this.getString(rs, 'recent_concentrations'))
    f.recentDistractionRates = this.parseNumberArray(this.getString(rs, 'recent_distraction_rates'))
    f.updatedAt = this.getNum(rs, 'updated_at')
    rs.close()
    return f
  }

  async saveProfile(f: FocusProfile): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': f.id,
      'best_focus_time': f.bestFocusTime,
      'average_focus_duration': f.averageFocusDuration,
      'focus_threshold': f.focusThreshold,
      'efficiency': f.efficiency,
      'concentration': f.concentration,
      'stability': f.stability,
      'execution': f.execution,
      'anti_distraction': f.antiDistraction,
      'weekly_trend': JSON.stringify(f.weeklyTrend),
      'monthly_trend': JSON.stringify(f.monthlyTrend),
      'sample_count': f.sampleCount,
      'recent_concentrations': JSON.stringify(f.recentConcentrations),
      'recent_distraction_rates': JSON.stringify(f.recentDistractionRates),
      'updated_at': f.updatedAt
    }
    await this.store.insert('focus_profile', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- Authorization（PRD §17 全局唯一事实源）----------
  async loadAuthorization(): Promise<Authorization | null> {
    const rs = await this.store.query(new relationalStore.RdbPredicates('authorization'))
    if (!rs.goToNextRow()) {
      rs.close()
      return null
    }
    const a = new Authorization()
    a.camera = this.getBool(rs, 'camera')
    a.microphone = this.getBool(rs, 'microphone')
    a.health = this.getBool(rs, 'health')
    a.notification = this.getBool(rs, 'notification')
    a.updatedAt = this.getNum(rs, 'updated_at')
    rs.close()
    return a
  }

  async saveAuthorization(a: Authorization): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': 'global',
      'camera': a.camera ? 1 : 0,
      'microphone': a.microphone ? 1 : 0,
      'health': a.health ? 1 : 0,
      'notification': a.notification ? 1 : 0,
      'updated_at': a.updatedAt
    }
    await this.store.insert('authorization', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- SessionSnapshot（§4 每 10s 落盘，支持崩溃/后台恢复）----------
  async saveSnapshot(snap: SessionSnapshot): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'session_id': snap.sessionId,
      'ts': snap.ts,
      'total_sec': snap.totalSec,
      'focus_sec': snap.focusSec,
      'distraction_sec': snap.distractionSec,
      'qa_sec': snap.qaSec,
      'break_sec': snap.breakSec,
      'current_task_id': snap.currentTaskId,
      'state': snap.state,
      'perception_mode': snap.perceptionMode,
      'start_time': snap.startTime
    }
    await this.store.insert('session_snapshot', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  async loadSnapshots(sessionId: string): Promise<SessionSnapshot[]> {
    const p = new relationalStore.RdbPredicates('session_snapshot')
    p.equalTo('session_id', sessionId)
    const rs = await this.store.query(p)
    const list: SessionSnapshot[] = []
    while (rs.goToNextRow()) {
      const s = new SessionSnapshot()
      s.sessionId = this.getString(rs, 'session_id')
      s.ts = this.getNum(rs, 'ts')
      s.totalSec = this.getNum(rs, 'total_sec')
      s.focusSec = this.getNum(rs, 'focus_sec')
      s.distractionSec = this.getNum(rs, 'distraction_sec')
      s.qaSec = this.getNum(rs, 'qa_sec')
      s.breakSec = this.getNum(rs, 'break_sec')
      s.currentTaskId = this.getString(rs, 'current_task_id')
      s.state = this.getString(rs, 'state') || 'FOCUSED'
      s.perceptionMode = this.getString(rs, 'perception_mode') || 'PERCEPTION_FULL'
      s.startTime = this.getNum(rs, 'start_time')
      list.push(s)
    }
    rs.close()
    return list
  }

  async loadLatestSnapshot(sessionId: string): Promise<SessionSnapshot | null> {
    const list = await this.loadSnapshots(sessionId)
    if (list.length === 0) {
      return null
    }
    let latest = list[0]
    for (const s of list) {
      if (s.ts > latest.ts) {
        latest = s
      }
    }
    return latest
  }

  async deleteSnapshots(sessionId: string): Promise<void> {
    const p = new relationalStore.RdbPredicates('session_snapshot')
    p.equalTo('session_id', sessionId)
    await this.store.delete(p)
  }

  // ---------- InterventionEvent（§9 反馈回收）----------
  async saveIntervention(e: InterventionEvent): Promise<void> {
    const v: relationalStore.ValuesBucket = {
      'id': e.id,
      'session_id': e.sessionId,
      'ts': e.ts,
      'level': e.level,
      'channel': e.channel,
      'message': e.message,
      'source': e.source,
      'user_feedback': e.userFeedback,
      'recovered_focus': e.recoveredFocus ? 1 : 0,
      'payload_json': e.payloadJson
    }
    await this.store.insert('intervention_event', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  async saveInterventions(list: InterventionEvent[]): Promise<void> {
    for (const e of list) {
      await this.saveIntervention(e)
    }
  }

  async loadInterventions(sessionId: string): Promise<InterventionEvent[]> {
    const p = new relationalStore.RdbPredicates('intervention_event')
    p.equalTo('session_id', sessionId)
    const rs = await this.store.query(p)
    const list: InterventionEvent[] = []
    while (rs.goToNextRow()) {
      const e = new InterventionEvent()
      e.id = this.getString(rs, 'id')
      e.sessionId = this.getString(rs, 'session_id')
      e.ts = this.getNum(rs, 'ts')
      e.level = this.getString(rs, 'level') as InterventionLevel
      e.channel = this.getString(rs, 'channel')
      e.message = this.getString(rs, 'message')
      e.source = this.getString(rs, 'source') as FocusSource
      e.userFeedback = this.getString(rs, 'user_feedback') as FeedbackAction
      e.recoveredFocus = this.getBool(rs, 'recovered_focus')
      e.payloadJson = this.getString(rs, 'payload_json')
      list.push(e)
    }
    rs.close()
    return list
  }

  // ---------- StudyPlan（§12，单记录）----------
  /**
   * 保存长期计划。**强制固定 id** —— `ON_CONFLICT_REPLACE` 按主键覆盖，固定 id 即天然单行。
   * 老版本每次保存都 `new uuid` 新增一行，是"表里累积多条、读回不确定"的根源。
   */
  async saveStudyPlan(plan: StudyPlan): Promise<void> {
    plan.id = StudyPlan.PLAN_SINGLETON_ID
    if (plan.updatedAt <= 0) {
      plan.updatedAt = Date.now()
    }
    const v: relationalStore.ValuesBucket = {
      'id': plan.id,
      'title': plan.title,
      'total_estimated_minutes': plan.totalEstimatedMinutes,
      'subject_targets': JSON.stringify(plan.subjectTargets),
      'period_start': plan.periodStart,
      'period_end': plan.periodEnd,
      'created_at': plan.createdAt,
      'updated_at': plan.updatedAt
    }
    await this.store.insert('study_plan', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  /**
   * 读长期计划。**必须排序**：老库可能有 N 行（历次保存各一行），
   * 不带 `orderBy` 的查询读回哪一行是不确定的。固定 id 优先命中，否则取最近更新的一行。
   *
   * 同时做 D4 的一次性迁移：老记录只有总目标、没有分科 → 把旧总值包成一条
   * **未分配目标**（`subject === ''`）并写回固定 id。不静默分摊 —— 分摊要用户点按钮。
   */
  async loadStudyPlan(): Promise<StudyPlan | null> {
    const q = new relationalStore.RdbPredicates('study_plan')
    q.orderByDesc('updated_at')
    const rs = await this.store.query(q)
    let found: StudyPlan | null = null
    let fallback: StudyPlan | null = null
    while (rs.goToNextRow()) {
      const p = new StudyPlan()
      p.id = this.getString(rs, 'id')
      p.title = this.getString(rs, 'title')
      p.totalEstimatedMinutes = this.getNum(rs, 'total_estimated_minutes')
      p.subjectTargets = this.parseSubjectTargets(this.getString(rs, 'subject_targets'))
      p.periodStart = this.getNum(rs, 'period_start')
      p.periodEnd = this.getNum(rs, 'period_end')
      p.createdAt = this.getNum(rs, 'created_at')
      p.updatedAt = this.getNum(rs, 'updated_at')
      if (p.id === StudyPlan.PLAN_SINGLETON_ID) {
        found = p
        break
      }
      if (fallback === null) {
        fallback = p
      }
    }
    rs.close()
    const p = found !== null ? found : fallback
    if (p === null) {
      return null
    }
    if (p.subjectTargets.length === 0 && p.totalEstimatedMinutes > 0) {
      // 迁移：旧总值 → "未分配目标"；写回固定 id（幂等：下次 subjectTargets 就不再为空）
      p.subjectTargets = [SubjectTarget.create('', p.totalEstimatedMinutes)]
      StudyPlan.recomputeTotal(p)
      p.id = StudyPlan.PLAN_SINGLETON_ID
      p.updatedAt = Date.now()
      await this.saveStudyPlan(p).catch(() => {
        // 迁移写回失败不影响本次读取结果
      })
      hilog.info(0x0000, 'iKnow.Store', '长期计划已迁移为分科结构（保留未分配总额 %{public}d 分钟）',
        p.totalEstimatedMinutes)
    }
    return p
  }

  // ---------- TaskTimeline（§12 任务归属曲线）----------
  async saveTaskTimeline(points: TaskTimelinePoint[], sessionId: string): Promise<void> {
    for (const p of points) {
      const v: relationalStore.ValuesBucket = {
        'session_id': sessionId,
        'minute_offset': p.minuteOffset,
        'task_id': p.taskId,
        'level': p.level
      }
      await this.store.insert('task_timeline', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
    }
  }

  async loadTaskTimeline(sessionId: string): Promise<TaskTimelinePoint[]> {
    const p = new relationalStore.RdbPredicates('task_timeline')
    p.equalTo('session_id', sessionId)
    const rs = await this.store.query(p)
    const list: TaskTimelinePoint[] = []
    while (rs.goToNextRow()) {
      const t = new TaskTimelinePoint()
      t.minuteOffset = this.getNum(rs, 'minute_offset')
      t.taskId = this.getString(rs, 'task_id')
      t.level = this.getNum(rs, 'level')
      list.push(t)
    }
    rs.close()
    return list
  }

  // ---------- 轻量 KV（跨崩溃持久化标记，如进行中会话 id）----------
  async saveKv(key: string, value: string): Promise<void> {
    const v: relationalStore.ValuesBucket = { 'key': key, 'value': value }
    await this.store.insert('app_kv', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  async loadKv(key: string): Promise<string> {
    const p = new relationalStore.RdbPredicates('app_kv')
    p.equalTo('key', key)
    const rs = await this.store.query(p)
    if (!rs.goToNextRow()) {
      rs.close()
      return ''
    }
    const val = this.getString(rs, 'value')
    rs.close()
    return val
  }

  // ---------- 清除 ----------
  async clearAll(): Promise<void> {
    const tables: string[] = [
      'user', 'learning_goal', 'task', 'focus_session', 'question', 'study_report', 'focus_profile',
      'authorization', 'session_snapshot', 'intervention_event', 'study_plan', 'task_timeline', 'app_kv',
      // 生理记录与画面观察记录也是实际在写的表：漏掉它们，"一键清除"就清不干净
      'watch_event', 'observation'
    ]
    for (let i = 0; i < tables.length; i++) {
      await this.store.delete(new relationalStore.RdbPredicates(tables[i]))
    }
  }

  /**
   * 只清"学习记录"：会话 / 任务 / 报告 / 画像 / 快照 / 干预 / 时间线 / 生理与观察记录。
   * 保留 user、learning_goal、authorization、study_plan、app_kv ——
   * 「清除学习数据」不该动身份、目标与授权（清了身份会直接跳过引导页，那不是这个按钮该干的事）。
   */
  async clearLearningTables(): Promise<void> {
    const tables: string[] = [
      'task', 'focus_session', 'question', 'study_report', 'focus_profile', 'session_snapshot',
      'intervention_event', 'task_timeline', 'watch_event', 'observation'
    ]
    for (let i = 0; i < tables.length; i++) {
      await this.store.delete(new relationalStore.RdbPredicates(tables[i]))
    }
  }

  /** 清除生理记录（心率 / HRV）。「清除生理数据」用它，不能再靠空实现假装没有数据 */
  async clearWatchEvents(): Promise<void> {
    await this.store.delete(new relationalStore.RdbPredicates('watch_event'))
  }
}
