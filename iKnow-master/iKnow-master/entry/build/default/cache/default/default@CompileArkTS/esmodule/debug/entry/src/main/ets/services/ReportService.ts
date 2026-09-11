import type { FocusSession } from '../models/FocusSession';
import type { QuestionRecord } from '../models/QuestionRecord';
import { StudyReport } from "@normalized:N&&&entry/src/main/ets/models/StudyReport&";
import { Metrics } from "@normalized:N&&&entry/src/main/ets/services/Metrics&";
import { MockAIService } from "@normalized:N&&&entry/src/main/ets/services/ai/MockAIService&";
import { IdUtils } from "@normalized:N&&&entry/src/main/ets/utils/IdUtils&";
/**
 * 复盘服务 —— 根据会话数据生成单次学习复盘（PRD §13 / §14）
 *
 * 指标口径严格走 Metrics（硬规则 §3）；AI 文案经 ReviewService（MockAIService.generate）
 * 返回，并经过 SchemaValidator 校验（硬规则 §9）。AI 失败不影响核心指标计算。
 */
export class ReportService {
    private static inst: ReportService | null = null;
    static getInstance(): ReportService {
        if (ReportService.inst === null) {
            ReportService.inst = new ReportService();
        }
        return ReportService.inst;
    }
    async buildReport(session: FocusSession, questions: QuestionRecord[]): Promise<StudyReport> {
        const r = new StudyReport();
        r.sessionId = session.id;
        r.createdAt = Date.now();
        // 指标全部来自 Metrics（§5 唯一事实源）
        r.completionRate = Metrics.completionRate(session);
        r.focusRate = Metrics.focusRatePercent(session);
        r.bestFocusPeriod = Metrics.bestFocusPeriod(session);
        r.fatiguePoint = Metrics.fatigueMinute(session);
        r.distractionTriggers = Metrics.distractionTriggers(session);
        r.questions = questions;
        // AI 文案经 ReviewService 返回（Schema 校验 + 失败兜底）
        try {
            const resp = await MockAIService.getInstance().generate({
                requestId: IdUtils.uuid(),
                scene: 'review',
                userId: 'local',
                payload: { session, questions }
            });
            if (resp.ok && resp.data !== undefined) {
                r.insights = resp.data.insight;
                r.suggestions = resp.data.suggestions;
            }
            else {
                r.insights = '本次学习已完成，继续加油。';
                r.suggestions = ['每 45 分钟左右主动休息一次，起来活动一下'];
            }
        }
        catch (e) {
            r.insights = '本次学习已完成，继续加油。';
            r.suggestions = ['每 45 分钟左右主动休息一次，起来活动一下'];
        }
        return r;
    }
}
