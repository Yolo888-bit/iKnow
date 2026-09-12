import type { AIScene } from './AIService';
import { QA_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/QAService&";
import { COMPANION_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/CompanionService&";
import { REVIEW_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/ReviewService&";
import { PLANNING_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/PlanningService&";
import { MEMORY_SCHEMA_VERSION } from "@normalized:N&&&entry/src/main/ets/services/ai/MemoryService&";
/**
 * AI 输出 Schema 校验（PRD §14.5 失败链：Provider → Validator → Invalid → 重试 → 兜底）
 *
 * 所有 AI 输出（Mock 或 Real）必须经此处校验：
 *  - 字段齐全、类型正确
 *  - 关键合规字段存在（如 QA 的 disclaimer）
 * 校验失败返回 errors，由 Provider 决定是否重试 / 兜底。
 *
 * ArkTS 合规：不使用 unknown / any / 类型谓词，统一用 Object + as 显式接口校验。
 * 校验器以显式 class（SceneValidator）承载，避免对象字面量 + 结构化类型受限问题。
 */
export interface ValidationResult {
    ok: boolean;
    data: Object;
    errors: string[];
}
/** 显式 class：对象字面量无法直接赋值给接口（受限的结构化类型），故用 class 实例承载 */
export class SceneValidator {
    scene: AIScene;
    version: string;
    validate: (p: Object) => ValidationResult;
    constructor(scene: AIScene, version: string, validate: (p: Object) => ValidationResult) {
        this.scene = scene;
        this.version = version;
        this.validate = validate;
    }
}
interface QAPayload {
    answer: string;
    disclaimer: string;
}
interface CompanionPayload {
    shouldIntervene: boolean;
    level: string;
    channel: string;
    message: string;
    action: string;
}
interface ReviewPayloadV {
    insight: string;
    suggestions: string[];
}
interface PlanPayload {
    tasks: Object[];
    summary: string;
}
interface DialogPayload {
    reply: string;
    done: boolean;
}
interface MemoryPayloadV {
    shouldUpdate: boolean;
    fields: Object;
}
export class SchemaValidator {
    /** 按场景取最新校验器 */
    static for(scene: AIScene): SceneValidator {
        switch (scene) {
            case 'qa_text':
            case 'qa_image':
                return SchemaValidator.qaValidator();
            case 'companion':
                return SchemaValidator.companionValidator();
            case 'review':
                return SchemaValidator.reviewValidator();
            case 'task_dialog':
                return SchemaValidator.dialogValidator();
            case 'task_plan':
            case 'planning':
                return SchemaValidator.planValidator();
            case 'memory':
                return SchemaValidator.memoryValidator();
            default:
                throw new Error(`未注册场景校验器: ${scene}`);
        }
    }
    private static qaValidator(): SceneValidator {
        return new SceneValidator('qa_text', QA_SCHEMA_VERSION, (p: Object): ValidationResult => {
            const o = p as QAPayload;
            const errors: string[] = [];
            if (typeof o.answer !== 'string' || o.answer.length === 0) {
                errors.push('字段 answer 缺失或非字符串');
            }
            if (typeof o.disclaimer !== 'string' || o.disclaimer.length === 0) {
                errors.push('字段 disclaimer 缺失或非字符串');
            }
            return { ok: errors.length === 0, data: p, errors: errors };
        });
    }
    private static companionValidator(): SceneValidator {
        return new SceneValidator('companion', COMPANION_SCHEMA_VERSION, (p: Object): ValidationResult => {
            const o = p as CompanionPayload;
            const errors: string[] = [];
            if (typeof o.shouldIntervene !== 'boolean') {
                errors.push('字段 shouldIntervene 缺失或非布尔');
            }
            if (o.level !== 'NONE' && o.level !== 'LIGHT' && o.level !== 'HEAVY') {
                errors.push('字段 level 非法');
            }
            if (typeof o.channel !== 'string') {
                errors.push('字段 channel 缺失或非字符串');
            }
            if (typeof o.message !== 'string') {
                errors.push('字段 message 缺失或非字符串');
            }
            if (typeof o.action !== 'string') {
                errors.push('字段 action 缺失或非字符串');
            }
            return { ok: errors.length === 0, data: p, errors: errors };
        });
    }
    private static reviewValidator(): SceneValidator {
        return new SceneValidator('review', REVIEW_SCHEMA_VERSION, (p: Object): ValidationResult => {
            const o = p as ReviewPayloadV;
            const errors: string[] = [];
            if (typeof o.insight !== 'string') {
                errors.push('字段 insight 缺失或非字符串');
            }
            if (!Array.isArray(o.suggestions)) {
                errors.push('字段 suggestions 缺失或非数组');
            }
            return { ok: errors.length === 0, data: p, errors: errors };
        });
    }
    /**
     * 对话式规划（task_dialog）—— 结构是 { reply, done, tasks? }，与 task_plan 不同。
     * 历史上这里误用了 planValidator（要求 tasks + summary），导致 {reply,done} 永远校验失败，
     * dialog 一直落到兜底文案。此处拆出独立校验器修正。
     */
    private static dialogValidator(): SceneValidator {
        return new SceneValidator('task_dialog', PLANNING_SCHEMA_VERSION, (p: Object): ValidationResult => {
            const o = p as DialogPayload;
            const errors: string[] = [];
            if (typeof o.reply !== 'string' || o.reply.length === 0) {
                errors.push('字段 reply 缺失或非字符串');
            }
            if (typeof o.done !== 'boolean') {
                errors.push('字段 done 缺失或非布尔');
            }
            return { ok: errors.length === 0, data: p, errors: errors };
        });
    }
    private static planValidator(): SceneValidator {
        return new SceneValidator('task_plan', PLANNING_SCHEMA_VERSION, (p: Object): ValidationResult => {
            const o = p as PlanPayload;
            const errors: string[] = [];
            if (!Array.isArray(o.tasks)) {
                errors.push('字段 tasks 缺失或非数组');
            }
            if (typeof o.summary !== 'string') {
                errors.push('字段 summary 缺失或非字符串');
            }
            return { ok: errors.length === 0, data: p, errors: errors };
        });
    }
    private static memoryValidator(): SceneValidator {
        return new SceneValidator('memory', MEMORY_SCHEMA_VERSION, (p: Object): ValidationResult => {
            const o = p as MemoryPayloadV;
            const errors: string[] = [];
            if (typeof o.shouldUpdate !== 'boolean') {
                errors.push('字段 shouldUpdate 缺失或非布尔');
            }
            if (typeof o.fields !== 'object') {
                errors.push('字段 fields 缺失或非对象');
            }
            return { ok: errors.length === 0, data: p, errors: errors };
        });
    }
}
