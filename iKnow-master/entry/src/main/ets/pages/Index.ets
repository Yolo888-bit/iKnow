import { router } from '@kit.ArkUI'
import { Home } from './Home'
import { Dashboard } from './Dashboard'
import { TaskPlanning } from './TaskPlanning'
import { Review } from './Review'
import { Mine } from './Mine'
import { Colors, Radius } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { StorageService } from '../services/StorageService'
import { FocusController } from '../services/FocusController'
import { AppStore } from '../store/AppStore'
import { SessionSnapshot } from '../models/SessionSnapshot'
import { TimeUtils } from '../utils/TimeUtils'

/**
 * 根容器：5 个底部 Tab（专注 / AI 规划 / 复盘 / 工作台 / 我的）
 *
 * 导航约定（统一模型）：**本页是唯一根页，永不被 replace**。
 * 二级页（Focus / FocusBreak / AIChat / StudyReport 等）统一 pushUrl，
 * 返回统一 router.back()。子页面需要切换 Tab 时通过 INDEX_TAB_REQUEST 传递。
 */
@Entry
@Component
struct Index {
  @State currentTab: number = 0
  @State showRecover: boolean = false
  @State recoverSnap: SessionSnapshot | null = null
  @StorageProp(StorageKey.INDEX_TAB_REQUEST) @Watch('onTabRequest') tabRequest: number = -1
  /** 全局「专注进行中」横幅：任意 Tab 可见，避免"会话在跑却没有出口" */
  @StorageProp(StorageKey.FOCUS_RUNNING) focusRunningFlag: number = 0
  @StorageProp(StorageKey.FOCUS_ELAPSED) focusElapsed: number = 0
  @State showSaved: boolean = false
  private controller: TabsController = new TabsController()

  aboutToAppear(): void {
    this.checkRecovery()
  }

  private resumeFocus(): void {
    router.pushUrl({ url: 'pages/Focus' })
  }

  /** 从根页直接结束会话（横幅上的「结束」） */
  private async endFocusFromRoot(): Promise<void> {
    try {
      await AppStore.getInstance().endSession()
    } catch (e) {
      // 结束失败也必须让统计与界面跟上，否则今日数据会停在旧值
      await AppStore.getInstance().syncAfterSession()
    }
    this.showSaved = true
  }

  /**
   * 切 Tab 时重算一次聚合。
   * 首页/工作台是 Tabs 的常驻子页，退出专注后不会重新走 aboutToAppear；
   * 这里补一道"看之前先刷新"，从根上避免"退出了但今日数据没变"。
   */
  private refreshOnTabSwitch(index: number): void {
    if (index === 0 || index === 3) {
      AppStore.getInstance().refreshAggregates()
    }
  }

  /** 子页面请求切 Tab（如"AI 帮我规划"） */
  private onTabRequest(): void {
    const t = this.tabRequest
    if (t < 0) {
      return
    }
    this.controller.changeIndex(t)
    this.currentTab = t
    this.refreshOnTabSwitch(t)
    AppStorage.setOrCreate<number>(StorageKey.INDEX_TAB_REQUEST, -1)
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
    Stack({ alignContent: Alignment.TopStart }) {
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          Home()
        }.tabBar(this.tabBar('专注', 0, '🎯'))

        TabContent() {
          TaskPlanning()
        }.tabBar(this.tabBar('AI 规划', 1, '🤖'))

        TabContent() {
          Review()
        }.tabBar(this.tabBar('复盘', 2, '📈'))

        TabContent() {
          Dashboard()
        }.tabBar(this.tabBar('工作台', 3, '📊'))

        TabContent() {
          Mine()
        }.tabBar(this.tabBar('我的', 4, '👤'))
      }
      .scrollable(false)
      .barHeight(60)
      .backgroundColor(Colors.BG)
      .onChange((index: number) => {
        this.currentTab = index
        this.refreshOnTabSwitch(index)
      })

      // 全局「专注进行中」横幅：任意 Tab 可见，永远有出口（继续 / 结束）
      if (this.focusRunningFlag === 1) {
        Row() {
          Text(`专注进行中 · ${TimeUtils.formatClock(this.focusElapsed)}`)
            .fontSize(13)
            .fontColor(Colors.TEXT_PRIMARY)
            .layoutWeight(1)
          Button('继续专注')
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY_STRONG)
            .height(30)
            .borderRadius(15)
            .onClick(() => {
              this.resumeFocus()
            })
          Button('结束')
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
            .backgroundColor(Colors.CARD)
            .height(30)
            .borderRadius(15)
            .margin({ left: 8 })
            .onClick(() => {
              this.endFocusFromRoot()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })
        .backgroundColor(Colors.PRIMARY_SOFT)
      }

      // 结束后给一个复盘入口，避免「直接结束」看不到结果
      if (this.showSaved) {
        Row() {
          Text('已保存本次专注')
            .fontSize(13)
            .fontColor(Colors.TEXT_PRIMARY)
            .layoutWeight(1)
          Button('查看复盘')
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor(Colors.PRIMARY_STRONG)
            .height(30)
            .borderRadius(15)
            .onClick(() => {
              this.showSaved = false
              router.pushUrl({ url: 'pages/StudyReport' })
            })
          Button('知道了')
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
            .backgroundColor(Colors.CARD)
            .height(30)
            .borderRadius(15)
            .margin({ left: 8 })
            .onClick(() => {
              this.showSaved = false
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })
        .backgroundColor(Colors.GREEN_SOFT)
      }

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
                .backgroundColor(Colors.PRIMARY_STRONG)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  if (this.recoverSnap !== null) {
                    FocusController.getInstance().restore(this.recoverSnap)
                  }
                  this.showRecover = false
                  this.recoverSnap = null
                  // 会话已恢复（running），不需要再请求新开
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
