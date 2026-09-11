/** 导航参数载体：用于向通用占位页（Placeholder）传递标题。
 * ArkTS 禁止未类型化对象字面量，故用显式类承载路由参数。 */
export class NavParams {
  title: string = ''

  constructor(t: string) {
    this.title = t
  }
}
