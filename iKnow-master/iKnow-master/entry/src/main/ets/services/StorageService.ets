import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { User } from '../models/User'
import { LearningGoal, Task } from '../models/Task'
import { FocusSession, FocusEvent, FocusTimelinePoint } from '../models/FocusSession'
import { QuestionRecord } from '../models/QuestionRecord'
import { StudyReport } from '../models/StudyReport'
import { FocusProfile } from '../models/FocusProfile'
import { AIPersonality, TaskStatus, SessionStatus } from '../models/Enums'

const DB_NAME = 'iKnow.db'

/**
 * 持久化层 —— 基于 @ohos.data.relationalStore（经 @kit.ArkData 暴露）
 * 所有学习数据、画像、会话、复盘均落库，App 重启后仍保留
 */
export class StorageService {
  private static inst: StorageService | null = null
  private rdb: relationalStore.RdbStore | null = null

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
    await this.createTables()
  }

  private async createTables(): Promise<void> {
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS user (
      id TEXT PRIMARY KEY, nickname TEXT, avatar TEXT, ai_personality TEXT, created_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS learning_goal (
      id TEXT PRIMARY KEY, title TEXT, exam_type TEXT, target_date INTEGER, subjects TEXT)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS task (
      id TEXT PRIMARY KEY, title TEXT, subject TEXT, estimated_duration INTEGER,
      actual_duration INTEGER, status TEXT, done INTEGER, sort_order INTEGER,
      session_id TEXT, created_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS focus_session (
      id TEXT PRIMARY KEY, title TEXT, start_time INTEGER, end_time INTEGER,
      total_duration INTEGER, focus_duration INTEGER, distraction_duration INTEGER,
      qa_duration INTEGER, break_duration INTEGER, planned_duration INTEGER,
      task_ids TEXT, completed_task_ids TEXT, timeline TEXT, events TEXT, status TEXT)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS question (
      id TEXT PRIMARY KEY, session_id TEXT, question TEXT, answer TEXT, created_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS study_report (
      session_id TEXT PRIMARY KEY, completion_rate REAL, focus_rate REAL,
      best_focus_period TEXT, fatigue_point INTEGER, distraction_triggers TEXT,
      suggestions TEXT, insights TEXT, questions TEXT, created_at INTEGER)`)
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS focus_profile (
      id TEXT PRIMARY KEY, best_focus_time TEXT, average_focus_duration INTEGER,
      focus_threshold INTEGER, efficiency INTEGER, concentration INTEGER,
      stability INTEGER, execution INTEGER, anti_distraction INTEGER,
      weekly_trend TEXT, monthly_trend TEXT, updated_at INTEGER)`)
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

  private parseEvents(json: string): FocusEvent[] {
    try {
      const a = JSON.parse(json) as FocusEvent[]
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
      t.done = this.getNum(rs, 'done') === 1
      t.sortOrder = this.getNum(rs, 'sort_order')
      t.sessionId = this.getString(rs, 'session_id')
      t.createdAt = this.getNum(rs, 'created_at')
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
      'created_at': t.createdAt
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
      s.plannedDuration = this.getNum(rs, 'planned_duration')
      s.taskIds = this.parseStringArray(this.getString(rs, 'task_ids'))
      s.completedTaskIds = this.parseStringArray(this.getString(rs, 'completed_task_ids'))
      s.timeline = this.parseTimeline(this.getString(rs, 'timeline'))
      s.events = this.parseEvents(this.getString(rs, 'events'))
      s.status = this.getString(rs, 'status') as SessionStatus
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
      'planned_duration': s.plannedDuration,
      'task_ids': JSON.stringify(s.taskIds),
      'completed_task_ids': JSON.stringify(s.completedTaskIds),
      'timeline': JSON.stringify(s.timeline),
      'events': JSON.stringify(s.events),
      'status': s.status
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
      'session_id': q.sessionId,
      'question': q.question,
      'answer': q.answer,
      'created_at': q.createdAt
    }
    await this.store.insert('question', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
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
      'updated_at': f.updatedAt
    }
    await this.store.insert('focus_profile', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  // ---------- 清除 ----------
  async clearAll(): Promise<void> {
    const tables: string[] = ['user', 'learning_goal', 'task', 'focus_session', 'question', 'study_report', 'focus_profile']
    for (let i = 0; i < tables.length; i++) {
      await this.store.delete(new relationalStore.RdbPredicates(tables[i]))
    }
  }
}
