import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { FocusTuning } from '../common/FocusTuning'

const DOMAIN = 0x0000
const TAG = 'iKnow.Camera'

/**
 * 前置摄像头：本机预览 + 触发式抓拍（诚实降级）
 *
 *  - `startPreview()` 建起"预览 + 拍照"的会话（`PhotoOutput` 与预览同会话）；
 *    `captureBurst()` 在信号触发时**在这个会话上**抓拍一束短片段，帧交给 `ObservationQueue`
 *    （落盘保存 + 送云端做「在做什么」识别）。UI 涉及数据流向的文案必须与此一致。
 *  - 任何一步失败（无权限 / 模拟器无可用摄像头 / 会话被占用）都返回 false，
 *    由页面降级为「未接入摄像头」，**绝不假装感知中**。
 *  - 相机会话是独占资源：离开页面必须 `stopPreview()`，否则切到答疑页会启动失败。
 */
export class CameraService {
  /**
   * 预览/采集的画面比例（4:3）。
   * `XComponent` 的 Surface **不会**按比例适配：给它的框比例和设备分辨率不一致，
   * 画面就是被拉扁的。页面用它设预览框比例，这里用它挑分辨率，两边保持同一口径。
   */
  static readonly PREVIEW_ASPECT = 4 / 3
  private static inst: CameraService | null = null
  private session: camera.Session | null = null
  private input: camera.CameraInput | null = null
  private preview: camera.PreviewOutput | null = null
  /**
   * 与预览同会话的拍照输出。信号触发时直接在**正在跑的会话**上 `capture()`，
   * 不必停预览、也不必重建会话（重建会让页面预览留下卡住的残影，且监听注册时机必然错误）。
   */
  private photo: camera.PhotoOutput | null = null
  /** 当前拍照档位（写进抓拍失败原因，便于在复盘 / 控制台上直接看到） */
  private photoSize: string = ''
  private running: boolean = false
  private lastError: string = ''
  /**
   * "正在等这一帧"的在途请求。`photoAvailable` 的监听是**常驻**的（随拍照输出一起建、一起放），
   * 结果统一从这里交回给等待中的 `captureOne()`。
   */
  private awaitPhoto: ((b: ArrayBuffer | null) => void) | null = null
  private awaitTimer: number = -1
  /** 抓拍重入保护：演示控制台连点时会同时发起两次，一次只能有一个在途请求 */
  private capturing: boolean = false

  static getInstance(): CameraService {
    if (CameraService.inst === null) {
      CameraService.inst = new CameraService()
    }
    return CameraService.inst
  }

  isRunning(): boolean {
    return this.running
  }

  /** 从设备支持的分辨率里挑一个最接近 4:3 的（都不可用时退回第一个） */
  private pickProfile(profiles: camera.Profile[]): camera.Profile {
    let best: camera.Profile = profiles[0]
    let bestDiff = Number.MAX_VALUE
    for (const p of profiles) {
      if (p.size.width <= 0 || p.size.height <= 0) {
        continue
      }
      const diff = Math.abs(p.size.width / p.size.height - CameraService.PREVIEW_ASPECT)
      if (diff < bestDiff) {
        bestDiff = diff
        best = p
      }
    }
    return best
  }

  getLastError(): string {
    return this.lastError
  }

  /**
   * 探测本机是否有可用摄像头（不开始预览）。
   * 关键：**不能**用"本地授权标记"来决定要不要探测——否则未授权时永远测不出硬件是否存在。
   * 返回摄像头数量；失败时返回 0 并把错误码/原因写入 lastError。
   */
  probe(context: common.Context): number {
    try {
      const mgr = camera.getCameraManager(context)
      const devices = mgr.getSupportedCameras()
      this.lastError = ''
      hilog.info(DOMAIN, TAG, 'probe ok, cameras=%{public}d', devices.length)
      return devices.length
    } catch (err) {
      const e = err as BusinessError
      this.lastError = `探测失败 ${e.code}: ${e.message}`
      hilog.error(DOMAIN, TAG, 'probe failed code=%{public}d msg=%{public}s', e.code, e.message)
      return 0
    }
  }

  /**
   * 尝试开启前置预览；返回是否成功（失败原因见 getLastError）。
   *
   * 预览会话里**同时挂一个 `PhotoOutput`**（官方拍照示例的组合：预览 + 拍照同会话），
   * 于是信号触发时可以直接在这个会话上 `capture()`：预览不中断、不必停相机再重建会话。
   * 这样做的另一个必要原因是时序 —— `photoAvailable` 监听**必须在配置会话之前注册**，
   * 而"每次抓拍另开会话"的写法只能在 `start()` 之后才注册，底层不会把照片回调给它。
   */
  async startPreview(context: common.Context, surfaceId: string): Promise<boolean> {
    if (this.running) {
      return true
    }
    // 相机会话是独占资源：重复进入时 surface 可能已变化，先释放上一次（必须等它释放完）
    await this.stopPreview()
    if (surfaceId.length === 0) {
      this.lastError = '预览 surface 未就绪'
      return false
    }
    try {
      const mgr = camera.getCameraManager(context)
      const devices = mgr.getSupportedCameras()
      if (devices.length === 0) {
        this.lastError = '未找到可用摄像头'
        return false
      }
      let target: camera.CameraDevice = devices[0]
      for (const d of devices) {
        if (d.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
          target = d
          break
        }
      }

      const input = mgr.createCameraInput(target)
      this.input = input
      await input.open()

      // 会话模式：优先 `NORMAL_PHOTO` —— 它同时给出预览档位与拍照档位，是"预览 + 拍照"的标准组合。
      // 该模式下没有预览档位时退回 `NORMAL_VIDEO`（只能预览，抓拍由降级路径兜底）。
      let mode: camera.SceneMode = camera.SceneMode.NORMAL_PHOTO
      let caps = mgr.getSupportedOutputCapability(target, mode)
      let hasPhoto: boolean = caps.photoProfiles.length > 0
      if (caps.previewProfiles.length === 0) {
        mode = camera.SceneMode.NORMAL_VIDEO
        caps = mgr.getSupportedOutputCapability(target, mode)
        hasPhoto = false
        hilog.warn(DOMAIN, TAG, 'NORMAL_PHOTO 无预览档位，退回 NORMAL_VIDEO（仅预览，不抓拍）')
      }
      if (caps.previewProfiles.length === 0) {
        this.lastError = '无可用预览分辨率'
        await input.close()
        this.input = null
        return false
      }
      const preview = mgr.createPreviewOutput(this.pickProfile(caps.previewProfiles), surfaceId)
      this.preview = preview

      let photo: camera.PhotoOutput | null = null
      if (hasPhoto) {
        const photoProfile = this.pickPhotoProfile(caps.photoProfiles)
        photo = mgr.createPhotoOutput(photoProfile)
        this.photo = photo
        this.photoSize = `${photoProfile.size.width}x${photoProfile.size.height}`
        this.awaitPhoto = null
        this.awaitTimer = -1
        // **必须在 addOutput / commitConfig 之前注册**：官方时序是"创建输出流时就注册
        // photoAvailable 监听"。会话启动之后再注册是收不到任何回调的。
        photo.on('photoAvailable', (err: BusinessError, p: camera.Photo) => {
          this.onPhotoAvailable(err, p)
        })
      } else {
        hilog.warn(DOMAIN, TAG, '本机不给拍照档位，预览可用但抓拍不可用（复盘会走占位图）')
      }

      const session = mgr.createSession<camera.Session>(mode)
      session.beginConfig()
      session.addInput(input)
      session.addOutput(preview)
      if (photo !== null) {
        session.addOutput(photo)
      }
      await session.commitConfig()
      await session.start()

      this.session = session
      this.running = true
      this.lastError = ''
      hilog.info(DOMAIN, TAG, 'preview started（%{public}s，拍照%s）',
        mode === camera.SceneMode.NORMAL_PHOTO ? 'NORMAL_PHOTO' : 'NORMAL_VIDEO',
        photo !== null ? '已挂载' : '不可用')
      return true
    } catch (err) {
      const e = err as BusinessError
      // 错误码与原因都保留，方便在界面上直接看到、便于真机早调
      this.lastError = `不可用 ${e.code}: ${e.message}`
      hilog.error(DOMAIN, TAG, 'preview failed code=%{public}d msg=%{public}s', e.code, e.message)
      await this.stopPreview()
      return false
    }
  }

  /**
   * 停止预览并**等相机真正释放完**再返回。
   *
   * 相机是独占资源，且 `PhotoOutput` 与预览同属一个会话：这里必须一起释放，
   * 否则下次进页面 `startPreview()` 会报被占用。调用方不关心返回值时可以照旧不 await。
   */
  async stopPreview(): Promise<void> {
    try {
      if (this.session !== null) {
        await this.session.stop()
        await this.session.release()
      }
    } catch (e) {
      // 释放失败忽略：不影响页面降级
    }
    try {
      if (this.photo !== null) {
        await this.photo.release()
      }
    } catch (e) {
      // 忽略
    }
    try {
      if (this.preview !== null) {
        await this.preview.release()
      }
    } catch (e) {
      // 忽略
    }
    try {
      if (this.input !== null) {
        await this.input.close()
      }
    } catch (e) {
      // 忽略
    }
    this.session = null
    this.photo = null
    this.preview = null
    this.input = null
    this.running = false
    // 丢掉在途请求：此后回来的帧按"迟到帧"处理
    this.awaitPhoto = null
    if (this.awaitTimer !== -1) {
      clearTimeout(this.awaitTimer)
      this.awaitTimer = -1
    }
  }

  /**
   * 触发式短片段采集：在**已经在跑的预览会话**上连拍若干帧 JPEG。
   *
   * **用 `PhotoOutput` 拍照**（鸿蒙里取 JPEG 的正路）：`PhotoOutput` 由 `startPreview()`
   * 连同预览一起建好、`photoAvailable` 监听也已在配置会话之前注册，这里只负责逐次
   * `capture()` 并从回调里取 `photo.main` 的 JPEG 分量。
   *
   * 为什么不再"停预览 → 新建会话 → 恢复预览"：
   *  ① 相机是独占资源，来回拆装会让页面预览留下卡住的残影（点一次分心，预览就糊住）；
   *  ② 会话 `start()` 之后再注册 `photoAvailable` 收不到任何回调（官方时序要求在配置
   *     会话之前注册），所以旧写法下 `capture()` 永远等不到照片、整束 0 帧；
   *  ③ 在跑着的会话上拍照本来就是相机应用的标准做法，抓到的也正是触发那一刻的画面。
   *
   * 失败或超时都不抛：返回已采到的部分；`getLastError()` 给出卡在哪一步。
   */
  async captureBurst(): Promise<ArrayBuffer[]> {
    const frames: ArrayBuffer[] = []
    const started = Date.now()
    const out = this.photo
    if (!this.running || out === null) {
      this.lastError = this.running
        ? '本机不支持「预览 + 拍照」同会话，无法抓拍'
        : '预览未运行，无法抓拍'
      hilog.warn(DOMAIN, TAG, 'burst 跳过：%{public}s', this.lastError)
      return frames
    }
    if (this.capturing) {
      this.lastError = '上一次抓拍尚未结束，本次跳过'
      hilog.warn(DOMAIN, TAG, 'burst 跳过：上一次抓拍尚未结束')
      return frames
    }
    this.capturing = true
    let attempts = 0
    let lastFrameError = ''
    try {
      // 首帧 3s（等 AE/AF 收敛），后续 1.2s（已在工作状态，出图快）。
      // 总预算取一个不低于 6s 的下限，避免首帧吃掉全部配额后一帧都拿不到。
      const totalBudget = Math.max(FocusTuning.BURST_TIMEOUT_MS, 6000)
      for (let i = 0; i < FocusTuning.BURST_FRAME_COUNT; i++) {
        if (Date.now() - started >= totalBudget) {
          break
        }
        attempts += 1
        const buf = await this.captureOne(out, i === 0 ? 3000 : 1200)
        if (buf !== null && buf.byteLength > 0) {
          frames.push(buf)
        } else {
          lastFrameError = this.lastError
        }
      }
      hilog.info(DOMAIN, TAG, 'burst 采集 %{public}d 帧，capture %{public}d 次，耗时 %{public}d ms',
        frames.length, attempts, Date.now() - started)
      if (frames.length === 0) {
        // 0 帧时把**卡在哪一步**写进 lastError，复盘里直接可见，不用翻 hilog
        this.lastError = `capture ${attempts} 次均未取到帧（预览会话内拍照，分辨率 ${this.photoSize}` +
          `${lastFrameError.length > 0 ? '，末次原因：' + lastFrameError : ''}）`
      }
    } finally {
      // 丢掉在途请求：此后回来的帧按"迟到帧"处理
      this.capturing = false
      this.awaitPhoto = null
      if (this.awaitTimer !== -1) {
        clearTimeout(this.awaitTimer)
        this.awaitTimer = -1
      }
    }
    return frames
  }

  /**
   * 拍照分辨率：取**最接近 `BURST_WIDTH` 的那一档**（上传体积与端到端时延都可控），
   * 设备没有这一档时按宽度差取最近的。
   */
  private pickPhotoProfile(profiles: camera.Profile[]): camera.Profile {
    let best: camera.Profile = profiles[0]
    let bestDiff = Number.MAX_VALUE
    for (const p of profiles) {
      if (p.size.width <= 0 || p.size.height <= 0) {
        continue
      }
      const diff = Math.abs(p.size.width - FocusTuning.BURST_WIDTH)
      if (diff < bestDiff) {
        bestDiff = diff
        best = p
      }
    }
    return best
  }

  /**
   * 发起一次 `capture()` 并等这一帧的 JPEG。超时或出错返回 null（**不抛**）。
   *
   * 监听**不在这里注册**：它由 `startPreview()` 在建好 `PhotoOutput` 之后、配置会话之前
   * 一次性注册，这里只把自己登记为"当前在途请求"，结果由 `onPhotoAvailable` 路由回来。
   */
  private captureOne(out: camera.PhotoOutput, timeoutMs: number): Promise<ArrayBuffer | null> {
    return new Promise<ArrayBuffer | null>((resolve: (b: ArrayBuffer | null) => void) => {
      this.awaitPhoto = (b: ArrayBuffer | null): void => {
        resolve(b)
      }
      // 单帧超时：首帧要等 AE/AF 收敛 + 传感器出图，真机上常需 2~3 秒；
      // 原先 583ms（3500/6）几乎必然等不到回调 → 整束 0 帧 → 复盘只剩占位图。
      this.awaitTimer = setTimeout(() => {
        this.lastError = `等待 photoAvailable 超时（${timeoutMs}ms）`
        this.settlePhoto(null)
      }, timeoutMs)
      // 显式给出拍照参数：部分设备在无参 `capture()` 下不触发 `photoAvailable`。
      const setting: camera.PhotoCaptureSetting = {
        quality: camera.QualityLevel.QUALITY_LEVEL_MEDIUM,
        rotation: camera.ImageRotation.ROTATION_0
      }
      out.capture(setting).catch((e: BusinessError) => {
        this.lastError = `拍照失败 ${e.code}: ${e.message}`
        hilog.error(DOMAIN, TAG, 'capture 调用失败 code=%{public}d msg=%{public}s', e.code, e.message)
        this.settlePhoto(null)
      })
    })
  }

  /**
   * `photoAvailable` 的统一处理：把这一帧交给当前在途的 capture，并取 JPEG 分量。
   *
   * 这里**不能**调用 `off()` —— 官方明确说明不可以在 `on()` 的回调里注销监听。
   * 监听随 `PhotoOutput` 一起建、一起随 `stopPreview()` 释放，不存在监听堆积。
   */
  private onPhotoAvailable(err: BusinessError, photo: camera.Photo): void {
    if (this.awaitPhoto === null) {
      // 迟到的帧（发起它的那次 capture 已经超时收场）：丢掉，不占着 buffer
      if (photo !== undefined && photo !== null) {
        photo.release()
      }
      return
    }
    if (err || photo === undefined || photo === null) {
      this.lastError = `photoAvailable 回调异常 ${err ? err.code : 'null'}`
      this.settlePhoto(null)
      return
    }
    const img: image.Image = photo.main
    // 取 JPEG 分量。注意：本 SDK 的 `image.Image` **没有** `createPixelMap`/`readPixels`，
    // 只有 `getComponent(type)` —— 所以这里是唯一可行的取帧路径（`PhotoOutput`
    // 默认输出 JPEG，正常情况下应能直接取到）。取不到时把真实尺寸与 format 记进 lastError，
    // 便于判断是"设备给的不是 JPEG"还是"取帧本身失败"。
    const imgSize: string = `${img.size.width}x${img.size.height}`
    const imgFormat: number = img.format
    hilog.info(DOMAIN, TAG, 'photoAvailable：size=%{public}s format=%{public}d',
      imgSize, imgFormat)
    img.getComponent(image.ComponentType.JPEG).then((comp: image.Component) => {
      const buf: ArrayBuffer = comp.byteBuffer
      if (buf === undefined || buf.byteLength === 0) {
        this.lastError = `JPEG 分量为空（${imgSize} format=${imgFormat}）`
        hilog.error(DOMAIN, TAG, 'JPEG 分量存在但为空：%{public}s', this.lastError)
        photo.release()
        img.release()
        this.settlePhoto(null)
        return
      }
      photo.release()
      img.release()
      this.settlePhoto(buf)
    }).catch((e: BusinessError) => {
      // 拿不到 JPEG：把尺寸与真实 format 一起记下，区分"设备返回非 JPEG"与"调用失败"
      this.lastError = `取 JPEG 分量失败 code=${e.code}（${imgSize} format=${imgFormat}）`
      hilog.error(DOMAIN, TAG,
        'getComponent(JPEG) 失败 code=%{public}d msg=%{public}s size=%{public}s format=%{public}d',
        e.code, e.message, imgSize, imgFormat)
      photo.release()
      img.release()
      this.settlePhoto(null)
    })
  }

  /** 结算当前在途请求：清掉超时定时器并把结果交回等待方（同一帧只结算一次） */
  private settlePhoto(b: ArrayBuffer | null): void {
    const deliver = this.awaitPhoto
    if (deliver === null) {
      return
    }
    this.awaitPhoto = null
    if (this.awaitTimer !== -1) {
      clearTimeout(this.awaitTimer)
      this.awaitTimer = -1
    }
    deliver(b)
  }
}
