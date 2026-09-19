/**
 * AppStorage 键名 & 产品常量
 * 跨页面响应式状态统一通过这些键写入 / 读取
 */
export class StorageKey {
  static readonly USER_NICKNAME = 'ik_user_nickname'
  static readonly USER_AVATAR = 'ik_user_avatar'
  static readonly USER_PERSONALITY = 'ik_user_personality'

  // 首页 / 工作台聚合
  static readonly TODAY_FOCUS_SEC = 'ik_today_focus_sec'
  static readonly TODAY_NET_FOCUS_SEC = 'ik_today_net_focus_sec'
  static readonly TODAY_DONE_TASKS = 'ik_today_done_tasks'
  static readonly TODAY_TOTAL_TASKS = 'ik_today_total_tasks'
  static readonly FOCUS_RATE = 'ik_focus_rate'
  static readonly WEEK_FOCUS_SEC = 'ik_week_focus_sec'
  static readonly WEEK_TREND = 'ik_week_trend_json'
  static readonly EXAM_DAYS = 'ik_exam_days'
  static readonly DATA_VERSION = 'ik_data_version'

  // 专注实时状态
  static readonly FOCUS_ELAPSED = 'ik_focus_elapsed'
  static readonly FOCUS_NET = 'ik_focus_net'
  /** 总学习秒数 = 墙钟 − 休息 − 暂停（与复盘页「总学习时长」同口径） */
  static readonly FOCUS_STUDY = 'ik_focus_study'
  static readonly FOCUS_STATE = 'ik_focus_state'
  static readonly FOCUS_QA_ELAPSED = 'ik_focus_qa_elapsed'
  /** 休息剩余秒数（休息态由 FocusController 独占，页面只读此值） */
  static readonly FOCUS_BREAK_REMAIN = 'ik_focus_break_remain'
  /** 是否有会话正在运行（1/0）：供根页/首页以 @StorageProp 响应式读取 */
  static readonly FOCUS_RUNNING = 'ik_focus_running'
  static readonly CAMERA_ON = 'ik_camera_on'

  // 当前计划
  static readonly CURRENT_PLAN = 'ik_current_plan_json'
  /** 从「学习记录」进入单次复盘时要加载的会话 id（一次性，读完即清） */
  static readonly REPORT_SESSION_ID = 'ik_report_session_id'

  /** 模拟模式（1 = 开；默认开，因为当前无硬件）。关闭且无真表连接时不产生任何信号 */
  static readonly SIM_MODE = 'ik_sim_mode'
  /** 分心确认后的震动提醒（1 = 开，默认开） */
  static readonly VIBRATE_ON = 'ik_vibrate_on'
  /** 分心确认后的语音提醒（1 = 开，默认关；依赖 HMS，环境不支持时静默） */
  static readonly VOICE_ON = 'ik_voice_on'

  // 服务卡片快照（主界面写、卡片进程读；卡片不读主进程内存）
  static readonly CARD_TODAY = 'ik_card_today'
  static readonly CARD_RATE = 'ik_card_rate'
  static readonly CARD_ADVICE = 'ik_card_advice'

  // 分项授权（PRD §17 全局唯一事实源，落库）
  static readonly AUTHORIZATION = 'ik_authorization_json'

  // 感知模式：PERCEPTION_FULL / PERCEPTION_TIMER_ONLY（关闭摄像头后降级）
  static readonly PERCEPTION_MODE = 'ik_perception_mode'

  // 指标最小样本数（§5/§6 N>=3），冗余缓存到 AppStorage 以便 UI 直接读取
  static readonly METRICS_MIN_SAMPLES = 'ik_metrics_min_samples'

  // AI 智能体标识（所有 AI 页面顶部展示）
  static readonly AI_AGENT_TAG = 'ik_ai_agent_tag'

  // AI 智能体首次非真人声明是否已展示（全局仅一次）
  static readonly AI_DISCLAIMER_SHOWN = 'ik_ai_disclaimer_shown'

  // 进行中会话 id（持久化到库，用于崩溃/后台恢复，硬规则 §7）
  static readonly ACTIVE_SESSION_ID = 'ik_active_session_id'

  /** 请求切换根页 Tab（子页面无法直接操作 Index 的 TabsController，用此键传递；-1 = 无请求） */
  static readonly INDEX_TAB_REQUEST = 'ik_index_tab_request'

  /** 请求 Focus 页新开一个会话（1 = 主动开始；消费后置 0） */
  static readonly FOCUS_START_REQUEST = 'ik_focus_start_request'
}

/**
 * 本地登录 KV 键（AuthService 使用）
 * 说明：MVP 无后端，账号密码仅存本地（密码存散列，不落明文）。
 * 生产环境应由服务端鉴权，客户端不持有任何密钥（硬规则 §10）。
 */
export class AuthKey {
  static readonly USERNAME = 'ik_auth_username'
  static readonly PASSWORD_HASH = 'ik_auth_password_hash'
  static readonly LOGGED_IN = 'ik_auth_logged_in'
}

export class Product {
  static readonly COMPANION_NAME = '小伴'

}

export class DemoFlag {
  /** 是否开启专注检测的自动状态流转脚本（绿→黄→红） */
  static readonly AUTO_SCRIPT = true
  /** 自动脚本的检测间隔（毫秒） */
  static readonly DETECT_INTERVAL = 3000
  /** 定时器 tick（毫秒） */
  static readonly TICK = 1000
}
