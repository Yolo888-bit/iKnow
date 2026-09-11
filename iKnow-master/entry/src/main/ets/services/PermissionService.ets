import { Authorization } from '../models/Authorization'
import { StorageService } from './StorageService'

/**
 * 分项授权服务 —— 隐私合规全局唯一事实源（PRD §17，硬规则 §4）
 *
 *  - camera / microphone / health / notification 四项独立开关，全部以本服务为唯一事实源。
 *  - 关闭摄像头后，专注降级为"仅计时模式"，UI 明示"本次未开启感知"。
 *  - 权限变更持久化（落 authorization 表），并广播给订阅者（FocusDetectionService 等）。
 *  - 首次启动读取系统真实相机权限作为初值（此处以 setSystemCameraPermission 注入，
 *    真实环境应调用 @ohos.permission 的查询结果）。
 */
export type AuthKind = 'camera' | 'microphone' | 'health' | 'notification'

export class PermissionService {
  private static inst: PermissionService | null = null
  private auth: Authorization = new Authorization()
  private listeners: Array<(a: Authorization) => void> = []
  private initialized: boolean = false

  static getInstance(): PermissionService {
    if (PermissionService.inst === null) {
      PermissionService.inst = new PermissionService()
    }
    return PermissionService.inst
  }

  async init(): Promise<void> {
    if (this.initialized) {
      return
    }
    const stored = await StorageService.getInstance().loadAuthorization()
    this.auth = stored ?? new Authorization()
    this.initialized = true
    this.emit()
  }

  /** 当前授权快照（只读使用） */
  snapshot(): Authorization {
    return this.auth
  }

  isCameraOn(): boolean {
    return this.auth.camera
  }

  isWatchHealthOn(): boolean {
    return this.auth.health
  }

  /** 注入系统真实相机权限初值（真实环境由 Ability 启动时调用） */
  setSystemCameraPermission(granted: boolean): void {
    if (!this.auth.camera && granted) {
      this.auth.camera = granted
      this.auth.updatedAt = Date.now()
      StorageService.getInstance().saveAuthorization(this.auth).then(() => this.emit()).catch(() => {})
    }
  }

  private setKind(kind: AuthKind, value: boolean): void {
    switch (kind) {
      case 'camera':
        this.auth.camera = value
        break
      case 'microphone':
        this.auth.microphone = value
        break
      case 'health':
        this.auth.health = value
        break
      case 'notification':
        this.auth.notification = value
        break
      default:
        break
    }
  }

  async grant(kind: AuthKind): Promise<void> {
    this.setKind(kind, true)
    this.auth.updatedAt = Date.now()
    await StorageService.getInstance().saveAuthorization(this.auth)
    this.emit()
  }

  async revoke(kind: AuthKind): Promise<void> {
    this.setKind(kind, false)
    this.auth.updatedAt = Date.now()
    await StorageService.getInstance().saveAuthorization(this.auth)
    this.emit()
  }

  /** 订阅授权变化（FocusDetectionService 据此启停摄像头检测） */
  onChange(cb: (a: Authorization) => void): void {
    this.listeners.push(cb)
  }

  private emit(): void {
    for (const cb of this.listeners) {
      cb(this.auth)
    }
  }
}
