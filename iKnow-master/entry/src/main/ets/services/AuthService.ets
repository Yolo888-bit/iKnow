import { StorageService } from './StorageService'
import { AuthKey, StorageKey, PrivacyDoc } from '../common/Constants'

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
 *  - **隐私协议是前置条件**：`register()` / `login()` 都会先校验"是否已同意当前版本"，
 *    未同意直接返回提示、不做任何账号操作（对应登录页那个必须勾选的复选框）。
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

  // ---------- 隐私协议同意（登录 / 注册的前置条件）----------

  /** 已同意过的文档版本（没同意过返回空串） */
  async consentedVersion(): Promise<string> {
    try {
      return await StorageService.getInstance().loadKv(AuthKey.CONSENT_VERSION)
    } catch (e) {
      return ''
    }
  }

  /**
   * 是否已经同意**当前版本**的协议。
   *
   * 存的是版本号而不是布尔值：文档内容改版后（`PrivacyDoc.VERSION` 变了），
   * 旧的同意自动失效，用户必须重新阅读并勾选 —— 这是合规上的要求，
   * 不能因为"以前同意过"就一直沿用。
   */
  async hasConsent(): Promise<boolean> {
    const v = await this.consentedVersion()
    return v.length > 0 && v === PrivacyDoc.VERSION
  }

  /** 记下这次同意（版本 + 时间戳），落本地 KV 留痕 */
  async recordConsent(): Promise<void> {
    await StorageService.getInstance().saveKv(AuthKey.CONSENT_VERSION, PrivacyDoc.VERSION)
    await StorageService.getInstance().saveKv(AuthKey.CONSENT_AT, `${Date.now()}`)
  }

  /** 撤回同意：清掉留痕。用户下次登录会被要求重新阅读并勾选。 */
  async withdrawConsent(): Promise<void> {
    await StorageService.getInstance().saveKv(AuthKey.CONSENT_VERSION, '')
  }

  /**
   * 注册：显式创建本地账号。
   *  - 同名账号已存在 → 提示直接登录，不覆盖。
   *  - 单账号模型：已有其它账号时，用新用户名注册即切换/重建本地账号。
   */
  async register(username: string, password: string, confirm: string): Promise<AuthResult> {
    const r = new AuthResult()
    // 前置门禁：必须先同意当前版本的协议（UI 上表现为勾选框，这里做服务层兜底，
    // 避免将来新增调用方绕过勾选直接建号）
    const consented = await this.hasConsent()
    if (!consented) {
      r.message = `请先阅读并勾选同意《${PrivacyDoc.AGREEMENT}》与《${PrivacyDoc.POLICY}》`
      return r
    }
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
    // 「每次登录后都换一句新语录」：这里只清**进程内**缓存，
    // KV 里的「上次展示过的那句」保留着，正好给新语录做避让
    AppStorage.setOrCreate<string>(StorageKey.GOAL_SLOGAN, '')
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
    // 同 register：登录也要先同意当前版本的协议
    const consented = await this.hasConsent()
    if (!consented) {
      r.message = `请先阅读并勾选同意《${PrivacyDoc.AGREEMENT}》与《${PrivacyDoc.POLICY}》`
      return r
    }
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
    // 退出也清一次，保证下次登录进来是全新的一句
    AppStorage.setOrCreate<string>(StorageKey.GOAL_SLOGAN, '')
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
