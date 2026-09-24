import { common } from '@kit.AbilityKit'
import { ble, access } from '@kit.ConnectivityKit'
import { Colors, Radius, Spacing } from '../common/Theme'
import { DeviceService } from '../services/DeviceService'
import { DeviceInfo } from '../services/ServiceTypes'
import { BleWatchService } from '../services/BleWatchService'
import { CameraService } from '../services/CameraService'
import { PermissionService } from '../services/PermissionService'

/** 设备连接（含真实 BLE 心率设备 + 设备自检）。模拟状态已移到「专注页 → 模拟状态」。 */
@Entry
@Component
export struct Device {
  @State devices: DeviceInfo[] = []
  @State watchPresent: boolean = false
  @State bleNames: string[] = []
  @State bleIds: string[] = []
  @State bleStatus: string = '未连接'
  @State bleScanning: boolean = false
  // 设备自检（联调时把关键事实常驻在界面上，不用猜）
  @State camCount: number = 0
  @State camError: string = ''
  @State camGranted: boolean = false
  @State btOn: boolean = false

  aboutToAppear(): void {
    this.refresh()
    BleWatchService.getInstance().setListeners(
      (list: Array<ble.ScanResult>) => {
        const names: string[] = []
        const ids: string[] = []
        for (const r of list) {
          names.push(r.deviceName.length > 0 ? r.deviceName : r.deviceId)
          ids.push(r.deviceId)
        }
        this.bleNames = names
        this.bleIds = ids
      },
      () => {
        this.bleStatus = BleWatchService.getInstance().getStatusText()
        this.bleScanning = BleWatchService.getInstance().isScanning()
      }
    )
    this.bleStatus = BleWatchService.getInstance().getStatusText()
  }

  aboutToDisappear(): void {
    BleWatchService.getInstance().setListeners(null, null)
    BleWatchService.getInstance().stopScan()
  }

  private async startBleScan(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const granted = await PermissionService.getInstance().ensureBluetooth(ctx)
    if (!granted) {
      this.bleScanning = false
      this.bleStatus = '未授予蓝牙权限'
      return
    }
    this.bleScanning = true
    const err = await BleWatchService.getInstance().startScan()
    if (err.length > 0) {
      this.bleScanning = false
      this.bleStatus = err
    } else {
      this.bleStatus = '扫描中，请把设备靠近手机…'
    }
  }

  private connectBle(idx: number): void {
    if (idx < 0 || idx >= this.bleIds.length) {
      return
    }
    BleWatchService.getInstance().stopScan()
    this.bleScanning = false
    BleWatchService.getInstance().connect(this.bleIds[idx])
  }

  private refresh(): void {
    this.devices = DeviceService.getInstance().getDevices()
    this.watchPresent = DeviceService.getInstance().isWatchPresent()
    // 设备自检：摄像头数量 / 权限 / 蓝牙开关
    const ctx = getContext(this) as common.UIAbilityContext
    this.camCount = CameraService.getInstance().probe(ctx)
    this.camError = CameraService.getInstance().getLastError()
    this.camGranted = PermissionService.getInstance().isCameraOn()
    try {
      this.btOn = access.getState() === access.BluetoothState.STATE_ON
    } catch (e) {
      this.btOn = false
    }
  }

  private icon(type: string): string {
    if (type === 'CAMERA') {
      return '📷'
    }
    if (type === 'WATCH') {
      return '⌚'
    }
    return '📱'
  }

  build() {
    Scroll() {
      Column({ space: Spacing.LG }) {
        Text('设备连接')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.TEXT_PRIMARY)
          .width('100%')

        Column({ space: Spacing.SM }) {
          ForEach(this.devices, (d: DeviceInfo) => {
            Row() {
              Text(this.icon(d.type)).fontSize(26)
              Column() {
                Text(d.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Colors.TEXT_PRIMARY)
                Text(d.statusText)
                  .fontSize(12)
                  .fontColor(Colors.TEXT_SECONDARY)
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 14 })
              .layoutWeight(1)

              Row() {
                Circle()
                  .width(8)
                  .height(8)
                  .fill(d.connected ? Colors.GREEN : Colors.TEXT_TERTIARY)
                Text(d.connected ? '已连接' : '未连接')
                  .fontSize(12)
                  .fontColor(d.connected ? Colors.GREEN : Colors.TEXT_SECONDARY)
                  .margin({ left: 6 })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Colors.CARD)
            .borderRadius(Radius.MD)
          }, (d: DeviceInfo) => d.type)
        }
        .width('100%')

        // 设备自检：联调时先看这里，再看 DevEco Log（TAG: iKnow.Camera / iKnow.Ble）
        Column() {
          Row() {
            Text('设备自检')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.TEXT_PRIMARY)
            Blank()
            Button('重新探测')
              .fontSize(12)
              .fontColor(Colors.PRIMARY_DARK)
              .backgroundColor(Colors.BG)
              .height(30)
              .borderRadius(15)
              .onClick(() => {
                this.refresh()
              })
          }
          .width('100%')

          this.checkRow('摄像头数量', this.camCount > 0 ? `${this.camCount} 个` : '0 个（无可用摄像头）')
          this.checkRow('相机权限', this.camGranted ? '已授予' : '未授予')
          this.checkRow('蓝牙开关', this.btOn ? '已开启' : '未开启（请到系统设置打开）')
          if (this.camError.length > 0) {
            this.checkRow('摄像头错误', this.camError)
          }
          this.checkRow('BLE 状态', this.bleStatus)
        }
        .deviceCard()

        // 真实蓝牙心率设备（标准 HRS）
        Column() {
          Text('连接真实手表 / 心率带')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')

          Text('多数手环使用厂商私有协议，可能扫描不到，属正常现象；此时可以用下面的模拟佩戴。')
            .fontSize(12)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(18)
            .width('100%')
            .margin({ top: 8 })

          Text(this.bleStatus)
            .fontSize(12)
            .fontColor(Colors.PRIMARY_DARK)
            .width('100%')
            .margin({ top: 10 })

          Row({ space: 10 }) {
            Button(this.bleScanning ? '扫描中…' : '扫描设备')
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor(Colors.PRIMARY_STRONG)
              .height(40)
              .borderRadius(20)
              .onClick(() => {
                this.startBleScan()
              })
            if (BleWatchService.getInstance().isConnected()) {
              Button('断开')
                .fontSize(14)
                .fontColor(Colors.TEXT_PRIMARY)
                .backgroundColor(Colors.CARD)
                .height(40)
                .borderRadius(20)
                .onClick(() => {
                  BleWatchService.getInstance().disconnect()
                })
            }
          }
          .width('100%')
          .margin({ top: 12 })

          if (this.bleNames.length > 0) {
            ForEach(this.bleNames, (n: string, idx: number) => {
              Row() {
                Column() {
                  Text(n)
                    .fontSize(14)
                    .fontColor(Colors.TEXT_PRIMARY)
                  Text(this.bleIds[idx])
                    .fontSize(11)
                    .fontColor(Colors.TEXT_TERTIARY)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Button('连接')
                  .fontSize(12)
                  .fontColor(Color.White)
                  .backgroundColor(Colors.PRIMARY_STRONG)
                  .height(30)
                  .borderRadius(15)
                  .onClick(() => {
                    this.connectBle(idx)
                  })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }, (n: string, idx: number) => `${n}_${idx}`)
          }
        }
        .deviceCard()

        // 模拟手表（只保留"是否佩戴"这一个设备属性；
        // 状态/信号的手动驱动已统一移到「专注页 → 模拟状态」）
        Column() {
          Text('模拟手表')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_PRIMARY)
            .width('100%')

          Text('手表为模拟设备（默认未佩戴）。未佩戴时红级提醒走手机声音与屏幕，不会假装震动。')
            .fontSize(13)
            .fontColor(Colors.TEXT_SECONDARY)
            .lineHeight(20)
            .width('100%')
            .margin({ top: 8 })

          Row() {
            Column() {
              Text('模拟佩戴手表')
                .fontSize(15)
                .fontColor(Colors.TEXT_PRIMARY)
              Text(this.watchPresent ? '已佩戴：红级干预尝试手表震动' : '未佩戴：红级干预走手机声音 + 屏幕')
                .fontSize(12)
                .fontColor(Colors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.watchPresent })
              .selectedColor(Colors.PRIMARY)
              .onChange((v: boolean) => {
                this.watchPresent = v
                DeviceService.getInstance().setWatchPresent(v)
                this.refresh()
              })
          }
          .width('100%')
          .padding({ top: 14, bottom: 4 })

          Text('要手动驱动状态（做题 / 看手机 / 趴桌 / 离开…），请到「专注页 → 模拟状态」。')
            .fontSize(11)
            .fontColor(Colors.TEXT_TERTIARY)
            .lineHeight(16)
            .width('100%')
            .margin({ top: 6 })
        }
        .deviceCard()

        Blank().height(20)
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor(Colors.BG)
    .width('100%')
    .height('100%')
  }

  /** 设备自检的一行：左标签右值 */
  @Builder
  checkRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(Colors.TEXT_SECONDARY)
      Blank()
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_PRIMARY)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 0.5 }, color: Colors.LINE })
  }
}

@Extend(Column)
function deviceCard() {
  .width('100%')
  .padding(18)
  .backgroundColor(Colors.CARD)
  .borderRadius(Radius.LG)
  .alignItems(HorizontalAlign.Start)
}
