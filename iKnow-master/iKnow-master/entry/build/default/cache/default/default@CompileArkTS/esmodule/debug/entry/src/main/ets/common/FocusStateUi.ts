import { Colors } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
/**
 * 专注状态 → UI 文案 / 颜色 映射（绿 / 黄 / 红）
 * state 使用 FocusState 枚举的字符串值
 */
export class FocusStateUi {
    static isDistracted(state: string): boolean {
        return state === 'SLIGHTLY_DISTRACTED' || state === 'DISTRACTED';
    }
    static color(state: string): string {
        if (state === 'SLIGHTLY_DISTRACTED') {
            return Colors.YELLOW;
        }
        if (state === 'DISTRACTED') {
            return Colors.RED;
        }
        return Colors.GREEN;
    }
    static softColor(state: string): string {
        if (state === 'SLIGHTLY_DISTRACTED') {
            return Colors.YELLOW_SOFT;
        }
        if (state === 'DISTRACTED') {
            return Colors.RED_SOFT;
        }
        return Colors.GREEN_SOFT;
    }
    static dot(state: string): string {
        if (state === 'SLIGHTLY_DISTRACTED') {
            return '🟡';
        }
        if (state === 'DISTRACTED') {
            return '🔴';
        }
        return '🟢';
    }
    static label(state: string): string {
        if (state === 'SLIGHTLY_DISTRACTED') {
            return '注意力似乎飘走了～';
        }
        if (state === 'DISTRACTED') {
            return '需要休息一下，还是继续？';
        }
        return '状态良好';
    }
    static subLabel(state: string): string {
        if (state === 'SLIGHTLY_DISTRACTED') {
            return '轻轻拉回一下就好';
        }
        if (state === 'DISTRACTED') {
            return '给你留出选择的空间';
        }
        return '继续保持现在的节奏';
    }
}
