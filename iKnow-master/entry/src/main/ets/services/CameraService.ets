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
 *  - `startPreview()` 只做本机实时渲染的预览；
 *    `captureBurst()` 在手表信号触发时抓拍一束短片段，帧交给 `ObservationQueue`
 *    （落盘保存 + 送云端做「在做什么」识别）。UI 涉及数据流向的文案必须与此一致。
 *  - 任何一步失败（无权限 / 模拟器无可用摄像头 / 会话被占用）都返回 false，
 *    由页面降级为「未接入摄像头」，**绝不假装感知中**。
 *  - 相机会话是独占资源：离开页面必须 `stopPreview()`，否则切到答疑页会启动失败。
 */
export class CameraService {
  private static inst: CameraService | null = null
  private session: camera.Session | null = null
  private input: camera.CameraInput | null = null
  private preview: camera.PreviewOutput | null = null
  private running: boolean = false
  private lastError: string = ''

  static getInstance(): CameraService {
    if (CameraService.inst === null) {
      CameraService.inst = new CameraService()
    }
    return CameraService.inst
  }

  isRunning(): boolean {
    return this.running
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

  /** 尝试开启前置预览；返回是否成功（失败原因见 getLastError） */
  async startPreview(context: common.Context, surfaceId: string): Promise<boolean> {
    if (this.running) {
      return true
    }
    // 相机会话是独占资源：重复进入时 surface 可能已变化，先释放上一次
    this.stopPreview()
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
      await input.open()
      const caps = mgr.getSupportedOutputCapability(target, camera.SceneMode.NORMAL_VIDEO)
      if (caps.previewProfiles.length === 0) {
        this.lastError = '无可用预览分辨率'
        await input.close()
        return false
      }
      const preview = mgr.createPreviewOutput(caps.previewProfiles[0], surfaceId)

      const session = mgr.createSession<camera.Session>(camera.SceneMode.NORMAL_VIDEO)
      session.beginConfig()
      session.addInput(input)
      session.addOutput(preview)
      await session.commitConfig()
      await session.start()

      this.session = session
      this.input = input
      this.preview = preview
      this.running = true
      this.lastError = ''
      hilog.info(DOMAIN, TAG, 'preview started')
      return true
    } catch (err) {
      const e = err as BusinessError
      // 错误码与原因都保留，方便在界面上直接看到、便于真机早调
      this.lastError = `不可用 ${e.code}: ${e.message}`
      hilog.error(DOMAIN, TAG, 'preview failed code=%{public}d msg=%{public}s', e.code, e.message)
      this.stopPreview()
      return false
    }
  }

  stopPreview(): void {
    try {
      if (this.session !== null) {
        this.session.stop().catch(() => {
        })
        this.session.release().catch(() => {
        })
      }
    } catch (e) {
      // 释放失败忽略：不影响页面降级
    }
    try {
      if (this.input !== null) {
        this.input.close().catch(() => {
        })
      }
    } catch (e) {
      // 忽略
    }
    try {
      if (this.preview !== null) {
        this.preview.release().catch(() => {
        })
      }
    } catch (e) {
      // 忽略
    }
    this.session = null
    this.input = null
    this.preview = null
    this.running = false
  }

  /**
   * 触发式短片段采集：取若干帧 JPEG（参数已锁定，保证端到端时延可预测）。
   *
   * 链路：ImageReceiver 拿 surfaceId → 交给预览输出 → imageArrival 事件里取帧。
   * 相机会话是独占资源，**采完立即释放**（用 finally 保证）。
   * 失败或超时不会抛出：返回已采到的部分（可能是空数组），由上层决定降级。
   */
  async captureBurst(context: common.Context): Promise<ArrayBuffer[]> {
    const frames: ArrayBuffer[] = []
    const started = Date.now()
    let receiver: image.ImageReceiver | null = null
    let session: camera.Session | null = null
    let input: camera.CameraInput | null = null
    let preview: camera.PreviewOutput | null = null
    try {
      const rec = image.createImageReceiver(
        FocusTuning.BURST_WIDTH, FocusTuning.BURST_HEIGHT,
        image.ImageFormat.JPEG, FocusTuning.BURST_FRAME_COUNT)
      receiver = rec
      const surfaceId: string = await rec.getReceivingSurfaceId()

      const mgr = camera.getCameraManager(context)
      const devices = mgr.getSupportedCameras()
      if (devices.length === 0) {
        this.lastError = '无可用摄像头'
        return frames
      }
      let target: camera.CameraDevice = devices[0]
      for (const d of devices) {
        if (d.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
          target = d
          break
        }
      }
      const camInput = mgr.createCameraInput(target)
      input = camInput
      await camInput.open()
      const caps = mgr.getSupportedOutputCapability(target, camera.SceneMode.NORMAL_VIDEO)
      if (caps.previewProfiles.length === 0) {
        this.lastError = '无可用预览分辨率'
        return frames
      }
      const camPreview = mgr.createPreviewOutput(caps.previewProfiles[0], surfaceId)
      preview = camPreview
      const s = mgr.createSession<camera.Session>(camera.SceneMode.NORMAL_VIDEO)
      session = s
      s.beginConfig()
      s.addInput(camInput)
      s.addOutput(camPreview)
      await s.commitConfig()
      await s.start()

      await this.collectFrames(rec, frames, FocusTuning.BURST_TIMEOUT_MS)
      hilog.info(DOMAIN, TAG, 'burst 采集 %{public}d 帧，耗时 %{public}d ms',
        frames.length, Date.now() - started)
    } catch (err) {
      const e = err as BusinessError
      this.lastError = `采集失败 ${e.code}: ${e.message}`
      hilog.error(DOMAIN, TAG, 'burst 失败 code=%{public}d', e.code)
    } finally {
      await this.releaseBurst(session, input, preview, receiver)
    }
    return frames
  }

  /** 等帧：采满或超时即返回 */
  private collectFrames(rec: image.ImageReceiver, frames: ArrayBuffer[], timeoutMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      let done = false
      const finish = (): void => {
        if (!done) {
          done = true
          resolve()
        }
      }
      const timer = setTimeout(finish, timeoutMs)
      rec.on('imageArrival', () => {
        rec.readNextImage().then((img: image.Image) => {
          img.getComponent(image.ComponentType.JPEG).then((comp: image.Component) => {
            const buf: ArrayBuffer = comp.byteBuffer
            if (buf.byteLength > 0 && buf.byteLength <= FocusTuning.BURST_MAX_FRAME_BYTES) {
              frames.push(buf)
            }
            img.release()
            if (frames.length >= FocusTuning.BURST_FRAME_COUNT) {
              clearTimeout(timer)
              finish()
            }
          }).catch(() => {
            img.release()
          })
        }).catch(() => {
          // 单帧读取失败：跳过，等下一帧或超时
        })
      })
    })
  }

  private async releaseBurst(session: camera.Session | null, input: camera.CameraInput | null,
                             preview: camera.PreviewOutput | null,
                             receiver: image.ImageReceiver | null): Promise<void> {
    if (session !== null) {
      await session.stop().catch(() => {})
      await session.release().catch(() => {})
    }
    if (input !== null) {
      await input.close().catch(() => {})
    }
    if (preview !== null) {
      await preview.release().catch(() => {})
    }
    if (receiver !== null) {
      await receiver.release().catch(() => {})
    }
  }
}
