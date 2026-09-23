# iKnow：模拟触发后"复盘里没有真实抓拍画面"——问题交接说明

> 转交说明：本文档描述一个 HarmonyOS（ArkTS/ArkUI）应用中的相机抓拍问题。
> 接手人只需按"第 5 节 当前卡点"往下看即可，前面是必要背景。

---

## 1. 一句话问题

**模拟控制台点「离开 / 看手机 / 一键模拟分心」后，复盘记录里始终没有真实抓拍画面，
只显示一张明确标注的"演示占位图"。** 即：应用走通了"触发 → 记录 → 状态机 → 干预 → 复盘"，
唯独**相机抓拍拿不到任何帧**（`captureBurst()` 返回空数组）。

占位图是**有意的诚实降级**（图片自身写着"演示占位图·未接摄像头"），
所以问题不是"占位图不对"，而是 **为什么采不到帧**。

---

## 2. 运行环境

| 项 | 值 |
|---|---|
| 设备 | 模拟器机（前置摄像头可用，`getSupportedCameras()` 返回 2） |
| 相机权限 | 已在 `module.json5` 声明 `ohos.permission.CAMERA`，且预览可用（能实时看到前置画面） |
| 模拟模式 | `StorageKey.SIM_MODE` 默认开启 |
| IDE | DevEco Studio（用户本机） |
| SDK | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\api\` |
| 我方可编译性 | **无**（开发环境没有 DevEco/hvigor，无法编译验证，所有改动需用户在 DevEco 里构建） |



---

## 3. 复现步骤

1. 启动应用 → 进入**专注页** → **开始一个专注会话**（关键前提：所有模拟按钮都要求
   `FocusController.isRunning() === true`，否则只会弹"模拟流程只在专注中生效"）。
2. 页面上有「模拟状态」控制台，点任一**目标状态**按钮（如「离开」「看手机」）或底部「一键模拟分心（看手机）」。
3. 进入「学习记录 / 复盘」页查看本次记录。
4. **实际结果**：记录存在、状态也变了，但「本次画面片段」区域显示的是"演示占位图"，
   记录说明文字里写着"未生成任何画面：真实抓拍未取到帧（…）"。
5. **期望结果**：应显示本次触发时刻的**真实抓拍画面**（JPEG）。

---

## 4. 涉及链路（精确到文件与函数）

### 4.1 触发链路

```
SimWorkbench.runFlow(activity)                          // components/SimWorkbench.ets
  └─ FocusController.simulateObservation(activity, 0.9) // services/FocusController.ets
       ├─ cam.probe(ctx) > 0 ?  → captureThenDeliver()  // ← 真实抓拍分支（问题就在这）
       │                            ├─ await cam.stopPreview()   // 让出相机（独占资源）
       │                            ├─ await cam.captureBurst(ctx) // ★ 返回 0 帧
       │                            └─ await cam.restartPreview(ctx)
       └─ 否则 → deliverInjected(..., placeholderFrames(ctx)) // 占位图分支
     ↓
   deliverInjected() → onObservation() → FocusDetectionService.submit()
     → FocusController.onDetection() → transitionTo() → UI 变色
     → StorageService.saveObservation() 落库
     → ObservationQueue.saveFrames() 落盘（写 imagePaths）
     ↓
   StudyReport.ets 读取该 session 的 observations，显示「本次画面片段」
```

### 4.2 关键实现位置

| 文件 | 函数 | 作用 |
|---|---|---|
| `entry/src/main/ets/services/CameraService.ets` | `captureBurst(context)` | 抓一束帧（**问题核心**） |
| 同上 | `captureOne(out, timeoutMs)` | 拍单帧并等 `photoAvailable` 回调取 JPEG |
| 同上 | `startPreview / stopPreview / restartPreview` | 预览生命周期（相机为独占资源） |
| 同上 | `probe(context)` | 探测摄像头数量 |
| `entry/src/main/ets/services/FocusController.ets` | `simulateObservation()` | 模拟注入入口（先探测硬件再决定走不走抓拍） |
| 同上 | `captureThenDeliver()` | 真实抓拍分支：停预览 → 抓拍 → 恢复预览 |
| 同上 | `placeholderFrames()` | 无帧时的 rawfile 占位图 |
| 同上 | `injectedEvidence()` | 生成复盘里的说明文字（含失败原因） |
| `entry/src/main/ets/services/ObservationQueue.ets` | `saveFrames(sessionId, frames)` | 帧落盘，返回 `imagePaths` |
| `entry/src/main/ets/pages/StudyReport.ets` | — | 复盘页，展示 `imagePaths` 或占位图 |
| `entry/src/main/ets/components/SimWorkbench.ets` | `runFlow()` / `fireVital()` | 控制台按钮入口 |

### 4.3 相关常量（`entry/src/main/ets/common/FocusTuning.ets`）

```
BURST_FRAME_COUNT     = 6       // 每次触发最多抓 6 帧
BURST_TIMEOUT_MS      = 3500    // 原总预算
BURST_WIDTH           = 640     // 目标分辨率宽度
KEEP_FRAMES_PER_OBS   = 2       // 本地只保留 2 张
CONFIDENCE_FLOOR      = 50      // 状态机置信度门禁（0~100）
SIM_INJECT_CONFIDENCE = 0.9     // 模拟注入置信度
MAX_TRIGGER_PER_SESSION = 20    // 触发配额
MAX_QUEUE_PER_SESSION   = 20    // 队列配额
```

---

## 5. 当前卡点（接手人从这里开始）

### 5.1 已确认的事实（有证据）

1. **触发链路是通的**：复盘里能看到记录、状态会变色、`evidence` 文案会更新。
   所以"事件 → 记录 → 状态机 → 落库 → 复盘"这一段没问题。
2. **失败发生在抓拍这一段**：`evidence` 明确写着
   `未生成任何画面：真实抓拍未取到帧（…）`，即 `CameraService.captureBurst()` 返回了空数组。
3. **不是权限问题**：`probe()` 能返回 2，且页面能看到实时前置预览。
4. **不是"没走到抓拍"**：日志/文案显示确实进入了 `captureThenDeliver()` 分支。

### 5.2 待验证假设（按可能性排序）

**假设 A（最可能）：`photoAvailable` 回调根本没触发。**
`PhotoOutput.capture()` 的 promise 成功返回，但 `on('photoAvailable')` 不回调，
于是每帧都靠超时返回 null，整束 0 帧。常见诱因：session 结构不完整（缺 `PreviewOutput`）、
相机刚 `stopPreview()` 释放后硬件尚未就绪、或 `SceneMode` 与 profile 不匹配。

**假设 B：回调触发了，但 `getComponent(JPEG)` 失败。**
`photo.main` 的实际编码不是 JPEG（可能是 YUV/RGBA），
`img.getComponent(image.ComponentType.JPEG)` reject → 取不到 `byteBuffer`。
**这是最容易判定的一条**：代码已把 `img.format` 打进日志，
对照 `ComponentType` 枚举（`YUV_Y=1, YUV_U=2, YUV_V=3, JPEG=4`）即可确认。

**假设 C：`captureThenDeliver` 里 `stopPreview()` 后，surface 失效导致 `PreviewOutput` 建不起来。**
`captureBurst()` 会复用 `CameraService.lastSurfaceId`（Focus 页 `XComponent` 的 surface）来配置
`PreviewOutput`。若该 surface 在 `stopPreview()` 后已不可用，`createPreviewOutput` 抛错被 catch，
于是 session 里只剩 `PhotoOutput` —— 又回到假设 A 的诱因。

**假设 D：预览与抓拍对相机的竞争。**
`stopPreview()` 虽然 `await` 了 `session.stop()/release()`，但硬件释放可能有延迟，
紧接着新建 session 会失败或静默不回调。

### 5.3 建议的第一步：先用"最小对照实验"定位责任方

**在动手改项目之前**，建议先做一个独立验证：

> 用 HarmonyOS **官方 Camera 示例代码**（`NORMAL_PHOTO` + `PhotoOutput` + `photoAvailable` +
> `getComponent(JPEG)`）在**同一台设备**上跑一遍，看能否拍出 JPEG。

- 官方 demo **能**出图 → 问题在本项目代码（重点查 session 配置、预览/抓拍切换、timeout）。
- 官方 demo **也出不来** → 问题在设备/SDK 对该相机路径的支持，需要改方案
  （例如改用 `ImageReceiver` 直接接预览流并自行编码，而不是 `PhotoOutput`）。

**这一步能一次性砍掉一半可能性，强烈建议先做。**

---

## 6. 已埋好的诊断点位（怎么看）

### 6.1 界面上的诊断（最方便）

`FocusController.lastCaptureDiag` 会在每次模拟注入后更新，`SimWorkbench` 控制台
在「本会话配额」下面直接显示：

```
上次抓拍：真实抓拍成功：3 张
上次抓拍：真实抓拍失败：真实抓拍未取到帧（capture 6 次均未取到帧（会话：含 preview output，
          模式 NORMAL_PHOTO，分辨率 640x480，末次原因：等待 photoAvailable 超时（3000ms）））
上次抓拍：未进入真实抓拍：未探测到可用摄像头（getSupportedCameras 返回 0）
```

### 6.2 复盘记录里的说明文字

每条注入记录的 `evidence` 以 **`[v9]`** 开头（版本标记，用于确认设备跑的是新代码）；
后半段会带具体失败原因。**如果看不到 `[v9]`，说明构建没更新，不是代码问题。**

### 6.3 hilog 关键字

| TAG | 关键字 |
|---|---|
| `iKnow.Camera` | `burst caps(photo)` / `burst 选用拍照分辨率` / `burst 会话已启动` / `burst 采集 N 帧` / `photoAvailable：size=.. format=..` / `getComponent(JPEG) 失败` / `等待 photoAvailable 超时` |
| `iKnow.Focus` | `[模拟注入] 摄像头探测：ctx=.. cameras=.. previewRunning=.. permCamera=..` / `[模拟注入] 真实抓拍成功/失败` |

**最关键的三个值**：① `photoAvailable` 是否打印过；② 打印时 `format` 是多少；
③ 结束时的 `burst 采集 N 帧，capture M 次`。

---

## 7. 已经做过的改动（避免接手人重复走弯路）

以下是历次排查中已修复/已尝试的内容。**这些都不要再"重新发现"一遍。**

| # | 问题 | 处理 | 结论 |
|---|---|---|---|
| 1 | `SimWorkbench.runFlow` 调了 `simulateFlow`（走 `injectTrigger`，需要真机+网关，还会被 dwell 去抖吞掉） | 改为调 `simulateObservation`（直接注入识别结果，绕过相机与去抖） | ✅ 有效：页面能变色、复盘有记录 |
| 2 | `FocusController.triggerVisualCheck` 首行 `if (!PermissionService...camera) return` 把整条链路静默拦死 | 放开硬卡口，改为按有无硬件决定抓拍或降级 | ✅ 有效 |
| 3 | 注入记录 `confidence` 为 0，被状态机 `CONFIDENCE_FLOOR(50)` 拦下 → 页面不变色 | 注入路径加 confidence 兜底（0/undefined/null → 0.9） | ✅ 有效 |
| 4 | 占位图放在 `rawfile`，增量构建常漏打包 | 同时放 `resources/base/media/sim_placeholder.png`，UI 层用 `$r('app.media.sim_placeholder')` 兜底 | ✅ 有效（图能显示了） |
| 5 | `captureBurst` 只配置 `PhotoOutput`，session 结构可能不完整 | 若 `lastSurfaceId` 非空，额外配置 `PreviewOutput`；`session.start()` 后 warmup 350~500ms | ⚠️ 未解决 |
| 6 | 单帧超时仅 `3500/6≈583ms`，真机首帧等不到 AE/AF | 改为**首帧 3000ms、后续 1200ms**，总预算 `max(3500, 6000)` | ⚠️ 未解决 |
| 7 | `capture()` 无参调用，部分设备不触发回调 | 显式传 `PhotoCaptureSetting{quality, rotation}` | ⚠️ 未解决 |
| 8 | 曾误用 `image.Image.createPixelMap()` | **本 SDK 的 `image.Image` 没有这个方法**，编译报错。已回退到 `getComponent(JPEG)` | ❌ 已撤销（勿再尝试） |

> **第 8 条特别提醒**：`image.Image` 接口只有
> `clipRect / size / format / timestamp / getComponent(type) / release()`，
> **没有 `createPixelMap`、没有 `readPixels`**。取 JPEG 只能走
> `photo.main.getComponent(image.ComponentType.JPEG)` → `comp.byteBuffer`。
> 如需把非 JPEG 数据转成 JPEG，得先拿到 `PixelMap`，而这条路在当前接口下不存在——
> 这是**假设 B 成立时最麻烦的地方**，需要换方案（见 5.3）。

---

## 8. 建议的排查动作清单

1. **先做 5.3 的最小对照实验**（官方 demo 同设备能否拍出 JPEG）。
2. 若 demo 通过，在 `captureOne()` 里补一行 `hilog` 确认 `photoAvailable` 是否触发：
   - **不触发** → 专注查 session 配置：`SceneMode`、`photoProfiles` 是否来自同一 `SceneMode`、
     是否需要在 `capture()` 前等待预览首帧、是否必须保留 `PreviewOutput`。
   - **触发但 format ≠ 4** → 假设 B，需要换取帧方案。
3. 若怀疑假设 C：把 `captureThenDeliver` 的"先停预览再抓拍"改为
   **抓拍期间不释放 `PreviewOutput`**（例如复用同一个 surface 重建完整 session），
   或在 `stopPreview()` 后加一段显式延时再新建 session。
4. 若怀疑假设 D：在 `stopPreview()` 与 `captureBurst()` 之间加 200~300ms 延时试。
5. 每次验证**必须 Clean Project**，并确认复盘 `evidence` 带 `[v9]`（或更新版本号）。

---

## 9. 参考：当前 `captureBurst` 的核心逻辑（节选）

```ts
// CameraService.captureBurst()
const mgr = camera.getCameraManager(context)
const devices = mgr.getSupportedCameras()          // 真机返回 2
// 优先前置
let mode: camera.SceneMode = camera.SceneMode.NORMAL_PHOTO
let caps = mgr.getSupportedOutputCapability(target, mode)
if (caps.photoProfiles.length === 0) {             // 部分设备此处为空
  mode = camera.SceneMode.NORMAL_VIDEO
  caps = mgr.getSupportedOutputCapability(target, mode)
}
const out = mgr.createPhotoOutput(this.pickPhotoProfile(caps.photoProfiles))
const s = mgr.createSession<camera.Session>(mode)
s.beginConfig()
s.addInput(camInput)
s.addOutput(out)
// 若 lastSurfaceId 非空，再 add 一个 PreviewOutput（假设 A 的对策）
if (this.lastSurfaceId.length > 0 && caps.previewProfiles.length > 0) {
  previewOut = mgr.createPreviewOutput(this.pickProfile(caps.previewProfiles), this.lastSurfaceId)
  s.addOutput(previewOut)
}
await s.commitConfig()
await s.start()
await this.delay(hasPreview ? 500 : 350)          // warmup
for (let i = 0; i < 6; i++) {
  if (Date.now() - started >= Math.max(3500, 6000)) break
  const buf = await this.captureOne(out, i === 0 ? 3000 : 1200)
  if (buf) frames.push(buf)
}
```

```ts
// CameraService.captureOne()
out.on('photoAvailable', (err, photo) => {
  const img = photo.main
  hilog.info(TAG, 'photoAvailable：size=%s format=%d', `${img.size.width}x${img.size.height}`, img.format)
  img.getComponent(image.ComponentType.JPEG)
     .then(comp => finish(comp.byteBuffer))        // 成功路径
     .catch(e => { /* 记录 code + img.format */ finish(null) })
})
out.capture({ quality: camera.QualityLevel.QUALITY_LEVEL_MEDIUM,
              rotation: camera.ImageRotation.ROTATION_0 })
  .catch(e => finish(null))
```

---

## 10. 一句话给接手人

> 链路、状态机、落库、复盘都已验证正常，**唯一断点是 `CameraService.captureBurst()` 拿不到帧**。
> 先用官方 demo 在同一台设备上验证 `PhotoOutput` 能否出图，就能立刻区分
> "项目代码问题"还是"设备/方案问题"；关键要看 `photoAvailable` 有没有回调、回调时 `img.format` 是多少。
