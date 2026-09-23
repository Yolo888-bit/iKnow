import { hilog } from '@kit.PerformanceAnalysisKit'
import { fileIo } from '@kit.CoreFileKit'
import { ObservationRecord, WatchEvent } from '../models/WatchSignal'
import { FocusTuning } from '../common/FocusTuning'
import { IdUtils } from '../utils/IdUtils'
import { StorageService } from './StorageService'

const DOMAIN = 0x0000
const TAG = 'iKnow.Observation'

/**
 * 画面识别器接口 —— 由网关实现（多模态调用）。
 * 返回 null 表示"这次没拿到结论"（未配置/失败/超时），
 * 此时我们**如实记录为"无法判断"**，绝不编造 activity。
 */
export interface FrameRecognizer {
  recognize(frames: ArrayBuffer[]): Promise<ObservationRecord | null>
}

interface QueueTask {
  sessionId: string
  event: WatchEvent
  frames: ArrayBuffer[]
}

/**
 * 观察队列 —— **异步串行**，不阻塞专注计时。
 *
 * 触发式采集完成后，主流程立刻返回；这里负责：
 *   1. 把帧落盘到会话目录（决策：上传并保存供复盘）
 *   2. 串行调用识别器（避免并发打爆模型配额）
 *   3. 失败重试 1 次后放弃，并把"无法判断"如实入库
 *   4. 把结果回调给上层做规则组合
 *
 * 未配置 Key / 无摄像头时不会报错崩流程，只会得到"无法判断"的记录。
 */
export class ObservationQueue {
  private static inst: ObservationQueue | null = null
  private tasks: QueueTask[] = []
  private consuming: boolean = false
  private recognizer: FrameRecognizer | null = null
  private onObservation: ((o: ObservationRecord) => void) | null = null
  /** 单会话入队计数（防异常堆积） */
  private enqueuedBySession: Map<string, number> = new Map<string, number>()

  static getInstance(): ObservationQueue {
    if (ObservationQueue.inst === null) {
      ObservationQueue.inst = new ObservationQueue()
    }
    return ObservationQueue.inst
  }

  setRecognizer(r: FrameRecognizer | null): void {
    this.recognizer = r
  }

  setOnObservation(cb: ((o: ObservationRecord) => void) | null): void {
    this.onObservation = cb
  }

  /** 入队即返回；真正的识别在后台串行进行 */
  /** 本会话已入队的次数（**累计**，用于在控制台上显示配额用量） */
  getQuotaUsed(sessionId: string): number {
    const used = this.enqueuedBySession.get(sessionId)
    return used !== undefined ? used : 0
  }

  /**
   * 重置本会话的入队配额（**仅演示控制台显式调用**）。
   *
   * 配额本身是产品约束（避免连续抓拍与上传打扰用户），不该被自动绕过；
   * 但演示时若被配额挡住，界面必须能说清原因、也得有出口 —— 否则就是"点了没反应"。
   */
  resetQuota(sessionId: string): void {
    this.enqueuedBySession.set(sessionId, 0)
  }

  enqueue(sessionId: string, event: WatchEvent, frames: ArrayBuffer[]): void {
    const used = this.enqueuedBySession.get(sessionId)
    const count = used !== undefined ? used : 0
    if (count >= FocusTuning.MAX_QUEUE_PER_SESSION) {
      hilog.warn(DOMAIN, TAG, '本会话队列已满，丢弃本次（上限 %{public}d）', FocusTuning.MAX_QUEUE_PER_SESSION)
      return
    }
    this.enqueuedBySession.set(sessionId, count + 1)
    this.tasks.push({ sessionId: sessionId, event: event, frames: frames })
    this.consume()
  }

  /** 会话结束时重置计数（避免跨会话累积） */
  resetSession(sessionId: string): void {
    this.enqueuedBySession.delete(sessionId)
  }

  private consume(): void {
    if (this.consuming) {
      return
    }
    const task = this.tasks.shift()
    if (task === undefined) {
      return
    }
    this.consuming = true
    this.runTask(task)
      .then(() => {
        this.consuming = false
        this.consume()
      })
      .catch((e: Error) => {
        hilog.error(DOMAIN, TAG, '队列任务异常：%{public}s', e.message)
        this.consuming = false
        this.consume()
      })
  }

  private async runTask(task: QueueTask): Promise<void> {
    const rec = await this.recognizeWithRetry(task.frames)
    const o = rec !== null ? rec : this.unknownRecord()
    o.id = IdUtils.uuid()
    o.sessionId = task.sessionId
    o.eventId = task.event.id
    o.tMs = task.event.tMs
    // 帧落盘：决策是"上传并保存供复盘"，路径随记录入库（保留期与清除见 B5）
    o.imagePaths = this.saveFrames(task.sessionId, task.frames)

    try {
      await StorageService.getInstance().saveObservation(o)
    } catch (e) {
      // 带上原因：落库失败是"复盘里什么都没有"最可能的原因，不能只留一句"失败"
      hilog.error(DOMAIN, TAG, '观察记录落库失败：%{public}s', e.message)
    }
    if (this.onObservation !== null) {
      this.onObservation(o)
    }
  }

  /** 识别失败重试 1 次后放弃（不阻塞后续任务） */
  private async recognizeWithRetry(frames: ArrayBuffer[]): Promise<ObservationRecord | null> {
    if (this.recognizer === null) {
      return null
    }
    // 注意：不在这里因为 frames 为空就放弃 —— 模拟识别器不需要帧；
    // 真实网关实现应在自己内部判断"没有帧则无法识别"。
    const r = await this.recognizer.recognize(frames).catch((e: Error) => {
      hilog.error(DOMAIN, TAG, '识别异常：%{public}s', e.message)
      return null
    })
    if (r !== null) {
      return r
    }
    return await this.recognizer.recognize(frames).catch(() => null)
  }

  private unknownRecord(): ObservationRecord {
    const o = new ObservationRecord()
    o.activity = '无法判断'
    o.confidence = 0
    o.evidence = this.recognizer === null ? '云端识别未接入' : '云端识别失败或未配置'
    return o
  }

  /**
   * 帧落盘到会话目录。写失败不影响流程（只是复盘看不到图）。
   * 返回成功写入的文件路径。
   *
   * **本地只留 `KEEP_FRAMES_PER_OBS` 张**：上传给云端的是全部帧（多帧识别更准），
   * 但本地存全 6 张会让一次分心产生 6 个文件、连续几次就堆满沙箱。
   *
   * 对外可见：`FocusController` 的"模拟注入"路径（不经过本队列）需要复用同一套落盘逻辑，
   * 保证两条路产生的 `imagePaths` 口径一致。
   */
  saveFrames(sessionId: string, frames: ArrayBuffer[]): string[] {
    const paths: string[] = []
    if (frames.length === 0) {
      return paths
    }
    const dir = `${StorageService.getInstance().filesDir()}/obs/${sessionId}`
    const keep = Math.min(frames.length, FocusTuning.KEEP_FRAMES_PER_OBS)
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true)
      }
      for (let i = 0; i < keep; i++) {
        const p = `${dir}/${Date.now()}_${i}.jpg`
        const file = fileIo.openSync(p, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
        fileIo.writeSync(file.fd, frames[i])
        fileIo.closeSync(file)
        paths.push(p)
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '帧落盘失败，仅保留识别结论')
    }
    return paths
  }
}
