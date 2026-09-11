import { router } from '@kit.ArkUI'
import { Home } from './Home'
import { Dashboard } from './Dashboard'
import { Review } from './Review'
import { Mine } from './Mine'
import { Colors, Radius } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { StorageService } from '../services/StorageService'
import { FocusController } from '../services/FocusController'
import { AppStore } from '../store/AppStore'
import { SessionSnapshot } from '../models/SessionSnapshot'

/** 根容器：4 个底部 Tab */
@Entry
@Component
struct Index {
  @State currentTab: number = 0
  @State showRecover: boolean = false
  @State recoverSnap: SessionSnapshot | null = null
  private controller: TabsController = new TabsController()

  aboutToAppear(): void {
    this.checkRecovery()
  }

  /** 硬规则 §7：启动检查是否有被中断（崩溃/被杀）的会话，弹"继续/结束/放弃" */
  private async checkRecovery(): Promise<void> {
    try {
      const id = await StorageService.getInstance().loadKv(StorageKey.ACTIVE_SESSION_ID)
      if (id.length === 0) {
        return
      }
      const snap = await StorageService.getInstance().loadLatestSnapshot(id)
      if (snap === null) {
        return
      }
      // 仅当最近快照在 30 分钟内，才视为"被中断的会话"
      if (Date.now() - snap.ts > 30 * 60 * 1000) {
        return
      }
      this.recoverSnap = snap
      this.showRecover = true
    } catch (e) {
      // 恢复检查失败不影响正常使用
    }
  }

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
    Stack() {
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          Home()
        }.tabBar(this.tabBar('首页', 0, '🏠'))

        TabContent() {
          Dashboard()
        }.tabBar(this.tabBar('工作台', 1, '📊'))

        TabContent() {
          Review()
        }.tabBar(this.tabBar('复盘', 2, '📈'))

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

      // 中断恢复弹窗（覆盖层，不影响 Tabs 布局）
      if (this.showRecover && this.recoverSnap !== null) {
        Column() {
          Column() {
            Text('发现未结束的专注')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('上次专注似乎被打断了，要接着继续，还是结束它？')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 8 })
              .width('100%')

            Row({ space: 10 }) {
              Button('放弃')
                .layoutWeight(1)
                .height(44)
                .fontSize(14)
                .fontColor(Colors.TEXT_SECONDARY)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  StorageService.getInstance().saveKv(StorageKey.ACTIVE_SESSION_ID, '').catch(() => {})
                  if (this.recoverSnap !== null) {
                    StorageService.getInstance().deleteSnapshots(this.recoverSnap.sessionId).catch(() => {})
                  }
                  this.showRecover = false
                  this.recoverSnap = null
                })
              Button('结束本次')
                .layoutWeight(1)
                .height(44)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor(Colors.PRIMARY_DARK)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  if (this.recoverSnap !== null) {
                    FocusController.getInstance().restore(this.recoverSnap)
                    AppStore.getInstance().endSession()
                      .then(() => {
                        this.showRecover = false
                        this.recoverSnap = null
                      })
                      .catch(() => {
                        this.showRecover = false
                        this.recoverSnap = null
                      })
                  } else {
                    this.showRecover = false
                  }
                })
              Button('继续专注')
                .layoutWeight(1)
                .height(44)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor(Colors.PRIMARY)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  if (this.recoverSnap !== null) {
                    FocusController.getInstance().restore(this.recoverSnap)
                  }
                  this.showRecover = false
                  this.recoverSnap = null
                  router.pushUrl({ url: 'pages/Focus' })
                })
            }
            .margin({ top: 20 })
            .width('100%')
          }
          .width('82%')
          .padding(24)
          .backgroundColor(Colors.CARD)
          .borderRadius(Radius.LG)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
