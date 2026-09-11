import type { AIService, AIScene, AIRequest, AIResponse } from './AIService';
import { QA_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/QAService&";
import type { QATextPayload, QAImagePayload, QAResp, QAService } from "@normalized:N&&&entry/src/main/ets/services/ai/QAService&";
import { COMPANION_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/CompanionService&";
import type { CompanionContext, CompanionDecision, CompanionService } from "@normalized:N&&&entry/src/main/ets/services/ai/CompanionService&";
import { REVIEW_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/ReviewService&";
import type { ReviewPayload, ReviewData, ReviewService } from "@normalized:N&&&entry/src/main/ets/services/ai/ReviewService&";
import { PLANNING_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/PlanningService&";
import type { PlanningInput, PlanningResult, PlanningDialogInput, PlanningDialogResult, PlanningService } from "@normalized:N&&&entry/src/main/ets/services/ai/PlanningService&";
import { MEMORY_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/MemoryService&";
import type { MemoryPayload, MemoryDelta, ProfileFields, MemoryService } from "@normalized:N&&&entry/src/main/ets/services/ai/MemoryService&";
import { SchemaValidator } from "@normalized:N&&&entry/src/main/ets/services/ai/SchemaValidator&";
import type { FocusSession } from '../../models/FocusSession';
import type { FocusProfile } from '../../models/FocusProfile';
import { PlanTask } from "@normalized:N&&&entry/src/main/ets/models/StudyPlan&";
import { Task } from "@normalized:N&&&entry/src/main/ets/models/Task&";
import type { StudyReport } from '../../models/StudyReport';
import { Metrics } from "@normalized:N&&&entry/src/main/ets/services/Metrics&";
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
interface RetryConfig {
    timeoutMs: number;
    retries: number;
}
interface WordingLevel {
    light: string;
    heavy: string;
}
interface WordingMap {
    GENTLE: WordingLevel;
    STRICT: WordingLevel;
    QUIET: WordingLevel;
    ADAPTIVE: WordingLevel;
}
/**
 * 本地 Mock AI 服务实现（PRD §13 / §14）
 *
 *  - 实现 5 个独立接口（QAService / CompanionService / ReviewService /
 *    PlanningService / MemoryService），与未来 GatewayAIService 同接口、同 Schema。
 *  - 内置 §14.5 超时 / 重试矩阵：超时 → 重试 1 次 → 无效则本地兜底。
 *  - 所有输出经 SchemaValidator 校验；校验失败重试 1 次，仍失败走兜底。
 *  - 人格（GENTLE/STRICT/QUIET/ADAPTIVE）通过 wording pack 影响文案，绝不假装真人。
 *  - 不持有任何 API Key；Gateway 接入时仅替换本类，UI 不变。
 */
export class MockAIService implements AIService, QAService, CompanionService, ReviewService, PlanningService, MemoryService {
    private static inst: MockAIService | null = null;
    private personality: string = 'GENTLE';
    /** 仅供自测注入：让指定场景强制超时，用于验证重试/兜底链路 */
    private forceTimeoutScenes: Set<AIScene> = new Set<AIScene>();
    private static readonly TIMEOUTS: Map<AIScene, RetryConfig> = new Map<AIScene, RetryConfig>([
        ['task_plan', { timeoutMs: 20000, retries: 1 }],
        ['task_dialog', { timeoutMs: 15000, retries: 1 }],
        ['companion', { timeoutMs: 5000, retries: 0 }],
        ['qa_text', { timeoutMs: 20000, retries: 1 }],
        ['qa_image', { timeoutMs: 30000, retries: 1 }],
        ['review', { timeoutMs: 30000, retries: 1 }],
        ['planning', { timeoutMs: 60000, retries: 1 }],
        ['memory', { timeoutMs: 30000, retries: 1 }]
    ]);
    private static readonly WORDING: WordingMap = {
        GENTLE: {
            light: '感觉你有点走神啦，先喝口水缓一缓？不用急，慢慢来。',
            heavy: '你已经离开屏幕有一会儿了，要不要先休息 5 分钟，回来状态会更好。'
        },
        STRICT: {
            light: '专注度下降了，把手机放远一点，回到任务上。',
            heavy: '已经明显分心，必须停下来。现在去休息，别硬撑。'
        },
        QUIET: {
            light: '走神了。回到屏幕。',
            heavy: '离开太久。先休息。'
        },
        ADAPTIVE: {
            light: '节奏有点松，调整一下？继续就好。',
            heavy: '分心较久，建议短暂休息后再战。'
        }
    };
    /** §14.7 QA 免责声明（所有 AI 输出必须携带） */
    private static readonly DISCLAIMER = '（小伴是 AI 学伴，不是真人，回答仅供参考，重要结论请自行核实。）';
    static getInstance(): MockAIService {
        if (MockAIService.inst === null) {
            MockAIService.inst = new MockAIService();
        }
        return MockAIService.inst;
    }
    setPersonality(p: string): void {
        this.personality = p;
    }
    getPersonality(): string {
        return this.personality;
    }
    private static versionFor(scene: AIScene): string {
        switch (scene) {
            case 'qa_text':
            case 'qa_image':
                return QA_SCHEMA_VERSION;
            case 'companion':
                return COMPANION_SCHEMA_VERSION;
            case 'review':
                return REVIEW_SCHEMA_VERSION;
            case 'task_plan':
            case 'task_dialog':
            case 'planning':
                return PLANNING_SCHEMA_VERSION;
            case 'memory':
                return MEMORY_SCHEMA_VERSION;
            default:
                return 'unknown@0';
        }
    }
    private delay(ms: number): Promise<void> {
        return new Promise<void>((resolve) => {
            setTimeout(resolve, ms);
        });
    }
    private withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
        return new Promise<T>((resolve, reject) => {
            const t = setTimeout(() => reject(new Error('timeout')), ms);
            p.then((v) => {
                clearTimeout(t);
                resolve(v);
            }).catch((e: Object) => {
                clearTimeout(t);
                reject(e);
            });
        });
    }
    private ok<T>(scene: AIScene, requestId: string, data: T): AIResponse<T> {
        return {
            requestId,
            ok: true,
            schemaVersion: MockAIService.versionFor(scene),
            data,
            usage: { promptTokens: 0, completionTokens: 0, latencyMs: 0 }
        };
    }
    private fallback<T>(scene: AIScene, requestId: string, data: T): AIResponse<T> {
        return {
            requestId,
            ok: true,
            schemaVersion: MockAIService.versionFor(scene),
            data,
            fallback: true,
            usage: { promptTokens: 0, completionTokens: 0, latencyMs: 0 }
        };
    }
    /** 本地兜底数据（同 Schema，与真实接口结构一致，替换时 UI 不变） */
    private defaultQA(sceneName: 'qa_text' | 'qa_image'): QAResp {
        return {
            answer: '这个问题我先记下了，稍后我们一起回顾。',
            references: [],
            disclaimer: MockAIService.DISCLAIMER,
            scene: sceneName
        };
    }
    private defaultCompanion(): CompanionDecision {
        return {
            shouldIntervene: false,
            level: 'NONE',
            channel: 'quiet',
            message: '',
            action: 'continue'
        };
    }
    private defaultReview(): ReviewData {
        return {
            insight: '本次学习已完成，继续加油。',
            suggestions: ['每 45 分钟左右主动休息一次，起来活动一下']
        };
    }
    private defaultPlan(): PlanningResult {
        return { tasks: [], summary: '我先帮你记着，稍后一起规划。' };
    }
    private defaultDialog(): PlanningDialogResult {
        return { reply: '我先帮你记着，稍后一起规划。', done: false };
    }
    private defaultMemory(): MemoryDelta {
        return { shouldUpdate: false, fields: {}, note: '' };
    }
    /** 统一执行：produce → SchemaValidator → 重试 1 → 兜底 */
    private async runWithRetry<T>(scene: AIScene, requestId: string, produce: () => Promise<T>, fallbackData: T): Promise<AIResponse<T>> {
        const cfgOpt = MockAIService.TIMEOUTS.get(scene);
        const cfg: RetryConfig = cfgOpt !== undefined ? cfgOpt : { timeoutMs: 20000, retries: 1 };
        const tryOnce = async (): Promise<T | null> => {
            try {
                const forced = this.forceTimeoutScenes.has(scene);
                const promise: Promise<T> = forced
                    ? (async (): Promise<T> => {
                        await this.delay(cfg.timeoutMs + 10);
                        return produce();
                    })()
                    : produce();
                const data = await this.withTimeout(promise, cfg.timeoutMs);
                const v = SchemaValidator.for(scene).validate(data as Object);
                if (v.ok) {
                    return data;
                }
                return null;
            }
            catch (e) {
                return null;
            }
        };
        const first = await tryOnce();
        if (first !== null) {
            return this.ok<T>(scene, requestId, first);
        }
        if (cfg.retries > 0) {
            const second = await tryOnce();
            if (second !== null) {
                return this.ok<T>(scene, requestId, second);
            }
        }
        return this.fallback<T>(scene, requestId, fallbackData);
    }
    // ===================== 5 个服务的生产逻辑 =====================
    private async producePlan(input: PlanningInput): Promise<PlanningResult> {
        await this.delay(550);
        const goal = input.goal;
        const tasks: PlanTask[] = [];
        const add = (title: string, subject: string, min: number, order: number): void => {
            tasks.push(PlanTask.create(title, subject, min, order));
        };
        if (goal.indexOf('高数') >= 0 || goal.indexOf('数学') >= 0 || goal.indexOf('极限') >= 0 || goal.indexOf('导数') >= 0) {
            add('复习极限章节', '高等数学', 30, 0);
            add('完成极限练习题 10 道', '高等数学', 30, 1);
            add('复习导数章节', '高等数学', 30, 2);
            add('完成导数练习题 10 道', '高等数学', 30, 3);
        }
        else if (goal.indexOf('英语') >= 0 || goal.indexOf('单词') >= 0) {
            add('背诵 50 个核心单词', '英语', 25, 0);
            add('精读 1 篇阅读理解', '英语', 35, 1);
            add('整理今日生词与长难句', '英语', 20, 2);
        }
        else if (goal.indexOf('政治') >= 0) {
            add('梳理马原第一章框架', '政治', 40, 0);
            add('完成 20 道选择题', '政治', 30, 1);
            add('错题复盘', '政治', 20, 2);
        }
        else {
            add(`复习「${goal}」核心概念`, '综合', 40, 0);
            add(`「${goal}」专项练习`, '综合', 40, 1);
            add('错题与笔记整理', '综合', 20, 2);
        }
        const summary = `已为你拆出 ${tasks.length} 个任务，预计总时长约 ${tasks.reduce((a, t) => a + t.estimatedDuration, 0)} 分钟。`;
        return { tasks, summary };
    }
    private async produceDialog(input: PlanningDialogInput): Promise<PlanningDialogResult> {
        await this.delay(420);
        if (input.step === 0) {
            return { reply: '好的，大概有多少时间可以学习呢？', done: false };
        }
        if (input.step === 1) {
            return { reply: '有没有特别想优先完成的部分？', done: false };
        }
        return {
            reply: '好的，我帮你安排一下。',
            done: true,
            tasks: [
                PlanTask.create('优先任务块 A', '综合', 30, 0),
                PlanTask.create('巩固练习 B', '综合', 30, 1),
                PlanTask.create('整理复盘 C', '综合', 20, 2)
            ]
        };
    }
    private async produceInsight(input: PlanningInput): Promise<PlanningResult> {
        await this.delay(500);
        const pref = input.preferredSubject !== undefined ? input.preferredSubject : '上午';
        return {
            tasks: [],
            summary: `你通常在 ${pref} 状态最好，建议把难点安排在精力高峰。`
        };
    }
    private async produceDecision(ctx: CompanionContext): Promise<CompanionDecision> {
        await this.delay(120);
        return this.buildDecisionSync(ctx);
    }
    /** 同步决策核心（供 InterventionEngine 在计时循环中同步调用） */
    buildDecisionSync(ctx: CompanionContext): CompanionDecision {
        const distracted = ctx.state === 'SLIGHTLY_DISTRACTED' || ctx.state === 'DISTRACTED';
        if (!distracted) {
            return { shouldIntervene: false, level: 'NONE', channel: 'quiet', message: '', action: 'continue' };
        }
        const sinceSec = ctx.sinceMs / 1000;
        let level: 'LIGHT' | 'HEAVY' = 'LIGHT';
        if (ctx.state === 'DISTRACTED' && sinceSec >= 60) {
            level = 'HEAVY';
        }
        // §12 硬规则：无手表时 RED 用手机声音 + 屏幕选择，绝不假装震动
        const channel = level === 'HEAVY' && ctx.hasWatch ? 'watch-vibrate' : level === 'HEAVY' ? 'phone-sound' : 'screen-select';
        const message = this.wording(ctx.personality, level);
        const action = level === 'HEAVY' ? 'rest' : 'continue';
        return { shouldIntervene: true, level, channel, message, action };
    }
    /** 同步决策入口（InterventionEngine 调用，不触发网络/延迟） */
    decideSync(ctx: CompanionContext): CompanionDecision {
        return this.buildDecisionSync(ctx);
    }
    private async produceQAText(payload: QATextPayload): Promise<QAResp> {
        await this.delay(620);
        const q = payload.question;
        return {
            answer: this.knowledgeAnswer(q),
            references: [],
            disclaimer: MockAIService.DISCLAIMER,
            scene: 'qa_text'
        };
    }
    private async produceQAImage(payload: QAImagePayload): Promise<QAResp> {
        await this.delay(720);
        const q = payload.question !== undefined ? payload.question : payload.imageRef;
        return {
            answer: this.knowledgeAnswer(q),
            references: [],
            disclaimer: MockAIService.DISCLAIMER,
            scene: 'qa_image'
        };
    }
    private async produceReview(payload: ReviewPayload): Promise<ReviewData> {
        await this.delay(420);
        const s = payload.session;
        const focusPct = Metrics.focusRatePercent(s);
        const completion = Metrics.completionRate(s);
        const studyMin = Math.round(Metrics.totalStudySec(s) / 60);
        let insight = `本次一共学习了 ${studyMin} 分钟，净专注率 ${focusPct}%。`;
        let fatigueMin = 0;
        for (const p of s.timeline) {
            if (p.state === 'DISTRACTED' || p.level < 45) {
                fatigueMin = p.minute;
                break;
            }
        }
        if (fatigueMin > 0) {
            insight += ` 大约第 ${fatigueMin} 分钟出现疲劳信号，下次可提前到 ${Math.max(25, fatigueMin - 5)} 分钟左右安排休息。`;
        }
        const suggestions: string[] = ['每 45 分钟左右主动休息一次，起来喝口水、活动一下'];
        if (completion < 90) {
            suggestions.push('下次把任务切得更小一些，完成感会更足');
        }
        if (Metrics.distractionRate(s) > 0.2) {
            suggestions.push('把手机放到视线之外，减少被动打断');
        }
        suggestions.push('练习题分两批完成，中间留出缓冲');
        return { insight, suggestions };
    }
    private async produceMemory(payload: MemoryPayload): Promise<MemoryDelta> {
        await this.delay(200);
        const finished = payload.recentSessions.filter((s) => Metrics.totalStudySec(s) > 0);
        const count = finished.length;
        if (!Metrics.canShowProfile(count)) {
            // 样本不足：不更新五维，UI 显示"还在了解你"
            return { shouldUpdate: false, fields: {}, note: '样本不足，暂不更新画像' };
        }
        const d = Metrics.fiveDim(finished);
        const fields: ProfileFields = {
            efficiency: d.efficiency,
            concentration: d.concentration,
            stability: d.stability,
            execution: d.execution,
            antiDistraction: d.antiDistraction,
            averageFocusDuration: Math.round(finished.reduce((a, s) => a + s.focusDuration, 0) / finished.length / 60),
            focusThreshold: Metrics.focusThreshold(finished),
            bestFocusTime: Metrics.goldenWindow(finished),
            sampleCount: count
        };
        return { shouldUpdate: true, fields, note: '画像已根据最近会话更新' };
    }
    // ===================== 文案包（按人格 × 场景）=====================
    private wording(personality: string, level: 'LIGHT' | 'HEAVY'): string {
        const w = MockAIService.wordingFor(personality);
        if (level === 'HEAVY') {
            return w.heavy;
        }
        return w.light;
    }
    private static wordingFor(p: string): WordingLevel {
        switch (p) {
            case 'STRICT':
                return MockAIService.WORDING.STRICT;
            case 'QUIET':
                return MockAIService.WORDING.QUIET;
            case 'ADAPTIVE':
                return MockAIService.WORDING.ADAPTIVE;
            default:
                return MockAIService.WORDING.GENTLE;
        }
    }
    private knowledgeAnswer(q: string): string {
        if (q.indexOf('洛必达') >= 0) {
            return '洛必达法则适用于 0/0 或 ∞/∞ 型未定式：当分子分母都趋于 0（或都趋于无穷）时，可对分子、分母分别求导再取极限。使用前要确认满足可导与未定式条件，且求导后极限存在。';
        }
        if (q.indexOf('导数') >= 0 || q.indexOf('链式') >= 0) {
            return '链式法则是复合函数求导的核心：若 y = f(g(x))，则 y\' = f\'(g(x)) · g\'(x)。由外向内一层层求导再相乘。';
        }
        if (q.indexOf('极限') >= 0) {
            return '求极限先判断类型：能直接代入就先代入；出现 0/0 型，优先考虑等价无穷小替换、因式分解或洛必达法则。';
        }
        if (q.indexOf('状态不好') >= 0 || q.indexOf('累') >= 0 || q.indexOf('焦虑') >= 0) {
            return '状态有起伏很正常，不用逼自己。我们先从最小的一步开始：把今天要做的第一件事缩小到 15 分钟就能完成的量，好吗？';
        }
        if (q.indexOf('分心') >= 0 || q.indexOf('走神') >= 0) {
            return '容易分心通常不是意志力的问题，而是任务和节奏没匹配。我建议把任务切成更小的块，每 25-45 分钟安排一次短暂休息。';
        }
        return '这个问题我记下了。按我目前的模拟知识库，先给你一个方向：把它拆成「定义 → 适用条件 → 典型例题」三步逐步击破。回到专注后，我会把它写进本次复盘。';
    }
    // ===================== 5 服务接口实现（canonical）=====================
    async plan(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
        return this.runWithRetry<PlanningResult>('task_plan', req.requestId, () => this.producePlan(req.payload), this.defaultPlan());
    }
    async dialog(req: AIRequest<PlanningDialogInput>): Promise<AIResponse<PlanningDialogResult>> {
        return this.runWithRetry<PlanningDialogResult>('task_dialog', req.requestId, () => this.produceDialog(req.payload), this.defaultDialog());
    }
    async weeklyInsight(req: AIRequest<PlanningInput>): Promise<AIResponse<PlanningResult>> {
        return this.runWithRetry<PlanningResult>('planning', req.requestId, () => this.produceInsight(req.payload), this.defaultPlan());
    }
    async decide(req: AIRequest<CompanionContext>): Promise<AIResponse<CompanionDecision>> {
        return this.runWithRetry<CompanionDecision>('companion', req.requestId, () => this.produceDecision(req.payload), this.defaultCompanion());
    }
    async askText(req: AIRequest<QATextPayload>): Promise<AIResponse<QAResp>> {
        return this.runWithRetry<QAResp>('qa_text', req.requestId, () => this.produceQAText(req.payload), this.defaultQA('qa_text'));
    }
    async askImage(req: AIRequest<QAImagePayload>): Promise<AIResponse<QAResp>> {
        return this.runWithRetry<QAResp>('qa_image', req.requestId, () => this.produceQAImage(req.payload), this.defaultQA('qa_image'));
    }
    async generate(req: AIRequest<ReviewPayload>): Promise<AIResponse<ReviewData>> {
        return this.runWithRetry<ReviewData>('review', req.requestId, () => this.produceReview(req.payload), this.defaultReview());
    }
    async update(req: AIRequest<MemoryPayload>): Promise<AIResponse<MemoryDelta>> {
        return this.runWithRetry<MemoryDelta>('memory', req.requestId, () => this.produceMemory(req.payload), this.defaultMemory());
    }
    // ===================== 兼容垫片便捷方法（供现有 AppStore/UI 调用）=====================
    private toTask(p: PlanTask): Task {
        const t = new Task();
        t.id = p.id.length > 0 ? p.id : IdUtils.uuid();
        t.title = p.title;
        t.subject = p.subject;
        t.estimatedDuration = p.estimatedDuration;
        t.status = p.status;
        t.done = p.done;
        t.sortOrder = p.sortOrder;
        t.createdAt = Date.now();
        return t;
    }
    /** 旧 AIService.planTasks 等价实现 */
    async planTasks(input: string): Promise<Task[]> {
        const r = await this.plan({
            requestId: IdUtils.uuid(),
            scene: 'task_plan',
            userId: 'local',
            payload: { goal: input }
        });
        const tasks = (r.data?.tasks ?? []).map((p) => this.toTask(p));
        return tasks;
    }
    async chat(input: string): Promise<string> {
        return this.knowledgeAnswer(input);
    }
    async answerQuestion(q: string): Promise<string> {
        return this.knowledgeAnswer(q);
    }
    async reviewInsight(session: FocusSession, report?: StudyReport): Promise<string> {
        const r = await this.generate({
            requestId: IdUtils.uuid(),
            scene: 'review',
            userId: 'local',
            payload: { session, questions: [] }
        });
        return r.data?.insight ?? '本次学习已完成，继续加油。';
    }
    reviewSuggestions(session: FocusSession, report?: StudyReport): string[] {
        const r = Metrics.focusRatePercent(session);
        const suggestions: string[] = ['每 45 分钟左右主动休息一次，起来活动一下'];
        if (r < 90) {
            suggestions.push('下次把任务切得更小一些，完成感会更足');
        }
        if (Metrics.distractionRate(session) > 0.2) {
            suggestions.push('把手机放到视线之外，减少被动打断');
        }
        return suggestions;
    }
    /** 长期画像更新：统一走 Metrics（§3 指标唯一事实源） */
    updateProfile(profile: FocusProfile, sessions: FocusSession[]): FocusProfile {
        const finished = sessions.filter((s) => Metrics.totalStudySec(s) > 0);
        profile.sampleCount = finished.length;
        profile.recentConcentrations = finished.map((s) => Metrics.focusRatePercent(s));
        profile.recentDistractionRates = finished.map((s) => Metrics.distractionRate(s));
        if (Metrics.canShowProfile(profile.sampleCount)) {
            const d = Metrics.fiveDim(finished);
            profile.efficiency = d.efficiency;
            profile.concentration = d.concentration;
            profile.stability = d.stability;
            profile.execution = d.execution;
            profile.antiDistraction = d.antiDistraction;
            profile.averageFocusDuration = Math.round(finished.reduce((a, s) => a + s.focusDuration, 0) / finished.length / 60);
            profile.focusThreshold = Metrics.focusThreshold(finished);
            profile.bestFocusTime = Metrics.goldenWindow(finished);
        }
        else {
            profile.efficiency = 0;
            profile.concentration = 0;
            profile.stability = 0;
            profile.execution = 0;
            profile.antiDistraction = 0;
        }
        profile.updatedAt = Date.now();
        return profile;
    }
    companionIntro(): string {
        return '你好，我是你的 AI 学伴小伴，不是真人，但会一直陪你。';
    }
    openPlanning(): string {
        return '今天想学点什么？先告诉我一个大概的目标，我帮你拆成几个具体的小任务。';
    }
    nextPlanningQuestion(step: number): string {
        if (step === 0) {
            return '好的，大概有多少时间可以学习呢？';
        }
        if (step === 1) {
            return '有没有特别想优先完成的部分？';
        }
        return '好的，我帮你安排一下。';
    }
    proactive(goldenTime: string): string {
        return `你通常在 ${goldenTime} 专注效率最高。要不要现在开始一个 45 分钟的专注？`;
    }
    longTermAnalysis(profile: FocusProfile, hardestSubject: string): string {
        return `最近，你的专注效率在稳步提升。相比阅读类任务，你在${hardestSubject}中更容易出现注意力下降。建议将${hardestSubject}安排在精力最好的时段，并配合 45 分钟左右的专注节奏。`;
    }
}
