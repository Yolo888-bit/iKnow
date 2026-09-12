/**
 * 后端 AI 网关配置（PRD §15）
 *
 * ⚠️ 安全说明（与硬规则 §10 的取舍，务必知悉）：
 *  - 硬规则 §10 要求「API Key 只放后端，客户端代码不得出现」。
 *  - 当前为**本地联调阶段**：项目暂无后端网关，为让 AI 规划对话真正跑通，
 *    这里直接填入了 PRD §15.2 提供的大模型 Key（仅此一处，页面组件内绝不出现）。
 *  - 上线前必须改为：客户端只持有「网关地址 + 后端下发的短期 token」，
 *    把 AI_API_KEY 留空并直接指向后端 BFF，其余代码零改动即可切换。
 *
 * 场景 → 模型映射（来自 PRD §15.2）：
 *  - task_plan / task_dialog / planning / review / memory → 文本大模型（qwen-plus）
 *  - qa_text / qa_image                          → 多模态（qwen-vl-plus）
 *  - companion                                   → 极速模型（qwen-turbo，5s 超时）
 */
export class BridgeConfig {
  /** 后端网关 Base URL（兼容 OpenAI 协议）。非密钥，可保留。 */
  static readonly AI_API_BASE_URL: string =
    'https://ws-2f33030lijt758d4.cn-beijing.maas.aliyuncs.com/compatible-mode/v1'

  /**
   * 大模型访问令牌（来自 PRD §15.2）。
   * 留空 → GatewayAIService 返回 not_configured，由门面自动回退 MockAIService。
   * 生产环境请改为由后端在运行时注入短期 token，不要在此硬编码长期 Key。
   */
  static AI_API_KEY: string =
    'sk-ws-H.PDYRMEE.hVZE.MEUCIQD7ZvNxCADR07xgmZJp7a8nK1mui78U_XMg8q1MA8SwZAIgYFIr_MHlGr5u93oU8SNpaA3yZq0S7bp0jII7mG-kHEw'

  /** 是否启用真实网关。开启后 dispatch 先试网关，失败/未配置时自动回退 Mock（§4/§14.5） */
  static useGateway: boolean = true

  /** 文本大模型（任务规划 / 复盘 / 长期规划） */
  static readonly MODEL_TEXT: string = 'qwen-plus'
  /** 多模态（拍题答疑） */
  static readonly MODEL_MULTIMODAL: string = 'qwen-vl-plus'
  /** 极速模型（Companion 干预文案） */
  static readonly MODEL_FAST: string = 'qwen-turbo'

  /** 按场景返回应使用的模型名（PRD §15.2） */
  static modelForScene(scene: string): string {
    switch (scene) {
      case 'qa_text':
      case 'qa_image':
        return 'qwen-vl-plus'
      case 'companion':
        return 'qwen-turbo'
      case 'task_plan':
      case 'task_dialog':
      case 'planning':
      case 'review':
      case 'memory':
      default:
        return 'qwen-plus'
    }
  }

  /** 每个场景的调用超时（ms），对齐 PRD §14.5 */
  static timeoutForScene(scene: string): number {
    switch (scene) {
      case 'companion':
        return 5000
      case 'task_dialog':
        return 15000
      case 'task_plan':
      case 'qa_text':
        return 20000
      case 'qa_image':
      case 'review':
      case 'memory':
        return 30000
      case 'planning':
        return 60000
      default:
        return 20000
    }
  }
}
