import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { Colors, Radius } from '../common/Theme'
import { StorageKey } from '../common/Constants'
import { AppStore } from '../store/AppStore'
import { UserAvatar } from './UserAvatar'

/**
 * 头像选择器（底部弹出）
 *
 *  - **不依赖 `bindSheet`**：改用自定义全屏覆盖层 + 底部面板，在 Tabs 子页面里也稳定可用。
 *  - 用法：父页面根 `Stack` 中放一层 `AvatarPicker({ show: this.xxx, onClose: () => { this.xxx = false } })`。
 *  - 支持两种头像：从相册选真实照片（`PhotoViewPicker` + 拷贝到沙箱，无需申请权限）、或选 emoji。
 */
@Component
export struct AvatarPicker {
  /** 是否显示（由父页面 @State 单向传入） */
  @Prop show: boolean = false
  /** 关闭回调（点遮罩 / 选完 / 取消时触发） */
  onClose: () => void = () => {
  }
  @StorageProp(StorageKey.USER_AVATAR) avatar: string = '🧑‍🎓'
  private options: string[] = [
    '🦊', '🐱', '🐼', '🐯', '🦁', '🐸', '🐵', '🐧',
    '🦄', '🐨', '🦉', '🐢', '🌟', '🍀', '🚀', '🎯'
  ]

  /** 选中 emoji 头像 */
  private async choose(a: string): Promise<void> {
    await AppStore.getInstance().saveUserAvatar(a)
    this.onClose()
    promptAction.showToast({ message: '头像已更新' })
  }

  /** 从相册选择照片 → 拷贝到应用沙箱持久化 */
  private async pickFromGallery(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const picker = new photoAccessHelper.PhotoViewPicker()
      const result = await picker.select(options)
      const uris: string[] = result.photoUris
      if (uris.length === 0) {
        return
      }
      const ctx = getContext(this) as common.UIAbilityContext
      const destPath: string = `${ctx.filesDir}/avatar_${Date.now()}.jpg`
      const src = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY)
      const dest = fileIo.openSync(destPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      fileIo.copyFileSync(src.fd, dest.fd)
      fileIo.closeSync(src)
      fileIo.closeSync(dest)

      await AppStore.getInstance().saveUserAvatar(`file://${destPath}`)
      this.onClose()
      promptAction.showToast({ message: '头像已更新' })
    } catch (err) {
      promptAction.showToast({ message: '已取消选择' })
    }
  }

  @Builder
  panel() {
    Column() {
      // 顶部拖拽提示条
      Column() {}
      .width(38)
      .height(4)
      .backgroundColor(Colors.LINE)
      .borderRadius(2)
      .margin({ top: 8, bottom: 14 })

      Text('选择头像')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT_PRIMARY)
        .width('100%')
        .textAlign(TextAlign.Center)

      // 从相册选择真实照片
      Row() {
        Text('🖼️').fontSize(20)
        Text('从相册选择照片')
          .fontSize(15)
          .fontColor(Colors.TEXT_PRIMARY)
          .margin({ left: 12 })
        Blank()
        Text('›')
          .fontSize(18)
          .fontColor(Colors.TEXT_TERTIARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor(Colors.BG)
      .borderRadius(Radius.MD)
      .margin({ left: 20, right: 20, top: 16 })
      .onClick(() => {
        this.pickFromGallery()
      })

      Text('或选一个 emoji 头像')
        .fontSize(12)
        .fontColor(Colors.TEXT_SECONDARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 18, bottom: 12 })

      Grid() {
        ForEach(this.options, (a: string) => {
          GridItem() {
            Column() {
              UserAvatar({ avatar: a, diameter: 44, bg: this.avatar === a ? Colors.PRIMARY_SOFT : Colors.BG })
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.choose(a)
            })
          }
        }, (a: string) => a)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(12)
      .columnsGap(12)
      .height(196)
      .width('100%')
      .padding({ left: 20, right: 20 })

      Button('取消')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor(Colors.TEXT_SECONDARY)
        .backgroundColor(Colors.BG)
        .borderRadius(Radius.MD)
        .margin({ left: 20, right: 20, top: 18, bottom: 26 })
        .onClick(() => {
          this.onClose()
        })
    }
    .width('100%')
    .backgroundColor(Colors.CARD)
    .borderRadius({ topLeft: 24, topRight: 24 })
  }

  build() {
    if (this.show) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 遮罩：点空白处关闭
        Column() {}
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.onClose()
        })

        this.panel()
      }
      .width('100%')
      .height('100%')
    }
  }
}
