/**
 * 关于页面 - 替代 Android AboutActivity
 * HarmonyOS 6: 使用 NavDestination 作为导航目的地
 */
@Component
export struct AboutPageContent {
  @Consume('navPathStack') navPathStack: NavPathStack;

  build() {
    NavDestination() {
      Column() {
        // 顶部标题栏
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.navPathStack.pop();
            })

        Text($r('app.string.about_text'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          // 应用图标和名称
          Column() {
            Image($r('app.media.app_icon'))
              .width(80)
              .height(80)
              .borderRadius(16)

            Text('OneText')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.colorText1'))
              .margin({ top: 12 })

            Text('一言')
              .fontSize(14)
              .fontColor($r('app.color.colorText3'))
              .margin({ top: 4 })

            Text('v3.0.0 · HarmonyOS 6')
              .fontSize(12)
              .fontColor($r('app.color.colorText4'))
              .margin({ top: 8 })
          }
          .width('100%')
          .padding({ top: 32, bottom: 32 })
          .alignItems(HorizontalAlign.Center)

          // 应用介绍
          Column() {
            Text($r('app.string.about_introduction'))
              .fontSize(15)
              .fontColor($r('app.color.colorText2'))
              .lineHeight(24)
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 16, bottom: 16 })
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(16)
          .margin({ left: 16, right: 16 })

          // 许可证
          Column() {
            Text('许可证')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.colorPrimary'))
              .width('100%')
              .padding({ bottom: 8 })

            Text('OneText 遵循 LGPL v3 许可证，在这个基础上你可以修改它。')
              .fontSize(14)
              .fontColor($r('app.color.colorText2'))
              .lineHeight(22)
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 16 })

          // 致谢
          Column() {
            Text('致谢')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.colorPrimary'))
              .width('100%')
              .padding({ bottom: 8 })

            Text('在开发过程中，我们特别感谢：')
              .fontSize(14)
              .fontColor($r('app.color.colorText2'))

            Text('lz233 · XiaoMengXinX · Kanglyh · NekoInverter · RebornQ')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.colorText1'))
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 16 })

          // 相关链接
          Column() {
            Text('相关链接')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.colorPrimary'))
              .width('100%')
              .padding({ bottom: 8 })

            this.LinkItem('项目主页', 'https://github.com/lz233/OneText_For_Android')
            this.LinkItem('核心库', 'https://github.com/lz233/OneText-Library')
            this.LinkItem('Telegram 群组', 'https://t.me/OneTextProject')
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 16 })

          // 依赖项目
          Column() {
            Text('本项目的开发离不开以下项目：')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.colorPrimary'))
              .width('100%')
              .padding({ bottom: 8 })

            Text('HarmonyOS · ArkUI · ArkTS · Material Design Icons')
              .fontSize(13)
              .fontColor($r('app.color.colorText3'))
              .lineHeight(22)
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 16, bottom: 32 })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.colorBackground'))
    }
    .hideTitleBar(true)
  }

  @Builder
  LinkItem(title: string, url: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor($r('app.color.colorText1'))
      Blank()
      Text(url)
        .fontSize(11)
        .fontColor($r('app.color.colorText4'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 200 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
