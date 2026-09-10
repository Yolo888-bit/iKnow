/**
 * AppStorage 键名 & 产品常量
 * 跨页面响应式状态统一通过这些键写入 / 读取
 */
export class StorageKey {
    static readonly USER_NICKNAME = 'ik_user_nickname';
    static readonly USER_AVATAR = 'ik_user_avatar';
    static readonly USER_PERSONALITY = 'ik_user_personality';
    // 首页 / 工作台聚合
    static readonly TODAY_FOCUS_SEC = 'ik_today_focus_sec';
    static readonly TODAY_NET_FOCUS_SEC = 'ik_today_net_focus_sec';
    static readonly TODAY_DONE_TASKS = 'ik_today_done_tasks';
    static readonly TODAY_TOTAL_TASKS = 'ik_today_total_tasks';
    static readonly FOCUS_RATE = 'ik_focus_rate';
    static readonly WEEK_FOCUS_SEC = 'ik_week_focus_sec';
    static readonly WEEK_TREND = 'ik_week_trend_json';
    static readonly EXAM_DAYS = 'ik_exam_days';
    static readonly DATA_VERSION = 'ik_data_version';
    // 专注实时状态
    static readonly FOCUS_ELAPSED = 'ik_focus_elapsed';
    static readonly FOCUS_NET = 'ik_focus_net';
    static readonly FOCUS_STATE = 'ik_focus_state';
    static readonly FOCUS_QA_ELAPSED = 'ik_focus_qa_elapsed';
    static readonly CAMERA_ON = 'ik_camera_on';
    // 当前计划
    static readonly CURRENT_PLAN = 'ik_current_plan_json';
}
export class Product {
    static readonly COMPANION_NAME = '小伴';
    static readonly AI_TAG = '💡 AI 智能体';
}
export class DemoFlag {
    /** 是否开启专注检测的自动状态流转脚本（绿→黄→红） */
    static readonly AUTO_SCRIPT = true;
    /** 自动脚本的检测间隔（毫秒） */
    static readonly DETECT_INTERVAL = 3000;
    /** 定时器 tick（毫秒） */
    static readonly TICK = 1000;
}
