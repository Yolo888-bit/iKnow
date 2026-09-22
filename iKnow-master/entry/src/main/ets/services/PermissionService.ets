import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { Authorization } from '../models/Authorization'
import { StorageService } from './StorageService'

/**
 * 分项授权服务 —— 隐私合规全局唯一事实源（PRD §17，硬规则 §4）
 *
 *  - camera / microphone / health / notification 四项独立开关，全部以本服务为唯一事实源。
 *  - 关闭摄像头后，专注降级为"仅计时模式"，UI 明示"本次未开启感知"。
 *  - 权限变更持久化（落 authorization 表），并广播给订阅者（FocusDetectionService 等）。
 *  - 相机/蓝牙都是 user_grant 权限：`ensureCamera()` / `ensureBluetooth()` 真正向系统申请成功后，
 *    才写入本地标记；未申请成功时专注页降级为"仅计时模式"并如实标注。
 *  - **是否探测硬件不由本地标记决定**：否则未授权时永远测不出设备是否存在（见 CameraService.probe）。
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

  /**
   * 确保拿到系统相机权限（ohos.permission.CAMERA 是 user_grant）。
   *
   * 已授权时 `requestPermissionsFromUser` 会**立即返回结果、不弹窗**，
   * 因此它同时充当"检查 + 申请"两用入口 —— 所有进入专注页的路径都应先调它，
   * 否则会出现"没授权 → 不去探测硬件 → 永远不知道有没有摄像头"的逻辑死角。
   * **只有拿到系统授权才写本地标记**，避免本地标记与系统真实授权不一致。
   */
  async ensureCamera(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const mgr = abilityAccessCtrl.createAtManager()
      const perms: Permissions[] = ['ohos.permission.CAMERA']
      const res = await mgr.requestPermissionsFromUser(ctx, perms)
      if (res.authResults.length === 0 || res.authResults[0] !== 0) {
        return false
      }
    } catch (e) {
      return false
    }
    await this.grant('camera')
    return true
  }

  /**
   * 确保拿到系统麦克风权限（user_grant），供语音输入（按住说话）使用。
   * 与 `ensureCamera` 同一模式：已授权时立即返回、不弹窗；只有拿到系统授权才写本地标记。
   * 注意：拿到权限 ≠ 语音识别可用 —— 系统语音服务是否可用由识别引擎决定（见 VoiceInputService）。
   */
  async ensureMicrophone(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const mgr = abilityAccessCtrl.createAtManager()
      const perms: Permissions[] = ['ohos.permission.MICROPHONE']
      const res = await mgr.requestPermissionsFromUser(ctx, perms)
      if (res.authResults.length === 0 || res.authResults[0] !== 0) {
        return false
      }
    } catch (e) {
      return false
    }
    await this.grant('microphone')
    return true
  }

  isMicrophoneOn(): boolean {
    return this.auth.microphone
  }

  /** 确保拿到蓝牙权限（user_grant）；已授权时立即返回、不弹窗 */
  async ensureBluetooth(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const mgr = abilityAccessCtrl.createAtManager()
      const perms: Permissions[] = ['ohos.permission.ACCESS_BLUETOOTH']
      const res = await mgr.requestPermissionsFromUser(ctx, perms)
      return res.authResults.length > 0 && res.authResults[0] === 0
    } catch (e) {
      return false
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
