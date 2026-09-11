import type { AIRequest, AIResponse } from './AIService';
import type { FocusProfile } from '../../models/FocusProfile';
import type { FocusSession } from '../../models/FocusSession';
/**
 * 记忆/画像更新服务契约（PRD §13，场景 memory）
 * 根据历史会话判断是否需要更新长期画像字段。
 */
export interface ProfileFields {
    efficiency?: number;
    concentration?: number;
    stability?: number;
    execution?: number;
    antiDistraction?: number;
    averageFocusDuration?: number;
    focusThreshold?: number;
    bestFocusTime?: string;
    sampleCount?: number;
}
export interface MemoryPayload {
    profile: FocusProfile;
    recentSessions: FocusSession[];
}
export interface MemoryDelta {
    shouldUpdate: boolean;
    fields: ProfileFields;
    note: string;
}
export interface MemoryService {
    update(req: AIRequest<MemoryPayload>): Promise<AIResponse<MemoryDelta>>;
}
export const MEMORY_SCHEMA_VERSION = 'memory@2026-09-11';
