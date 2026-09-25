/**
 * AppStorage 键名 & 产品常量
 * 跨页面响应式状态统一通过这些键写入 / 读取
 */
export class StorageKey {
  static readonly USER_NICKNAME = 'ik_user_nickname'
  static readonly USER_AVATAR = 'ik_user_avatar'
  static readonly USER_PERSONALITY = 'ik_user_personality'

  // 首页聚合（原工作台页面已移除）
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

  /**
   * 请求 Focus 页执行"结束专注"（0 = 无；1 = 生成复盘；2 = 直接结束/丢弃；消费后置 0）。
   *
   * 为什么休息页不自己结束：休息页是 `pushUrl` 上来的，栈是「根页 → 专注页 → 休息页」，
   * 它自己 `back()` 只会退回**已经结束的专注页**；而 `router.back(index)` 在不同版本上行为不稳。
   * 索性把结束动作交回专注页执行 —— 这样"从休息页结束"和"从专注页结束"走的是**同一段代码**，
   * 落点与提示文案天然一致。
   */
  static readonly FOCUS_END_REQUEST = 'ik_focus_end_request'
  /**
   * 请求 Focus 页**以自由专注开始**：这次会话不挂任何任务（1 = 是；消费后置 0）。
   * 用于「跳过规划，直接开始专注」—— 用户明确说了"跳过规划直接专注"，
   * 就不该把今日计划里的任务又带进这次会话（今日计划本身**不清空**，首页照旧显示）。
   */
  static readonly FOCUS_FREE_REQUEST = 'ik_focus_free_request'
  /**
   * 首页「开始专注」进入时设置：本次会话**只挂未完成任务**，已完成的不带入。
   * （已完成任务仍保留在首页「今日任务」里，只是这次不重复挂上。）
   * 与 `FOCUS_START_REQUEST` 同一时机设置、仅在新开会话时被 `Focus.ets` 消费一次。
   */
  static readonly FOCUS_HOME_INCOMPLETE_REQUEST = 'ik_focus_home_incomplete_request'

  /** 贴合目标的励志标语（AI 生成，进程内缓存；目标变更时置空重新生成） */
  static readonly GOAL_SLOGAN = 'ik_goal_slogan'

  /**
   * 上一次真实展示过的首页语录（KV 持久化）。
   * 用来保证"每次打开 App 都换一句新的" —— 只在 AppStorage 里存是不够的，
   * 那是进程内缓存，重启就没了，也就无从判断是否重复。
   */
  static readonly LAST_SLOGAN = 'ik_last_slogan'

  /**
   * 用户是否**走过**目标引导（'1' / ''）。
   * 不能只看 goal.examType 是否为空：老版本 seed 曾预置过「考研」，
   * 升级后残留会让引导被跳过。用显式标记才可靠。
   */
  static readonly GOAL_CONFIGURED = 'ik_goal_configured'
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

  /**
   * 已同意过的《用户服务协议 / 隐私政策》**版本号**。
   *
   * 为什么记版本而不是一个布尔值：文档改了内容（比如新增了数据用途）之后，
   * 旧的"已同意"就不再有效，必须重新征求一次同意。
   * 存的是 `PrivacyDoc.VERSION`，与当前版本不一致就视为"未同意"。
   */
  static readonly CONSENT_VERSION = 'ik_auth_consent_version'
  /** 同意的**时间戳**（毫秒字符串），仅作为留痕，不参与逻辑判断 */
  static readonly CONSENT_AT = 'ik_auth_consent_at'
}

/**
 * 《用户服务协议》与《隐私政策》的元信息。
 *
 * ⚠️ 改文档内容时**必须同时改 `VERSION`** —— 否则老用户不会被重新征求同意。
 * 页面（`pages/PrivacyPolicy`）与登录门禁（`pages/Login` / `AuthService`）都读这里，
 * 避免两处各写一个版本号对不上。
 */
export class PrivacyDoc {
  /** 文档版本（语义化：改了实质内容就升次版本号） */
  static readonly VERSION = '1.0.0'
  /** 生效日期 */
  static readonly EFFECTIVE = '2026 年 9 月 25 日'
  /** 文档标题（登录页勾选、隐私页入口都用同一个名字） */
  static readonly AGREEMENT = '用户服务协议'
  static readonly POLICY = '隐私政策'
  /**
   * 打开文档页时预选哪一篇（0 = 用户服务协议；1 = 隐私政策）。
   * 与项目里 `INDEX_TAB_REQUEST` / `FOCUS_*_REQUEST` 同一套做法：
   * 子页面之间用 AppStorage 传意图，避免 `router.getParams()` 取值与类型转换在各版本上不一致。
   */
  static readonly TAB_REQUEST = 'ik_privacy_doc_tab'
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
