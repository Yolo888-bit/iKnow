# iKnow 项目长期记忆

## 项目定位
iKnow 专注感知智能学伴（HarmonyOS NEXT + ArkTS + ArkUI + RDB）。MVP 4 Tab：首页 / 工作台 / AI 学伴 / 我的。

## 12 条硬性规则（用户强制，违反即视为 bug）
1. 动态 AI 内容不得硬编码在页面组件中，必须经 AIService / QAService / CompanionService / ReviewService / PlanningService 返回。
2. 核心计时、摄像头检测、本地记录不依赖云端 AI。
3. 所有指标必须按 PRD §6《指标口径字典》计算，页面不得自行解释（统一走 `Metrics.ets`）。
4. 隐私分项授权是全局唯一事实源（`PermissionService`）；关摄像头降级"仅计时模式"，UI 明示"本次未开启感知"。
5. 少于 3 次会话，画像页显示"还在了解你"，禁止显示默认五维雷达图。
6. `FocusController` 是唯一计时源；`FocusBreak` 不得自行 setInterval 计时。
7. 用 `Date.now()` 差值驱动计时，每 10s 写 SessionSnapshot，支持崩溃/后台恢复。
8. Mock 与 Real 必须同接口、同 JSON Schema，替换时不改 UI。
9. AI 输出必须经 SchemaValidator；无效重试 1 次或本地兜底。
10. API Key 不出现客户端，只走环境变量/后端网关占位。
11. 所有 AI 页面顶部显示"AI 智能体"，首次进入说明不是真人。
12. 无手表时 RED 干预用手机声音+屏幕选择，不假装震动。

## 架构约定
- AI 层：`services/ai/` 下 5 接口 + `MockAIService`（默认）+ `GatewayAIService`（占位）。旧 `services/AIService.ets` 是委托垫片。
- 指标：`services/Metrics.ets` 唯一口径；`ReportService` 只调它。
- 去抖/冷却参数：集中在 `common/FocusTuning.ets`，禁止散落魔法数字。
- 授权：`PermissionService` 全局唯一源，落 `authorization` 表。
- 数据模型缺口已补齐：StudyPlan / Authorization / TaskTimeline / SessionSnapshot / InterventionEvent。
- 冷启动种子：`AppStore.seed()` 只建 1 用户 + 1 目标 + 空画像（sampleCount=0），不伪造会话/五维。

## 开发方式约定（用户要求）
- 每次只做一个阶段，先给计划/接口契约/冲突点，再给变更清单/核心代码/验收点/未完成项。
- 不一次生成整个项目，不修改与当前阶段无关的文件。
- 验收需覆盖 A0-1~A0-10（见对话上下文）。
