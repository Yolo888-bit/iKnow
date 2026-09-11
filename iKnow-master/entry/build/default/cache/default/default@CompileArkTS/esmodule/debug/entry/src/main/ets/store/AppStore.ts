import type common from "@ohos:app.ability.common";
import { User } from "@normalized:N&&&entry/src/main/ets/models/User&";
import { Task, LearningGoal } from "@normalized:N&&&entry/src/main/ets/models/Task&";
import type { FocusSession } from '../models/FocusSession';
import type { StudyReport } from '../models/StudyReport';
import { FocusProfile } from "@normalized:N&&&entry/src/main/ets/models/FocusProfile&";
import { Dashboard, SubjectProgress } from "@normalized:N&&&entry/src/main/ets/models/Dashboard&";
import { AIPersonality, TaskStatus } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
import { StorageService } from "@normalized:N&&&entry/src/main/ets/services/StorageService&";
import { AIService } from "@normalized:N&&&entry/src/main/ets/services/AIService&";
import { ReportService } from "@normalized:N&&&entry/src/main/ets/services/ReportService&";
import { FocusController } from "@normalized:N&&&entry/src/main/ets/services/FocusController&";
import { PermissionService } from "@normalized:N&&&entry/src/main/ets/services/PermissionService&";
import { Metrics } from "@normalized:N&&&entry/src/main/ets/services/Metrics&";
import { StorageKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
import { TimeUtils } from "@normalized:N&&&entry/src/main/ets/utils/TimeUtils&";
/**
 * AppStore —— 单一事实源（Vuex 风格）
 * 所有读写都经过这里，并同步到 StorageService 持久化 + AppStorage 响应式。
 * 页面只与 AppStore / Service 交互，不直接写死 Mock 数据。
 */
export class AppStore {
    private static inst: AppStore | null = null;
    private user: User = new User();
    private goal: LearningGoal = new LearningGoal();
    private tasks: Task[] = [];
    private sessions: FocusSession[] = [];
    private profile: FocusProfile = new FocusProfile();
    private dashboard: Dashboard = new Dashboard();
    private currentPlan: Task[] = [];
    private currentReport: StudyReport | null = null;
    private currentSession: FocusSession | null = null;
    private initialized: boolean = false;
    private initPromise: Promise<void> | null = null;
    static getInstance(): AppStore {
        if (AppStore.inst === null) {
            AppStore.inst = new AppStore();
        }
        return AppStore.inst;
    }
    async init(context: common.Context): Promise<void> {
        if (this.initPromise === null) {
            this.initPromise = this.doInit(context);
        }
        return this.initPromise;
    }
    private async doInit(context: common.Context): Promise<void> {
        if (this.initialized) {
            return;
        }
        await StorageService.getInstance().init(context);
        await PermissionService.getInstance().init();
        AppStorage.setOrCreate<number>(StorageKey.METRICS_MIN_SAMPLES, Metrics.MIN_SAMPLES);
        this.initAppStorageDefaults();
        const user = await StorageService.getInstance().loadUser();
        if (user === null) {
            await this.seed();
        }
        else {
            this.user = user;
            this.tasks = await StorageService.getInstance().loadTasks();
            this.sessions = await StorageService.getInstance().loadSessions();
            const g = await StorageService.getInstance().loadGoal();
            this.goal = g !== null ? g : new LearningGoal();
            const p = await StorageService.getInstance().loadProfile();
            this.profile = p !== null ? p : new FocusProfile();
        }
        await this.refreshAggregates();
        this.initialized = true;
    }
    private initAppStorageDefaults(): void {
        AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, '刘灿');
        AppStorage.setOrCreate<string>(StorageKey.USER_AVATAR, '🧑‍🎓');
        AppStorage.setOrCreate<string>(StorageKey.USER_PERSONALITY, AIPersonality.GENTLE);
        AppStorage.setOrCreate<number>(StorageKey.TODAY_FOCUS_SEC, 0);
        AppStorage.setOrCreate<number>(StorageKey.TODAY_NET_FOCUS_SEC, 0);
        AppStorage.setOrCreate<number>(StorageKey.TODAY_DONE_TASKS, 0);
        AppStorage.setOrCreate<number>(StorageKey.TODAY_TOTAL_TASKS, 0);
        AppStorage.setOrCreate<number>(StorageKey.FOCUS_RATE, 0);
        AppStorage.setOrCreate<number>(StorageKey.WEEK_FOCUS_SEC, 0);
        AppStorage.setOrCreate<string>(StorageKey.WEEK_TREND, '[]');
        AppStorage.setOrCreate<number>(StorageKey.EXAM_DAYS, 0);
        AppStorage.setOrCreate<number>(StorageKey.DATA_VERSION, 0);
        AppStorage.setOrCreate<number>(StorageKey.FOCUS_ELAPSED, 0);
        AppStorage.setOrCreate<number>(StorageKey.FOCUS_NET, 0);
        AppStorage.setOrCreate<string>(StorageKey.FOCUS_STATE, 'FOCUSED');
        AppStorage.setOrCreate<number>(StorageKey.FOCUS_QA_ELAPSED, 0);
    }
    // ---------- 首次启动种子数据（空模板，硬规则 §5：冷启动不得伪造五维/会话）----------
    private async seed(): Promise<void> {
        const now = Date.now();
        const u = new User();
        u.id = IdUtils.uuid();
        u.nickname = '刘灿';
        u.avatar = '🧑‍🎓';
        u.aiPersonality = AIPersonality.GENTLE;
        u.createdAt = now;
        await StorageService.getInstance().saveUser(u);
        this.user = u;
        const g = new LearningGoal();
        g.id = IdUtils.uuid();
        g.title = '考研上岸';
        g.examType = '考研';
        g.targetDate = now + 128 * 24 * 3600 * 1000;
        g.subjects = ['高等数学', '英语', '政治'];
        await StorageService.getInstance().saveGoal(g);
        this.goal = g;
        // 画像保持空模板：sampleCount = 0，五维全 0，UI 显示"还在了解你"
        const p = new FocusProfile();
        p.id = IdUtils.uuid();
        p.bestFocusTime = '09:30 - 11:30';
        p.updatedAt = now;
        await StorageService.getInstance().saveProfile(p);
        this.profile = p;
        // 不预置任何会话 / 任务：用户首次跑通后才会产生真实数据
        this.sessions = [];
        this.tasks = [];
    }
    // ---------- Getters ----------
    getUser(): User {
        return this.user;
    }
    getGoal(): LearningGoal {
        return this.goal;
    }
    getTasks(): Task[] {
        return this.tasks;
    }
    getSessions(): FocusSession[] {
        return this.sessions;
    }
    getProfile(): FocusProfile {
        return this.profile;
    }
    getDashboard(): Dashboard {
        return this.dashboard;
    }
    getCurrentPlan(): Task[] {
        return this.currentPlan;
    }
    getCurrentReport(): StudyReport | null {
        return this.currentReport;
    }
    getCurrentSession(): FocusSession | null {
        return this.currentSession;
    }
    // ---------- 用户 & 目标 ----------
    async saveUserNickname(nickname: string): Promise<void> {
        this.user.nickname = nickname;
        await StorageService.getInstance().saveUser(this.user);
        AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, nickname);
    }
    async saveUserPersonality(p: AIPersonality): Promise<void> {
        this.user.aiPersonality = p;
        AIService.getInstance().setPersonality(p);
        await StorageService.getInstance().saveUser(this.user);
        AppStorage.setOrCreate<string>(StorageKey.USER_PERSONALITY, p);
    }
    async saveGoal(goal: LearningGoal): Promise<void> {
        this.goal = goal;
        await StorageService.getInstance().saveGoal(goal);
        this.pushAggregates();
    }
    // ---------- 规划 ----------
    async planTasks(input: string): Promise<Task[]> {
        return await AIService.getInstance().planTasks(input);
    }
    setCurrentPlan(tasks: Task[]): void {
        this.currentPlan = tasks;
    }
    addPlanTask(title: string, subject: string, minutes: number): void {
        const t = new Task();
        t.id = IdUtils.uuid();
        t.title = title;
        t.subject = subject;
        t.estimatedDuration = minutes;
        t.sortOrder = this.currentPlan.length;
        t.createdAt = Date.now();
        this.currentPlan.push(t);
    }
    removePlanTask(id: string): void {
        const next: Task[] = [];
        for (const t of this.currentPlan) {
            if (t.id !== id) {
                next.push(t);
            }
        }
        this.currentPlan = next;
    }
    togglePlanTask(id: string): void {
        for (const t of this.currentPlan) {
            if (t.id === id) {
                t.done = !t.done;
                t.status = t.done ? TaskStatus.DONE : TaskStatus.TODO;
            }
        }
    }
    // ---------- 结束会话 → 复盘 → 画像 → 工作台联动 ----------
    async endSession(): Promise<StudyReport | null> {
        const controller = FocusController.getInstance();
        if (!controller.isRunning()) {
            return this.currentReport;
        }
        const session = controller.finalize();
        const questions = controller.getQuestions();
        const tasks = controller.getTasks();
        const report = await ReportService.getInstance().buildReport(session, questions);
        await StorageService.getInstance().saveSession(session);
        for (const t of tasks) {
            await StorageService.getInstance().saveTask(t);
        }
        for (const q of questions) {
            await StorageService.getInstance().saveQuestion(q);
        }
        await StorageService.getInstance().saveReport(report);
        this.sessions = await StorageService.getInstance().loadSessions();
        this.tasks = await StorageService.getInstance().loadTasks();
        this.profile = AIService.getInstance().updateProfile(this.profile, this.sessions);
        await StorageService.getInstance().saveProfile(this.profile);
        await this.refreshAggregates();
        this.currentSession = session;
        this.currentReport = report;
        this.currentPlan = [];
        return report;
    }
    // ---------- 聚合 & 响应式刷新 ----------
    async refreshAggregates(): Promise<void> {
        const now = Date.now();
        let todayFocus = 0;
        let todayNet = 0;
        let weekFocus = 0;
        const weekStart = TimeUtils.dayStart(now) - 6 * 24 * 3600 * 1000;
        for (const s of this.sessions) {
            if (TimeUtils.isSameDay(s.startTime, now)) {
                todayFocus += s.totalDuration;
                todayNet += s.focusDuration;
            }
            if (s.startTime >= weekStart) {
                weekFocus += s.focusDuration;
            }
        }
        let done = 0;
        let total = 0;
        for (const t of this.tasks) {
            if (TimeUtils.isSameDay(t.createdAt, now)) {
                total += 1;
                if (t.done) {
                    done += 1;
                }
            }
        }
        const d = new Dashboard();
        d.todayFocusSeconds = todayFocus;
        d.todayNetFocusSeconds = todayNet;
        d.focusRate = todayFocus > 0 ? Math.round(todayNet / todayFocus * 100) : 0;
        d.weekFocusSeconds = weekFocus;
        d.weekTrend = this.computeWeekTrend(now);
        d.todayCompletedTasks = done;
        d.todayTotalTasks = total;
        d.subjectProgress = this.computeSubjectProgress();
        this.dashboard = d;
        this.pushAggregates();
    }
    private computeWeekTrend(now: number): number[] {
        const arr: number[] = [];
        for (let day = 6; day >= 0; day--) {
            const dayStart = TimeUtils.dayStart(now) - day * 24 * 3600 * 1000;
            const dayEnd = dayStart + 24 * 3600 * 1000;
            let net = 0;
            for (const s of this.sessions) {
                if (s.startTime >= dayStart && s.startTime < dayEnd) {
                    net += s.focusDuration;
                }
            }
            arr.push(Math.round(net / 60));
        }
        return arr;
    }
    private computeSubjectProgress(): SubjectProgress[] {
        const map: Map<string, SubjectProgress> = new Map<string, SubjectProgress>();
        for (const t of this.tasks) {
            let sp = map.get(t.subject);
            if (sp === undefined) {
                sp = new SubjectProgress();
                sp.subject = t.subject;
                map.set(t.subject, sp);
            }
            sp.total += 1;
            if (t.done) {
                sp.completed += 1;
            }
        }
        const list: SubjectProgress[] = [];
        map.forEach((value: SubjectProgress, key: string) => {
            value.percent = value.total > 0 ? Math.round(value.completed / value.total * 100) : 0;
            list.push(value);
        });
        return list;
    }
    private pushAggregates(): void {
        AppStorage.setOrCreate<number>(StorageKey.TODAY_FOCUS_SEC, this.dashboard.todayFocusSeconds);
        AppStorage.setOrCreate<number>(StorageKey.TODAY_NET_FOCUS_SEC, this.dashboard.todayNetFocusSeconds);
        AppStorage.setOrCreate<number>(StorageKey.TODAY_DONE_TASKS, this.dashboard.todayCompletedTasks);
        AppStorage.setOrCreate<number>(StorageKey.TODAY_TOTAL_TASKS, this.dashboard.todayTotalTasks);
        AppStorage.setOrCreate<number>(StorageKey.FOCUS_RATE, this.dashboard.focusRate);
        AppStorage.setOrCreate<number>(StorageKey.WEEK_FOCUS_SEC, this.dashboard.weekFocusSeconds);
        AppStorage.setOrCreate<string>(StorageKey.WEEK_TREND, JSON.stringify(this.dashboard.weekTrend));
        AppStorage.setOrCreate<string>(StorageKey.USER_NICKNAME, this.user.nickname);
        AppStorage.setOrCreate<string>(StorageKey.USER_AVATAR, this.user.avatar);
        AppStorage.setOrCreate<string>(StorageKey.USER_PERSONALITY, this.user.aiPersonality);
        const days = TimeUtils.daysUntil(this.goal.targetDate, Date.now());
        AppStorage.setOrCreate<number>(StorageKey.EXAM_DAYS, days);
        let ver = 0;
        const cur: number | undefined = AppStorage.get<number>(StorageKey.DATA_VERSION);
        if (cur !== undefined) {
            ver = cur;
        }
        AppStorage.setOrCreate<number>(StorageKey.DATA_VERSION, ver + 1);
    }
    // ---------- 数据清除（合规） ----------
    async clearAll(): Promise<void> {
        await StorageService.getInstance().clearAll();
        // 重置为「零状态」，但保留一个可用账号，避免下次启动误触种子
        const now = Date.now();
        const u = new User();
        u.id = IdUtils.uuid();
        u.nickname = '刘灿';
        u.avatar = '🧑‍🎓';
        u.aiPersonality = AIPersonality.GENTLE;
        u.createdAt = now;
        await StorageService.getInstance().saveUser(u);
        const g = new LearningGoal();
        g.id = IdUtils.uuid();
        g.title = '考研上岸';
        g.examType = '考研';
        g.targetDate = now + 128 * 24 * 3600 * 1000;
        g.subjects = ['高等数学', '英语', '政治'];
        await StorageService.getInstance().saveGoal(g);
        const p = new FocusProfile();
        p.id = IdUtils.uuid();
        p.bestFocusTime = '09:30 - 11:30';
        p.updatedAt = now;
        await StorageService.getInstance().saveProfile(p);
        this.user = u;
        this.goal = g;
        this.profile = p;
        this.tasks = [];
        this.sessions = [];
        this.currentPlan = [];
        this.currentReport = null;
        this.currentSession = null;
        this.dashboard = new Dashboard();
        this.pushAggregates();
    }
    async clearLearningData(): Promise<void> {
        await this.clearAll();
    }
    async clearPhysioData(): Promise<void> {
        // MVP 阶段生理数据为模拟，不落盘；此方法预留真实实现位
    }
}
