
> **文档用途**：产品设计、UI/UX 设计、前后端开发、AI Agent 开发、Workbuddy 代码编写唯一依据  
> **整合原则**：保留原 PRD 产品愿景与页面闭环，吸收优化建议中的指标口径、感知管线、干预引擎、AI 接口规范、空态/中断恢复、Mock→Real 契约  

---

# 目录

```
0.  硬性规则
1.  产品定位与目标
2.  阶段范围
3.  信息架构
4.  会话生命周期状态机
5.  指标口径字典
6.  五维画像公式
7.  感知管线技术规格
8.  Focus State Engine 参数表
9. 干预策略引擎
10. AI Context Assembly
11. 功能规格 FR
12. 数据模型
13. Service 接口契约与 Mock→Real 矩阵
14. AI 接口与调用规范
15. API 凭证与平台选择
16. 空态、加载、错误、中断恢复
17. 隐私合规与安全
18. 非功能需求
19. UI 视觉方向
20. Workbuddy 开发顺序
21. 验收清单
22. 最终产品定义
```


# 0. 硬性规则

1. 动态 AI 内容不得硬编码在页面组件中，必须经 `AIService` / `CompanionService` / `ReviewService` 返回。
2. 核心计时、摄像头检测、本地记录不依赖云端 AI。
3. 所有指标必须按《指标口径字典》计算，不允许各页面自行解释。
4. 隐私分项授权必须是全局事实源。
5. 关闭摄像头后必须降级为"仅计时模式"，UI 明确显示"本次未开启感知"。
6. 少于 3 次会话，画像页显示"还在了解你"，禁止显示默认五维雷达图。
7. `FocusController` 是唯一计时源，`FocusBreak` 等页面只渲染，不得自行 `setInterval` 计时。
8. 使用 `Date.now()` 差值驱动计时，每 10s 快照，支持崩溃/后台恢复。
9. Mock 与 Real 必须同契约，替换时不改 UI。
10. AI 输出必须经 JSON Schema Validator；无效则重试或本地兜底。
11. API Key 只放后端，客户端代码不得出现。
12. 所有 AI 页面顶部显示"AI 智能体"，首次进入说明不是真人。

---

# 1. 产品定位与目标

**定位**：专注感知智能 AI 学伴。  
**Slogan**：陪你学，更懂你何时需要推一把。  
**核心理念**：用户专注时 AI 安静；用户需要帮助时 AI 出现；长期使用后 AI 越来越懂用户。  
**不是**：番茄钟 + AI 聊天，也不是摄像头监督工具。

**MVP 目标**：闭环真实跑通，指标口径正确，隐私门禁生效，Mock AI 可无痛替换。  
**非目标**：真实 LLM 全量接入、真实手表、真实 OCR、订阅、企业/教育场景。

---

# 2. 阶段范围

| 阶段 | 范围 |
|---|---|
| MVP P0 | 首页、目标编辑、AI 任务规划 Mock、任务确认、专注页、暂停/休息、结束、AI 答疑文字+图片 Mock、单次复盘、历史记录、4 Tab、权限门禁、空态/中断恢复、指标字典、FocusEvent、TaskTimeline |
| V1 | 智能手表接入、心率/HRV/手腕动作、多设备融合、五维画像、长期趋势、AI 人格真实生效、AI Memory、动态专注阈值、个性化陪伴策略、语音答疑、真实 LLM 接入 |
| V2 | 鸿蒙桌面卡片、负一屏、小艺 Skill、人格定制、深度分析、订阅、企业/教育 |

---

# 3. 信息架构

底部 4 Tab：

```text
首页
工作台
复盘
我的
```

- **首页**：今日目标、今日任务、今日数据、开始专注、目标编辑入口。
- **工作台**：考试总览、总体进度、科目进度、长期趋势、AI 洞察。
- **复盘**：今日复盘、历史记录、周报、月报、专注画像。
- **我的**：AI 学伴、设备、通知、隐私、数据管理、关于。

---

# 4. 会话生命周期状态机

```text
IDLE
→ PLANNING
→ READY
→ FOCUSING
   ├── GREEN
   ├── YELLOW
   └── RED
→ PAUSED
→ RESTING
→ QA
→ FOCUSING
→ FINISHED
→ REVIEW
→ ARCHIVED
```

**所有出口边必须处理**：返回键、息屏、来电、权限关闭、崩溃、杀进程、卸载重装。

**规则**：

- `FocusController` 唯一计时源。
- `FocusBreak` 不自己起倒计时，只显示 `FocusController.breakRemaining`。
- 从休息页按系统返回键，必须调用 `endBreak()`，不得卡死 RESTING。
- 每 10s 写快照 `SessionSnapshot`。
- 崩溃恢复时弹窗：`继续上次专注 / 结束并保存 / 放弃`。

---

# 5. 指标口径字典

| 指标 | 定义 | 公式/口径 |
|---|---|---|
| 墙钟会话时长 | 开始到结束的真实时间 | `endTime - startTime` |
| 休息时长 | RESTING 累计 | 仅休息态 |
| 暂停时长 | PAUSED 累计 | 不计入总学习 |
| 总学习时长 | 有效学习墙钟 | `墙钟 - 休息 - 暂停` |
| 答疑时长 | QA 状态累计 | 计入总学习，不计入净专注 |
| 分心时长 | YELLOW + RED 累计 | 计入总学习，不计入净专注 |
| 净专注时长 | GREEN 状态累计 | 或 `总学习 - 答疑 - 分心` |
| 净专注率 | 专注质量 | `净专注时长 / 总学习时长`，分母为 0 时返回 0 |
| 任务完成率 | 计划完成度 | `Σ已完成任务.estimatedDuration / Σ全部任务.estimatedDuration`；无预计时长则按任务数 |
| 专注阈值 | 疲劳前连续专注能力 | 最近 N 次 GREEN 连续段中位数，N>=3 |
| 黄金时段 | 高效时段 | 过去 14 天，按 2 小时窗口的净专注率最高，至少 3 次会话 |
| 易分心任务 | 最易分心任务类型 | 按"分心次数 / 任务时长"或分心率最高，不再用完成率最低 |

---

# 6. 五维画像公式

- 效率 `efficiency = 100 * clamp(0.6 * 净专注率 + 0.4 * 任务完成率)`
- 专注度 `concentration = 100 * 最近7次平均净专注率`
- 稳定性 `stability = 100 * clamp(1 - 最近N次净专注率标准差 / 0.3)`
- 执行力 `execution = 100 * clamp(0.7 * 任务完成率 + 0.3 * min(连续学习天数 / 7, 1))`
- 抗干扰 `antiDistraction = 100 * clamp(0.6 * (1 - 每小时分心次数 / 6) + 0.4 * 干预后5分钟恢复率)`

**最小样本**：`N >= 3`。  
少于 3 次会话，画像页显示"还在了解你"，不渲染雷达图数值。  
`clamp` 范围 0-100。

---

# 7. 感知管线技术规格

**输入**：

```text
CameraState + WatchState + SessionContext + UserAction
```

**CameraState**：`looking_screen / looking_away / away / sleepy / unavailable`  
**WatchState**：`heart_rate / hrv / wrist_activity`

**MVP**：默认 Mock + 手动模拟面板，真实端侧检测作为可插拔开关。  
**V1**：Core Vision Kit / MindSpore Lite 端侧推理，原始影像不上传、不保存。  
**采样**：摄像头推理 1-5 FPS，状态融合 1Hz；手表 1Hz。  
**功耗预算**：感知开启时每小时耗电 < 8%，单帧处理 < 50ms。  
**失败降级**：无权限/关闭/占用/不可用 → `PERCEPTION_OFF`，仅计时，UI 显示"本次未开启感知"。  
**误报预算**：误报率 < 5%，召回 > 80%；误报比漏报伤害更大。

---

# 8. Focus State Engine 参数表

| 转换 | 条件 |
|---|---|
| GREEN → YELLOW | 连续 5s `looking_away/sleepy`，置信度 >= 0.7；或 10s 内 3 次 |
| YELLOW → RED | 连续 15s `away/sleepy`；或 5 分钟内 3 次 YELLOW |
| RED → YELLOW | 连续 5s `looking_screen` |
| YELLOW → GREEN | 连续 10s `looking_screen` |
| 最小驻留 | 10s |
| 置信度过滤 | < 0.5 忽略 |
| 冷却 | YELLOW 3 分钟，RED 5 分钟 |
| 干预预算 | 每 10 分钟最多 2 次轻干预、1 次重干预 |

`FocusEvent.confidence` 必须被状态引擎消费，不能采而不信。

---

# 9. 干预策略引擎

**升级阶梯**：

```text
忽视
→ 采样加密
→ 呼吸节奏加快（无文案）
→ 边缘柔光（无文案）
→ 一句轻提示
→ 一次震动/声音
→ 主动询问
→ 建议休息并自动结算
```

每一步都要：

- **预算控制**：单位时长最多打扰 N 次。
- **反馈回收**：用户忽略/接受/继续/休息/结束/手动纠正。
- **写回策略参数**：减少或增加后续干预频率。

**人格映射**：

- 严格教练型：直接、简短、强约束。
- 温和陪伴型：温和、鼓励、不指责。
- 极简安静型：尽量无语音、无文字，主要用光/触觉。
- AI 智能适配：作为策略模式，自动调整提醒频率、语气、专注时长、休息时间。

**无手表时**，RED 干预使用手机声音 + 屏幕选择，**不假装震动**。

---

# 10. AI Context Assembly

**三层记忆**：

- **L1 会话内**：当前任务、最近 5 分钟状态摘要、最近 3 条答疑、干预记录。Token < 800。
- **L2 近期**：7 日趋势、同类任务实际耗时偏差、近 3 次干预接受率。Token < 1200。
- **L3 长期**：五维画像、黄金时段、易分心任务类型、人格。Token < 800。

**总 token 预算** <= 3000。  
**L3 缓存** 24h。  
**无网络时**使用本地兜底文案包，核心功能不受影响。

---

# 11. 功能规格 FR

| 编号 | 功能 | 关键验收 |
|---|---|---|
| FR-01 | 首页 | 显示今日目标、任务、已学习、专注率、开始专注、目标编辑 |
| FR-02 | 目标编辑 | 可修改考试类型、考试日期、目标科目 |
| FR-03 | AI 任务规划 | 自然语言输入；追问 2-3 轮；后两轮回答必须参与 `planTasks()` |
| FR-04 | 任务确认 | 动态 Task Card；预计总时间；确认/修改 |
| FR-05 | 专注页 | 极简；显示当前任务、计时、状态、呼吸动画、AI 答疑、暂停、结束 |
| FR-06 | 感知授权门禁 | 关闭摄像头后 `FocusDetectionService` 不启动，UI 明示"未开启感知" |
| FR-07 | 状态引擎 | 去抖参数生效；不闪烁；`confidence` 被消费 |
| FR-08 | 干预引擎 | 升级阶梯、预算、反馈回收、人格映射 |
| FR-09 | 暂停/休息 | `FocusController` 唯一计时；返回键不卡死 |
| FR-10 | AI 答疑 | MVP 文字+图片 Mock；QA 计入总学习，不计净专注 |
| FR-11 | 结束复盘 | 总学习、净专注、专注率、任务完成率、曲线、AI 发现、建议、QA 记录 |
| FR-12 | 工作台 | 考试总览、总体进度、科目进度、30 天趋势、AI 长期洞察 |
| FR-13 | 复盘历史 | 今日/昨日/本周/上周/更早；可进详情 |
| FR-14 | 专注画像 | N>=3 才显示五维；否则"还在了解你" |
| FR-15 | AI 学伴设置 | 人格、语音、震动、主动提醒频率；人格必须影响 Prompt 与干预 |
| FR-16 | 设备中心 | 手机、摄像头、手表；Mock 状态明确标注 |
| FR-17 | 隐私与数据 | 分项授权；清除数据；原始影像未保存 |
| FR-18 | AI 身份透明 | 所有 AI 页面顶部显示"AI 智能体"，首次说明不是真人 |

---

# 12. 数据模型

必须包含：

```text
User
StudyPlan
Task
StudySession
FocusEvent
QARecord
Review
FocusProfile
TaskTimeline
Authorization
InterventionEvent
SessionSnapshot
```

**关键字段**：

- `Task.actualDuration` 必须被赋值。
- `Task.sessionId` 必须被赋值。
- `TaskTimeline` 记录第几分钟在哪个任务上。
- `FocusProfile.sampleCount`、`updatedAt`。
- `Authorization` 全局唯一：camera / mic / health / notification。
- `InterventionEvent`：级别、通道、用户反馈、是否恢复专注。

---

# 13. Service 接口契约与 Mock→Real 矩阵

| Service | Mock | Real | 切换要求 |
|---|---|---|---|
| TaskAgent | 规则拆分 | LLM | 同 JSON Schema |
| CompanionAgent | 固定策略 | LLM+策略 | 必须返回 `should_intervene/intervention_level/channel/message/action` |
| ReviewAgent | 模板+数据 | LLM | 同 JSON Schema |
| PlanningAgent | 规则 | LLM | 同 JSON Schema |
| QAService | Mock 答案 | LLM | 同 JSON Schema |
| FocusSensor | 手动模拟 | Camera/Watch | 同状态枚举 |
| SensorService | 随机数 | 手表 | 同字段契约 |
| StorageService | RDB | RDB | 已可用 |
| PermissionService | 本地状态 | 系统权限 | 全局事实源 |

AI 输出必须经 Schema Validator：有效则渲染，无效则重试/兜底。

---

# 14. AI 接口与调用规范

## 14.1 总架构

```text
ArkUI 页面
   ↓
AIService / QAService / CompanionService / ReviewService / PlanningService
   ↓
AI Gateway（后端 BFF，真实环境）
   ↓
LLM / Agent / RAG / 规则兜底
```

**MVP**：

```text
页面 → Service 接口 → MockAIService → 本地 JSON 兜底
```

**V1**：

```text
页面 → Service 接口 → 后端 AI Gateway → 盘古/第三方 LLM
```

**硬性要求**：

1. 页面不得直接调用 LLM。
2. API Key 不得放在客户端。
3. Mock 与 Real 必须同接口、同 JSON Schema。
4. AI 失败不得影响计时、感知、学习记录。
5. 所有 AI 输出必须经 Schema Validator。
6. 无效输出 → 重试 1 次 → 本地兜底。

## 14.2 统一 AI 请求 / 响应

```ts
interface AIRequest<TPayload> {
  requestId: string;
  scene: 'task_plan' | 'task_dialog' | 'companion' | 'qa_text' | 'qa_image' | 'review' | 'planning' | 'memory';
  userId: string;
  sessionId?: string;
  payload: TPayload;
  context?: {
    l1?: SessionContext;
    l2?: RecentContext;
    l3?: LongTermProfile;
  };
  options?: {
    stream?: boolean;
    temperature?: number;
    maxTokens?: number;
    timeoutMs?: number;
  };
}

interface AIResponse<TData> {
  requestId: string;
  ok: boolean;
  schemaVersion: string;
  data?: TData;
  error?: {
    code: string;
    message: string;
    retryable: boolean;
  };
  usage?: {
    promptTokens: number;
    completionTokens: number;
    latencyMs: number;
  };
  fallback?: boolean;
}
```

## 14.3 必须定义的 AI 接口

| 场景 | 接口 | 调用时机 | 输入 | 输出 | 流式 | 失败兜底 |
|---|---|---|---|---|---|---|
| 任务规划 | `TaskAgent.planTasks` | 用户点开始专注且无计划 | 自然语言目标、考试目标、可用时间、历史任务 | 结构化学习计划 | 可流式 | 规则模板 4 任务 |
| 任务追问 | `TaskAgent.continueDialog` | 规划对话中 | 对话历史、已抽取字段 | 下一问或最终计划 | 流式 | 固定 2 轮追问 |
| 专注干预 | `CompanionAgent.decide` | 状态变化/定时 | FocusState、持续时间、当前任务、人格、干预历史 | `should_intervene / level / channel / message / action` | 非流式 | 规则引擎 + 本地文案 |
| 文字答疑 | `QAService.askText` | 用户输入问题 | 问题、当前任务、最近 QA、L1/L2 上下文 | 答案、引用、免责声明 | 流式 | "AI 暂不可用" |
| 图片答疑 | `QAService.askImage` | 用户拍题 | 图片 OCR 文本或图片、当前任务 | 答案、步骤、免责声明 | 非流式/流式 | 提示重试 |
| 单次复盘 | `ReviewAgent.generate` | 结束学习后 | StudySession、FocusEvents、Task、QA、Profile | summary、insights、suggestions | 非流式 | 本地模板 + 真实数据 |
| 长期规划 | `PlanningAgent.generate` | 工作台/周报/月报 | 7/30 天数据、画像、考试目标 | weekly_insight、schedule、priority、reason | 非流式 | 规则建议 |
| 记忆更新 | `MemoryService.update` | 复盘后 | 新 Session + 历史 Profile | 是否更新、更新字段 | 非流式 | 不更新 |

## 14.4 关键 JSON Schema

### 任务规划

```json
{
  "type": "task_plan",
  "title": "今日高数复习",
  "estimated_minutes": 120,
  "tasks": [
    {
      "title": "极限章节复习",
      "estimated_minutes": 30
    }
  ]
}
```

### Companion 干预

```json
{
  "should_intervene": true,
  "intervention_level": "YELLOW",
  "channel": "phone",
  "message": "注意力好像飘走啦。",
  "action": "none"
}
```

### 答疑

```json
{
  "type": "qa",
  "answer": "...",
  "steps": ["..."],
  "disclaimer": "答案仅供参考，建议核对教材。"
}
```

### 单次复盘

```json
{
  "type": "review",
  "summary": "...",
  "best_focus_period": {
    "start": "...",
    "end": "..."
  },
  "fatigue_point": "...",
  "distraction_pattern": "...",
  "suggestions": ["...", "..."]
}
```

### 长期规划

```json
{
  "type": "planning",
  "weekly_insight": "...",
  "recommended_schedule": [],
  "priority_tasks": [],
  "reason": "..."
}
```

## 14.5 超时、重试、流式

| 场景 | 超时 | 重试 | 流式 |
|---|---|---|---|
| 任务追问 | 15s | 1 次 | 是 |
| 任务规划 | 20s | 1 次 | 可流式 |
| 文字答疑 | 20s | 1 次 | 是 |
| 图片答疑 | 30s | 1 次 | 否 |
| Companion | 5s | 0 次 | 否 |
| 单次复盘 | 30s | 1 次 | 否 |
| 长期规划 | 60s | 1 次 | 否 |

**失败后**：

```text
AI Response
↓
Schema Validator
↓
Valid → Render
Invalid → Retry / Fallback
```

## 14.6 Prompt 管理

目录：

```text
/prompts
  task_planner.md
  task_dialog.md
  companion.md
  qa.md
  review.md
  planning.md
  memory.md
```

每个 Prompt 必须有：

- 版本号
- 输入变量说明
- 输出 JSON Schema
- 禁止内容清单
- 语气负面清单
- 示例输入/输出

## 14.7 内容安全与隐私

- AI 答疑必须带免责声明。
- 禁止生成违法、自伤、仇恨、色情、作弊等内容。
- 图片答疑优先端侧 OCR，只上传文本；若上传图片必须明示并获授权。
- 原始影像、生理原始数据不上传。
- 日志脱敏：不记录完整用户问题、答案、图片。
- 遥测只记录：`scene`、`requestId`、`latency`、`token`、`schemaValid`、`fallback`、`userFeedback`。

## 14.8 实现要求

1. 先定义 `AIService` 接口和所有 Mock 实现。
2. 所有页面只依赖 Service 接口，不依赖具体 LLM。
3. 每个 AI 功能必须有：
   - Mock 实现
   - Real 占位实现
   - JSON Schema
   - Schema Validator
   - 超时/重试/兜底
4. AI 失败时 UI 必须显示可理解状态，不阻塞核心专注。
5. V1 接真实 AI 时，只替换 `MockAIService` 为 `GatewayAIService`，页面不改。

---

# 15. API 凭证

## 15.1 总览：需要哪些 API

| 类别 | API / 能力 | 用途 | 获取方式 |
|---|---|---|---|
| **AI 大模型** | 文本生成 / 对话 / 推理 API | 任务规划、答疑、复盘、长期洞察 | 第三方大模型平台申请 |
| **AI 多模态** | 图片理解 / OCR API | 拍题答疑（MVP 可 Mock） | 同大模型平台 |
| **系统-视觉** | Core Vision Kit | 摄像头人脸/人体/视线检测 | HarmonyOS 内置，无需申请 |
| **系统-相机** | CameraKit + MetadataOutput | 获取相机帧与元数据 | HarmonyOS 内置，声明权限 |
| **系统-端侧推理** | MindSpore Lite Kit | 端侧模型推理（V1 可选） | HarmonyOS 内置 |
| **系统-后台** | Background Tasks Kit | 息屏/后台持续计时 | HarmonyOS 内置，声明权限 |
| **系统-存储** | ArkData / RDB | 本地会话数据持久化 | HarmonyOS 内置 |

> **MVP 阶段实际需要"申请"的只有大模型 API 这一项。**

## 15.2 AI 大模型 API


```text
AI_API_BASE_URL = https://ws-2f33030lijt758d4.cn-beijing.maas.aliyuncs.com/compatible-mode/v1
AI_API_KEY = sk-ws-H.PDYRMEE.hVZE.MEUCIQD7ZvNxCADR07xgmZJp7a8nK1mui78U_XMg8q1MA8SwZAIgYFIr_MHlGr5u93oU8SNpaA3yZq0S7bp0jII7mG-kHEw
AI_MODEL_TEXT = qwen-plus        # 任务规划、复盘、长期规划
AI_MODEL_MULTIMODAL = qwen-vl-plus  # 拍题答疑
AI_MODEL_FAST = qwen-turbo       # Companion 干预文案
```
### ① 任务规划对话

- **用途**：用户说"今天复习高数两小时"，AI 追问 2-3 轮后生成结构化任务列表
- **调用方式**：多轮对话（Chat Completion）
- **要求**：支持 Function Calling / JSON 输出
- **建议模型**：通义千问-Plus 或 GLM-4-Plus

### ② 专注中 AI 答疑

- **用途**：用户文字提问或拍题，AI 返回解答
- **调用方式**：文本对话 + 图片理解（多模态）
- **要求**：流式输出，图片理解用于拍题
- **建议模型**：通义千问-VL 或 DeepSeek

### ③ 单次复盘分析

- **用途**：结束学习后，基于 StudySession + FocusEvent + Task + QA 数据生成动态复盘
- **调用方式**：单轮生成，输入结构化数据，输出 JSON
- **要求**：严格按 JSON Schema 返回
- **建议模型**：GLM-4-Plus 或通义千问-Plus

### ④ 长期洞察与规划

- **用途**：基于 7/30 天数据生成周报、月报、下一轮学习规划
- **调用方式**：单轮生成，输入历史聚合数据
- **要求**：长上下文（128K），支持 JSON 输出
- **建议模型**：通义千问-Max 或 GLM-4-Plus

### ⑤ 专注中 Companion 干预文案

- **用途**：YELLOW/RED 状态时生成低打扰提示文案
- **调用方式**：短文本生成，超时 5 秒
- **要求**：极低延迟；失败时直接走本地兜底文案
- **建议**：qwen-turbo 或纯规则 + 模板兜底


## 15.3 HarmonyOS 系统能力 API

### 摄像头感知

```ts
import { camera } from '@kit.CameraKit';
import { faceDetector } from '@kit.CoreVisionKit';
```

- **CameraKit MetadataOutput**：人脸检测、人体检测、显著性检测
- **Core Vision Kit**：目标检测，输入 PixelMap，返回 boundingBox / score / labels
- **权限**：`ohos.permission.CAMERA`（动态申请）

### 后台持续计时

```ts
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
```

- 申请长时任务类型 `KEEP_BACKGROUND_RUNNING`，发布持续通知
- **权限**：`ohos.permission.KEEP_BACKGROUND_RUNNING`

### 端侧推理（V1 可选）

```ts
import { mindSporeLite } from '@kit.MindSporeLiteKit';
```

- HarmonyOS 内置 MindSpore Lite，支持模型转换、推理调度、硬件加速
- 适合 V1 做端侧视线/姿态检测，MVP 可先用 Core Vision Kit 或 Mock



**需遵守**：

1. API Key 只放在后端网关，**不得出现在客户端代码中**。
2. 所有 AI 调用经 `AIService` 接口，MVP 先用 `MockAIService`，V1 替换为 `GatewayAIService`。
3. 流式接口用于：任务追问、文字答疑。非流式用于：复盘、长期规划、Companion。
4. 每个场景的超时/重试/兜底策略按 §14.5 执行。

---

# 16. 空态、加载、错误、中断恢复

- 画像空态：<3 次会话 → "还在了解你"。
- 趋势空态：无数据 → 引导开始第一次专注。
- AI 超时：本地兜底文案 + 重试按钮。
- 摄像头权限拒绝：仅计时模式，UI 明示。
- 摄像头被占用：提示并降级。
- 会话中断：快照恢复弹窗。
- AI 答疑失败：显示"AI 服务暂不可用"，不影响计时和记录。
- 数据清除：二次确认，清除学习记录/画像/AI偏好/生理数据，保留授权状态。

---

# 17. 隐私合规与安全

- 分项授权，不得默认打包。
- 授权状态是全局唯一系统事实源。
- 原始影像、生理原始数据不上传、不保存。
- 本地生成专注状态标签。
- 遥测边界：只上传聚合指标，不上传原始数据。
- AI 内容免责：答案仅供参考，建议核对教材。
- 禁止生成内容类型明确写入 Prompt 管理。

---

# 18. 非功能需求

- **功耗**：感知开启每小时 < 8%。
- **性能**：页面切换 < 300ms，状态更新 1Hz。
- **稳定性**：崩溃恢复，RESTING 不卡死。
- **兼容**：HarmonyOS NEXT，手机优先。
- **无障碍**：字号、对比度、震动/声音可关闭。

---

# 19. UI 视觉方向

**关键词**：温暖 / 安静 / 有生命感 / 克制 / 陪伴。

**建议**：暖橙色品牌主色、米白背景、深灰文字、大圆角、大留白、柔和阴影、微弱渐变、呼吸动画、状态光晕。

**避免**：复杂科技风、赛博朋克、大量数据仪表盘、密集表格、过多按钮、强制提醒感。

---

# 20. 开发顺序

| 阶段 | 任务 | 理由 |
|---|---|---|
| 第 0 步 | 写 `Metrics` 指标字典模块；空态/中断规范；授权门禁 | 不依赖技术决策，立刻消 P0/P1 |
| 第 1 步 | 修 B-1 人格生效+启动恢复；B-2 授权门禁；B-4 计时口径+崩溃恢复；C-4 RESTING 卡死 | 真实用户可见 bug |
| 第 2 步 | 任务级归因：`Task.actualDuration/sessionId/TaskTimeline` | 支撑 AI 洞察 |
| 第 3 步 | 五维画像重写；干预策略引擎；Context Assembly | 核心壁垒 |
| 第 4 步 | 真实感知可插拔；手表 Mock→Real | V1 技术选型 |
| 第 5 步 | AI Gateway 接入，替换 MockAIService | V1 真实 AI |

---

# 21. 验收清单

- 无前端硬编码 AI 总结。
- 每次 Session 保存总时间、净专注、答疑、完成率、FocusEvents、Review。
- 连续多次 Session 后，FocusProfile 与下一轮建议发生变化。
- 隐私开关真实生效。
- 计时在后台/息屏/崩溃后不严重失真。
- 画像少于 3 次会话不显示虚假五维。
- RESTING 状态不会因返回键卡死。
- 任务规划后两轮回答真实参与计划生成。
- AI 人格影响文案与干预。
- 无手表时 RED 不假装震动。
- API Key 不出现在客户端。
- AI 输出全部经 Schema Validator。
- AI 失败不影响核心计时与感知。

---

# 22. 最终产品定义

iKnow 不是：

> 番茄钟 + AI 聊天  
> 摄像头监督 + AI 总结

而应该是：

> 一个能够感知你的学习状态、理解你的学习习惯，并根据长期数据主动调整陪伴方式的 AI 学习搭子。

**核心循环**：

**感知 → 理解 → 陪伴 → 复盘 → 学习 → 再理解。**

最终目标不是让用户每天"打卡更多"，而是让用户逐渐发现：

> "它越来越懂我什么时候适合学习、什么时候容易分心，以及我应该怎么学。"
