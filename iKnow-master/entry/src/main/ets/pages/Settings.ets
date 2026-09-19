import { promptAction } from '@kit.ArkUI'
import { Colors, Radius, Spacing } from '../common/Theme'
import { AppStore } from '../store/AppStore'
import { AIPersonality } from '../models/Enums'

interface PersonaOption {
  key: AIPersonality
  label: string
  desc: string
}

/** 设置：考伴人格 + 一键清除数据（合规） */
@Entry
@Component
export struct Settings {
  @State personality: AIPersonality = AIPersonality.GENTLE
  @State showClearConfirm: boolean = false
  private personas: PersonaOption[] = [
    { key: AIPersonality.STRICT, label: '严格教练型', desc: '直接 · 高执行力' },
    { key: AIPersonality.GENTLE, label: '温和陪伴型', desc: '鼓励 · 低压力' },
    { key: AIPersonality.QUIET, label: '极简安静型', desc: '不主动说话 · 轻量反馈' },
    { key: AIPersonality.ADAPTIVE, label: '智能适配', desc: '根据数据自动调整' }
  ]

  aboutToAppear(): void {
    this.personality = AppStore.getInstance().getUser().aiPersonality
  }

  private selectPersona(key: AIPersonality): void {
    this.personality = key
    AppStore.getInstance().saveUserPersonality(key)
    promptAction.showToast({ message: '已切换考伴人格' })
  }

  private doClearAll(): void {
    this.showClearConfirm = false
    AppStore.getInstance().clearAll().then(() => {
      promptAction.showToast({ message: '✓ 数据已彻底销毁' })
    })
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: Spacing.LG }) {
          Text('设置')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')

          // 考伴人格
          Column() {
            Text('考伴人格')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 8 })

            ForEach(this.personas, (p: PersonaOption) => {
              Row() {
                Column() {
                  Text(p.label)
                    .fontSize(15)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Text(p.desc)
                    .fontSize(12)
                    .fontColor(Colors.TEXT_SECONDARY)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (this.personality === p.key) {
                  Text('✓')
                    .fontSize(18)
                    .fontColor(Colors.PRIMARY_DARK)
                }
              }
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .border({
                width: { bottom: p.key === AIPersonality.ADAPTIVE ? 0 : 0.5 },
                color: Colors.LINE
              })
              .onClick(() => {
                this.selectPersona(p.key)
              })
            }, (p: PersonaOption) => p.label)
          }
          .settingCard()

          // 数据清除（合规必备：一键清除 + 二次确认）
          Column() {
            Text('数据管理')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
              .width('100%')

            Text('清除后所有学习记录与画像将不可恢复。')
              .fontSize(13)
              .fontColor(Colors.TEXT_SECONDARY)
              .width('100%')
              .margin({ top: 8 })

            Button('一键清除所有本地数据')
              .width('100%')
              .height(48)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor(Colors.CAMERA_RED)
              .borderRadius(Radius.MD)
              .margin({ top: 16 })
              .onClick(() => {
                this.showClearConfirm = true
              })
          }
          .settingCard()

          Text('iKnow · 专注感知智能考伴 v1.0.0')
            .fontSize(12)
            .fontColor(Colors.TEXT_TERTIARY)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })

          Blank().height(20)
        }
        .padding(20)
        .width('100%')
      }
      .width('100%')
      .height('100%')

      // 二次确认弹窗
      if (this.showClearConfirm) {
        Column() {
          Column() {
            Text('确定清除所有本地数据吗？')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Text('将删除所有学习记录和生理数据。该操作不可恢复。')
              .fontSize(14)
              .fontColor(Colors.TEXT_SECONDARY)
              .margin({ top: 8 })

            Row({ space: 12 }) {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontColor(Colors.TEXT_SECONDARY)
                .backgroundColor(Colors.BG)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  this.showClearConfirm = false
                })
              Button('确认清除')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(Colors.CAMERA_RED)
                .borderRadius(Radius.MD)
                .onClick(() => {
                  this.doClearAll()
                })
            }
            .margin({ top: 20 })
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

@Extend(Column)
function settingCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
