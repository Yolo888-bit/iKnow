import type { Task } from '../models/Task';
import type { FocusSession } from '../models/FocusSession';
import type { StudyReport } from '../models/StudyReport';
import type { FocusProfile } from '../models/FocusProfile';
import type { AIPersonality } from '../models/Enums';
import { MockAIService } from "@normalized:N&&&entry/src/main/ets/services/ai/MockAIService&";
import { GatewayAIService } from "@normalized:N&&&entry/src/main/ets/services/ai/GatewayAIService&";
import { BridgeConfig } from "@normalized:N&&&entry/src/main/ets/services/ai/BridgeConfig&";
import type { AIPayload, AIResult, AIRequest, AIResponse, AIScene } from './ai/AIService';
import type { PlanningInput, PlanningResult, PlanningDialogInput, PlanningDialogResult } from './ai/PlanningService';
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
/**
 * AI 服务兼容垫片（PRD §13 / 硬规则 §1）
 *
 * 历史 UI / AppStore 通过 AIService.getInstance() 调用 AI 能力。本类作为薄委派层，
 * 全部逻辑下沉到 services/ai/MockAIService（实现 5 个独立接口：QA / Companion /
 * Review / Planning / Memory）。未来接入真实网关时，仅需把内部实例换成
 * GatewayAIService，UI 与调用方零改动。
 *
 * 人格：有温度、有陪伴感，但不假装真人；不指责、不说教、不制造焦虑。
 */
export class AIService {
    private static inst: AIService | null = null;
    private mock: MockAIService = MockAIService.getInstance();
    private gateway: GatewayAIService = GatewayAIService.getInstance();
    /** 是否启用真实网关；默认 false 走 Mock（硬规则 §8：替换时不改 UI） */
    private useGateway: boolean = false;
    static getInstance(): AIService {
        if (AIService.inst === null) {
            AIService.inst = new AIService();
        }
        return AIService.inst;
    }
    private constructor() {
        this.mock = MockAIService.getInstance();
        this.gateway = GatewayAIService.getInstance();
        // 按 BridgeConfig 决定是否启用真实大模型（默认开启；若未配置 Key 会自动回退 Mock）
        this.setGatewayEnabled(BridgeConfig.useGateway);
    }
    setPersonality(p: AIPersonality): void {
        this.mock.setPersonality(p);
        this.gateway.setPersonality(p);
    }
    /**
     * 切换真实网关（默认 false，强制 Mock）。
     * 开启后 dispatch 会先尝试网关，失败/未配置时自动回退 Mock，核心功能不中断。
     */
    setGatewayEnabled(on: boolean): void {
        this.gateway.enabled = on;
        this.useGateway = on;
    }
    /**
     * 场景路由（PRD §14.1 / §14.2）：依据 req.scene 分发到对应 Agent。
     * 开启网关时先试 Gateway，失败回退 Mock（AI 失败不影响核心计时/感知，硬规则 §4 / §14.5）。
     */
    async dispatch(req: AIRequest<AIPayload>): Promise<AIResponse<AIResult>> {
        if (this.useGateway) {
            const r: AIResponse<AIResult> = await this.gateway.dispatch(req);
            if (r.ok) {
                return r;
            }
            // 网关未配置/失败：回退 Mock，保证核心功能不中断
            return await this.mock.dispatch(req);
        }
        return await this.mock.dispatch(req);
    }
    /**
     * 便捷入口：仅传 scene + payload 即可按场景调用对应 AI。
     * 自动补全 requestId / userId，并复用 dispatch 的网关回退逻辑。
     *
     * 示例：
     *   const r = await AIService.getInstance().callScene('qa_text', { question: '洛必达怎么用？' })
     *   if (r.ok) { const ans = (r.data as QAResp).answer }
     */
    async callScene(scene: AIScene, payload: AIPayload, userId: string = 'local'): Promise<AIResponse<AIResult>> {
        const req: AIRequest<AIPayload> = {
            requestId: IdUtils.uuid(),
            scene: scene,
            userId: userId,
            payload: payload
        };
        return await this.dispatch(req);
    }
    getPersonality(): AIPersonality {
        return this.mock.getPersonality() as AIPersonality;
    }
    /** 考伴固定开场（身份透明必须保留） */
    companionIntro(): string {
        return this.mock.companionIntro();
    }
    /** 对话式规划开场白 */
    openPlanning(): string {
        return this.mock.openPlanning();
    }
    /** 规划页开场白（按时长/目标生成，页面不硬编码） */
    planningIntro(): string {
        return this.mock.planningIntro();
    }
    /** 规划对话没有拿到有效回复时的承接语（AI 文案，硬规则 §1） */
    planningHold(): string {
        return this.mock.planningHold();
    }
    /** 规划完成后的时间安排分析（AI 输出，硬规则 §1） */
    analyzePlan(tasks: Task[]): string {
        return this.mock.analyzePlan(tasks);
    }
    /** 单日复盘 AI 洞察（AI 输出，硬规则 §1） */
    dayInsight(dayLabel: string, focusRate: number, bestPeriod: string, hasData: boolean): string {
        return this.mock.dayInsight(dayLabel, focusRate, bestPeriod, hasData);
    }
    /** 单日复盘优化建议（AI 输出，硬规则 §1） */
    daySuggestions(studyMinutes: number, focusRate: number): string[] {
        return this.mock.daySuggestions(studyMinutes, focusRate);
    }
    /**
     * 规划场景（task_plan）强类型封装：按目标生成结构化任务。
     * 内部走 dispatch 场景路由，此处收敛联合类型，调用方无需做类型断言。
     */
    async planByScene(input: PlanningInput): Promise<PlanningResult> {
        const r = await this.callScene('task_plan', input);
        const d: AIResult | undefined = r.data;
        if (r.ok && d !== undefined) {
            return d as Object as PlanningResult;
        }
        return { tasks: [], summary: '' };
    }
    /** 对话式规划追问（task_dialog）强类型封装 */
    async dialogByScene(input: PlanningDialogInput): Promise<PlanningDialogResult> {
        const r = await this.callScene('task_dialog', input);
        const d: AIResult | undefined = r.data;
        if (r.ok && d !== undefined) {
            return d as Object as PlanningDialogResult;
        }
        return { reply: '', done: false };
    }
    /** 对话式规划的追问 */
    nextPlanningQuestion(step: number): string {
        return this.mock.nextPlanningQuestion(step);
    }
    /** 根据目标文本生成结构化任务（委托 MockAIService） */
    async planTasks(input: string): Promise<Task[]> {
        return await this.mock.planTasks(input);
    }
    /** 通用考伴对话 */
    async chat(input: string): Promise<string> {
        return await this.mock.chat(input);
    }
    /** 答疑（委托 MockAIService，输出带免责声明） */
    async answerQuestion(q: string): Promise<string> {
        return await this.mock.answerQuestion(q);
    }
    /** 复盘洞察文案（委托 MockAIService，指标统一走 Metrics） */
    async reviewInsight(session: FocusSession, report: StudyReport): Promise<string> {
        return await this.mock.reviewInsight(session, report);
    }
    /** 复盘优化建议（指标统一走 Metrics） */
    reviewSuggestions(session: FocusSession, report: StudyReport): string[] {
        return this.mock.reviewSuggestions(session, report);
    }
    /** 长期画像更新（委托 MockAIService，统一走 Metrics §3/§6） */
    updateProfile(profile: FocusProfile, sessions: FocusSession[]): FocusProfile {
        return this.mock.updateProfile(profile, sessions);
    }
    /** 首页主动建议文案 */
    proactive(goldenTime: string): string {
        return this.mock.proactive(goldenTime);
    }
    /** 长期分析文案 */
    longTermAnalysis(profile: FocusProfile, hardestSubject: string): string {
        return this.mock.longTermAnalysis(profile, hardestSubject);
    }
}
