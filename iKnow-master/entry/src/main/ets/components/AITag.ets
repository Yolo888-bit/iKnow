import { Colors } from '../common/Theme'

/** AI 智能体身份标签（合规：所有 AI 界面固定体现） */
@Component
export struct AITag {
  build() {
    Row() {
      Text('💡').fontSize(14)
      Text('AI 智能体').fontSize(13).fontColor(Colors.TEXT_SECONDARY).margin({ left: 4 })
    }
    .padding({ left: 10, right: 12, top: 5, bottom: 5 })
    .backgroundColor(Colors.PRIMARY_SOFT)
    .borderRadius(20)
  }
}
