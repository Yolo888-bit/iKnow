import { Home } from './Home'
import { Dashboard } from './Dashboard'
import { AICompanion } from './AICompanion'
import { Mine } from './Mine'
import { Colors } from '../common/Theme'

/** 根容器：4 个底部 Tab */
@Entry
@Component
struct Index {
  @State currentTab: number = 0
  private controller: TabsController = new TabsController()

  @Builder
  tabBar(title: string, index: number, icon: string) {
    Column() {
      Text(icon).fontSize(20)
      Text(title)
        .fontSize(11)
        .margin({ top: 2 })
        .fontColor(this.currentTab === index ? Colors.PRIMARY : Colors.TEXT_SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
      TabContent() {
        Home()
      }.tabBar(this.tabBar('首页', 0, '🏠'))

      TabContent() {
        Dashboard()
      }.tabBar(this.tabBar('工作台', 1, '📊'))

      TabContent() {
        AICompanion()
      }.tabBar(this.tabBar('AI 学伴', 2, '💡'))

      TabContent() {
        Mine()
      }.tabBar(this.tabBar('我的', 3, '👤'))
    }
    .scrollable(false)
    .barHeight(60)
    .backgroundColor(Colors.BG)
    .onChange((index: number) => {
      this.currentTab = index
    })
  }
}
