/**
 * 唯一 ID 生成
 */
export class IdUtils {
    static uuid(): string {
        const t = Date.now().toString(36);
        const r = Math.floor(Math.random() * 0xffffff).toString(36);
        const r2 = Math.floor(Math.random() * 0xffffff).toString(36);
        return `${t}-${r}-${r2}`;
    }
}
