/**
 * 桌面小组件卡片 - 替代 Android WidgetProvider + widget_layout.xml
 * 显示一言文字和作者
 */

const localStorage = new LocalStorage();

@Entry(localStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('text') text: string = '生活不止眼前的苟且，还有诗和远方。';
  @LocalStorageProp('by') by: string = '高晓松';

  build() {
    Column() {
      // 一言文字
      Text(this.text)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 16, right: 16 })
        .textShadow({
          radius: 4,
          color: '#80000000',
          offsetX: 1,
          offsetY: 1
        })

      // 作者
      if (this.by !== '') {
        Text(`—— ${this.by}`)
          .fontSize(12)
          .fontColor('#E0FFFFFF')
          .textAlign(TextAlign.End)
          .width('100%')
          .margin({ top: 8 })
          .padding({ right: 16 })
          .textShadow({
            radius: 3,
            color: '#80000000',
            offsetX: 1,
            offsetY: 1
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(12)
    .linearGradient({
      direction: GradientDirection.BottomRight,
      colors: [
        ['#667eea', 0.0],
        ['#764ba2', 1.0]
      ]
    })
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility'
      });
    })
  }
}
