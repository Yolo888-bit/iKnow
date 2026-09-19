import { StorageService } from './StorageService'
import { AuthKey } from '../common/Constants'

/** 登录结果 */
export class AuthResult {
  ok: boolean = false
  message: string = ''
  username: string = ''
}

/**
 * 本地登录服务（MVP 无后端时的账号兜底）
 *
 *  - **注册与登录分开**：`register()` 显式创建账号，`login()` 只校验已有账号，
 *    「账号不存在」会明确提示去注册（不再静默地用登录顺手建号）。
 *  - 单账号模型：本机只保留一个本地账号（KV 只存一对用户名/密码散列）；
 *    换用户名重新注册即视为切换账号（本地演示允许）。
 *  - 密码不落明文，仅存本地散列摘要（避免明文读数，不作为安全边界）。
 *  - 生产环境应替换为服务端鉴权；此处不涉及、也不保存任何 API Key（硬规则 §10）。
 */
export class AuthService {
  private static inst: AuthService | null = null

  static getInstance(): AuthService {
    if (AuthService.inst === null) {
      AuthService.inst = new AuthService()
    }
    return AuthService.inst
  }

  /** 是否已登录（用于启动门禁） */
  async isLoggedIn(): Promise<boolean> {
    try {
      const v = await StorageService.getInstance().loadKv(AuthKey.LOGGED_IN)
      return v === '1'
    } catch (e) {
      return false
    }
  }

  /** 当前登录用户名（未登录返回空串） */
  async currentUsername(): Promise<string> {
    try {
      return await StorageService.getInstance().loadKv(AuthKey.USERNAME)
    } catch (e) {
      return ''
    }
  }

  /** 本机是否已经创建过账号（用于决定首屏默认显示「注册」还是「登录」） */
  async hasAccount(): Promise<boolean> {
    try {
      const n = await this.currentUsername()
      return n.length > 0
    } catch (e) {
      return false
    }
  }

  /**
   * 注册：显式创建本地账号。
   *  - 同名账号已存在 → 提示直接登录，不覆盖。
   *  - 单账号模型：已有其它账号时，用新用户名注册即切换/重建本地账号。
   */
  async register(username: string, password: string, confirm: string): Promise<AuthResult> {
    const r = new AuthResult()
    const name = username.trim()
    if (name.length === 0) {
      r.message = '请输入用户名'
      return r
    }
    if (name.length < 2) {
      r.message = '用户名至少 2 个字符'
      return r
    }
    if (password.length < 6) {
      r.message = '密码至少 6 位'
      return r
    }
    if (password !== confirm) {
      r.message = '两次输入的密码不一致'
      return r
    }

    const storedName = await this.currentUsername()
    if (storedName.length > 0 && storedName === name) {
      r.message = '该用户名已注册，请直接登录'
      return r
    }

    await StorageService.getInstance().saveKv(AuthKey.USERNAME, name)
    await StorageService.getInstance().saveKv(AuthKey.PASSWORD_HASH, AuthService.hash(password))
    await StorageService.getInstance().saveKv(AuthKey.LOGGED_IN, '1')
    r.ok = true
    r.username = name
    r.message = `账号创建成功，欢迎你，${name}`
    return r
  }

  /**
   * 登录：用户名 + 密码，**只校验已有账号**，不会顺手建号。
   *  - 本机还没有账号 / 用户名对不上 → 提示先去注册。
   *  - 账号存在但密码不符 → 提示密码不正确。
   */
  async login(username: string, password: string): Promise<AuthResult> {
    const r = new AuthResult()
    const name = username.trim()
    if (name.length === 0) {
      r.message = '请输入用户名'
      return r
    }
    if (password.length < 6) {
      r.message = '密码至少 6 位'
      return r
    }

    const storedName = await this.currentUsername()
    if (storedName.length === 0) {
      r.message = '本机还没有账号，请先注册'
      return r
    }
    if (storedName !== name) {
      r.message = '账号不存在，请先注册'
      return r
    }
    const storedHash = await StorageService.getInstance().loadKv(AuthKey.PASSWORD_HASH)
    if (storedHash !== AuthService.hash(password)) {
      r.message = '密码不正确'
      return r
    }

    await StorageService.getInstance().saveKv(AuthKey.LOGGED_IN, '1')
    r.ok = true
    r.username = name
    r.message = `欢迎回来，${name}`
    return r
  }

  /** 退出登录（保留本地账号，便于下次直接登录） */
  async logout(): Promise<void> {
    await StorageService.getInstance().saveKv(AuthKey.LOGGED_IN, '0')
  }

  /** 简易本地散列（djb2）；仅避免明文落盘，生产走服务端鉴权 */
  private static hash(s: string): string {
    let h = 5381
    for (let i = 0; i < s.length; i++) {
      h = ((h << 5) + h + s.charCodeAt(i)) | 0
    }
    return `h${h.toString(16)}`
  }
}
