# iKnow —— 专注感知智能考伴

> 陪你学，更懂你何时需要推一把。

基于 **HarmonyOS NEXT + ArkTS + ArkUI** 的 AI Agent 学习陪伴应用原型。核心不是「番茄钟」，而是**通过 AI 主动感知用户状态，而非等待用户主动操作**。

---

## 一、技术栈与运行方式

| 项 | 值 |
|---|---|
| 平台 | HarmonyOS NEXT（API 12，SDK `5.0.0(12)`） |
| 语言 | ArkTS（严格模式） |
| UI | ArkUI 声明式 |
| 持久化 | `@kit.ArkData` 的 `relationalStore`（RDB，即 `@ohos.data.relationalStore`） |
| 状态管理 | `@State` / `@Observed` / `@StorageProp` + `AppStorage` + `@Watch`（Vuex 风格集中 Store） |

**运行步骤：**

1. 使用 **DevEco Studio 5.0.0（build ≥ 243）** 打开 `D:\iKnow`（File → Open）。
2. 等待首次 Sync / 依赖解析（DevEco 会自动下载 hvigor 相关依赖，若提示 SDK 版本升级，选择同步到本机 SDK 版本即可）。
3. 连接设备 / 模拟器，点击 Run 运行 `entry` 模块。

> 图标为脚本生成的占位 PNG（暖橙圆点），如需正式图标可在 `AppScope/resources/base/media` 与 `entry/src/main/resources/base/media` 替换。

---

## 二、项目结构

```
entry/src/main/ets/
├── entryability/EntryAbility.ets   # 启动入口，注入 Context 到存储层
├── common/
│   ├── Theme.ets                    # 设计令牌（暖橙/米白配色、圆角、间距）
│   ├── Constants.ets                # AppStorage 键名 & 产品常量
│   └── FocusStateUi.ets             # 状态 → 颜色/文案映射（绿/黄/红）
├── models/                          # 数据模型（对齐 PRD 第七节）
├── services/                        # 服务抽象层（核心）
│   ├── AIService.ets                #   Mock 盘古：规划/答疑/复盘/画像
│   ├── FocusDetectionService.ets    #   Mock 摄像头视觉（实现 FocusSensor）
│   ├── SensorService.ets            #   Mock 手表（心率/HRV/动作，实现 FocusSensor）
│   ├── DeviceService.ets            #   设备连接 + 模拟设备模式
│   ├── ReportService.ets            #   单次复盘计算
│   ├── FocusController.ets          #   状态机 + 计时引擎 + 检测订阅
│   ├── StorageService.ets           #   RDB 持久化
│   └── ServiceTypes.ets             #   FocusSensor 接口 / 检测结果类型
├── store/AppStore.ets               # 单一事实源（Vuex 风格）
├── components/                      # 可复用组件（计时器/呼吸灯/图表/卡片）
├── pages/                           # 14 个页面
└── utils/                           # 时间格式化 / ID 生成
```

---

## 三、架构分层（UI 零 Mock，全部 Service 注入）

```
┌──────────────────────────────────────────────────┐
│  pages / components（UI 层）                       │
│   只读取 AppStore + 调用 Service，不写死 Mock       │
└───────────────┬──────────────────────────────────┘
                │ 注入
┌───────────────▼──────────────────────────────────┐
│  store/AppStore（单一事实源，Vuex 风格）            │
│   state + action + 联动 + 持久化调度               │
└───────┬──────────────────┬───────────────────────┘
        │                  │
┌───────▼────────┐  ┌──────▼───────────────────────┐
│ Service 抽象层  │  │ StorageService（RDB）          │
│ AIService      │  │   user / task / session /     │
│ FocusDetection │  │   report / profile …          │
│ Sensor         │  └──────────────────────────────┘
│ Device         │
└────────────────┘
```

**关键原则：** UI 层禁止直接写死 Mock 数据。所有数据经 `Service` 注入；`AppStore` 是唯一事实源，读写都落 `StorageService`。

---

## 四、核心数据流（闭环）

```
AI 目标规划 → 任务拆解 → 开启专注 → 实时感知(绿/黄/红状态机)
   → 分层干预 → AI 答疑(计时不中断) → 单次复盘 → 长期画像更新 → 工作台联动
```

- **计时口径**：`总学习时长 = 净专注 + 分心 + 答疑`（休息/暂停不计入）。
- **答疑**：停止摄像头监测，计时继续，计入总时长、不计净专注，问题自动写入本次复盘。
- **结束**：`FocusController.finalize()` → `ReportService` 生成复盘 → 落库 → `AIService.updateProfile` 更新五维画像 → `refreshAggregates` 重算 Dashboard + 周趋势 → 推入 `AppStorage` → 首页/工作台自动联动。

---

## 五、专注状态机

```typescript
enum FocusState {
  FOCUSED,               // 🟢 状态良好，不打扰
  SLIGHTLY_DISTRACTED,   // 🟡 注意力飘走，柔光晕 + 轻提示
  DISTRACTED,            // 🔴 AI 主动询问：继续/休息/结束
  RESTING, PAUSED, QA_MODE
}
```

- 绿→黄→红由 `FocusDetectionService` 的视觉观察驱动，`FocusController` 做状态映射与事件记录（含 `source`/`confidence`）。
- 红灯的 AI 询问**给选择权，不指责、不说教、不制造焦虑**。
- **演示切换**：专注页点击呼吸灯可手动循环 绿→黄→红；`设备页 → 模拟设备模式` 也可触发。

---

## 六、数据模型（对应 PRD 第七节）

`User` / `LearningGoal` / `Task` / `FocusSession` / `FocusEvent` / `QuestionRecord` / `StudyReport` / `FocusProfile`，详见 `models/`。复杂字段（时间线、事件、建议）以 JSON 存于 RDB 的 TEXT 列。

---

## 七、页面导航

```
Index（Tabs：首页 / 工作台 / AI考伴 / 我的）
  ├── 首页「开始专注」→ 无计划则 TaskPlanning（对话式 AI 规划）
  │                          └─ 确认计划 → Focus
  ├── Focus ─ 休息 → FocusBreak
  │        └─ AI 悬浮按钮 → AIChat（答疑）→ 返回专注
  │        └─ 结束 → StudyReport（单次复盘）→ 完成 → 首页
  ├── 工作台：学习总览 / 今日任务 / 周趋势 / 学科进度 / 考试倒计时
  ├── AI 考伴：AI 对话 + 快捷提问
  └── 我的：个人专注画像(FocusProfile) / 设备(Device) / 隐私(Privacy) / 设置(Settings)
```

---

## 八、合规必备

- **专注页顶部固定**：红色摄像头指示灯 `● 摄像头感知中` + `💡 AI 智能体` 标签。
- **AI 身份透明**：所有 AI 界面固定 `💡 AI 智能体`，开场白声明「不是真人」。
- **设置页**：一键清除所有本地数据 + 二次确认弹窗（`该操作不可恢复`）。
- **隐私页**：摄像头数据「本地分析 / 不上传 / 不保存原始视频」；生理数据**分项授权**（不支持一键全部授权）。
- **无焦虑营销 / 无监控式 UI**：专注页仅任务 + 大号计时器 + 呼吸灯，红灯文案温和。

---

## 九、Mock → 真实能力替换指引

| Mock | 位置 | 替换方式 |
|---|---|---|
| Mock 盘古 | `AIService.ets` | 在 `planTasks/answerQuestion/reviewInsight` 内改调真实大模型 API |
| Mock 摄像头视觉 | `FocusDetectionService.ets` | 实现真实 `FocusSensor.getVisualState()`（头部姿态/视线/离席） |
| Mock 手表 | `SensorService.ets` | 替换为 HarmonyOS / BLE 手表数据（心率/HRV/动作） |
| 持久化 | `StorageService.ets` | 已用真实 relationalStore，无需替换 |

所有真实能力已通过 `FocusSensor` 接口与 Service 边界抽象，替换内部实现即可，UI 与业务流无需改动。

---

## 十、后续规划（Phase 2）

真实大模型 API、真实摄像头视觉检测、智能手表数据接入、HarmonyOS 多设备协同。
