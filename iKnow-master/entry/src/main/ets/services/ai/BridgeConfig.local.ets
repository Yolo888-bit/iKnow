/**
 * 本地密钥占位文件（**默认提交的是空值**）
 *
 * 为什么单独一个文件：`BridgeConfig.ets` 里原先直接硬编码了真实大模型 Key，
 * 导致 Key 进入 git 历史 —— 客户端持有长期 Key 等于任何人反编译 HAP 即可盗用额度，
 * 也与「Key 只放后端」的既有硬规则冲突。
 *
 * 使用方式（本地联调）：
 *  1. 在下方填入**新申请**的 Key（旧 Key 请务必到控制台吊销）；
 *  2. 立刻执行一次，让 git 忽略本文件的本地修改：
 *       git update-index --skip-worktree entry/src/main/ets/services/ai/BridgeConfig.local.ets
 *     （.gitignore 对**已被跟踪**的文件无效，所以必须用 skip-worktree）
 *  3. 提交前用 `git status` 确认本文件不在改动列表里。
 *
 * 留空时的行为：`GatewayAIService.isReady()` 判定为未配置，所有场景自动回退
 * `MockAIService`，功能不中断（只是规划/对话走本地模板）。
 *
 * 更推荐的做法：把 Key 放到后端 BFF，客户端只持有网关地址 + 短期 token。
 */
export class LocalSecrets {
  /** 大模型访问令牌（留空 = 不启用真实网关，自动回退本地模板） */
  static AI_API_KEY: string = ''
}
