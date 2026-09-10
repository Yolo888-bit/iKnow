import type { QuestionRecord } from './QuestionRecord';
/** 单次学习复盘 */
@Observed
export class StudyReport {
    sessionId: string = '';
    completionRate: number = 0; // 完成率 0-100
    focusRate: number = 0; // 净专注率 0-100
    bestFocusPeriod: string = ''; // 最佳专注时段描述
    fatiguePoint: number = 0; // 疲劳信号出现的分钟数
    distractionTriggers: string[] = [];
    suggestions: string[] = [];
    insights: string = ''; // AI 洞察文案
    questions: QuestionRecord[] = [];
    createdAt: number = 0;
}
