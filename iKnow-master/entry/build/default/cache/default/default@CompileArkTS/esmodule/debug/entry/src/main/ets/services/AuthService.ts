import { StorageService } from "@normalized:N&&&entry/src/main/ets/services/StorageService&";
import { AuthKey } from "@normalized:N&&&entry/src/main/ets/common/Constants&";
/** 登录结果 */
export class AuthResult {
    ok: boolean = false;
    message: string = '';
    username: string = '';
}
/**
 * 本地登录服务（MVP 无后端时的账号兜底）
 *
 *  - 需提供「用户名 + 密码（≥ 6 位）」；首次使用某个用户名即创建本地账号。
 *  - 同名账号二次登录会校验密码；换一个用户名视为切换账号（本地演示允许）。
 *  - 密码不落明文，仅存本地散列摘要（避免明文读数，不作为安全边界）。
 *  - 生产环境应替换为服务端鉴权；此处不涉及、也不保存任何 API Key（硬规则 §10）。
 */
export class AuthService {
    private static inst: AuthService | null = null;
    static getInstance(): AuthService {
        if (AuthService.inst === null) {
            AuthService.inst = new AuthService();
        }
        return AuthService.inst;
    }
    /** 是否已登录（用于启动门禁） */
    async isLoggedIn(): Promise<boolean> {
        try {
            const v = await StorageService.getInstance().loadKv(AuthKey.LOGGED_IN);
            return v === '1';
        }
        catch (e) {
            return false;
        }
    }
    /** 当前登录用户名（未登录返回空串） */
    async currentUsername(): Promise<string> {
        try {
            return await StorageService.getInstance().loadKv(AuthKey.USERNAME);
        }
        catch (e) {
            return '';
        }
    }
    /**
     * 登录：用户名 + 密码。
     *  - 首次使用该用户名 → 创建本地账号并登录。
     *  - 已存在同名账号 → 校验密码，通过才登录。
     */
    async login(username: string, password: string): Promise<AuthResult> {
        const r = new AuthResult();
        const name = username.trim();
        if (name.length === 0) {
            r.message = '请输入用户名';
            return r;
        }
        if (password.length < 6) {
            r.message = '密码至少 6 位';
            return r;
        }
        const storedName = await this.currentUsername();
        const hash = AuthService.hash(password);
        if (storedName.length > 0 && storedName === name) {
            const storedHash = await StorageService.getInstance().loadKv(AuthKey.PASSWORD_HASH);
            if (storedHash !== hash) {
                r.message = '密码不正确';
                return r;
            }
        }
        await StorageService.getInstance().saveKv(AuthKey.USERNAME, name);
        await StorageService.getInstance().saveKv(AuthKey.PASSWORD_HASH, hash);
        await StorageService.getInstance().saveKv(AuthKey.LOGGED_IN, '1');
        r.ok = true;
        r.username = name;
        r.message = `欢迎回来，${name}`;
        return r;
    }
    /** 退出登录（保留本地账号，便于下次直接登录） */
    async logout(): Promise<void> {
        await StorageService.getInstance().saveKv(AuthKey.LOGGED_IN, '0');
    }
    /** 简易本地散列（djb2）；仅避免明文落盘，生产走服务端鉴权 */
    private static hash(s: string): string {
        let h = 5381;
        for (let i = 0; i < s.length; i++) {
            h = ((h << 5) + h + s.charCodeAt(i)) | 0;
        }
        return `h${h.toString(16)}`;
    }
}
