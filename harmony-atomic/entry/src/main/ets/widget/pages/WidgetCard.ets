/**
 * 桌面小组件卡片 - 元服务版
 * 显示一言文字和作者，支持点击跳转到元服务
 */

const localStorage = new LocalStorage();

@Entry(localStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('text') text: string = '生活不止眼前的苟且，还有诗和远方。';
  @LocalStorageProp('by') by: string = '高晓松';
  @LocalStorageProp('widget_dark') widgetDark: string = 'false';
  @LocalStorageProp('widget_shadow') widgetShadow: string = 'true';
  @LocalStorageProp('widget_center') widgetCenter: string = 'true';

  private isEnabled(value: string): boolean {
    return value === 'true';
  }

  build() {
    Column() {
      if (this.isEnabled(this.widgetCenter)) {
        Text(this.text)
          .fontSize(15)
          .fontColor(this.isEnabled(this.widgetDark) ? '#1C1C1C' : '#FFFFFF')
          .textAlign(TextAlign.Center)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textShadow({
            radius: this.isEnabled(this.widgetShadow) ? 8 : 0,
            color: this.isEnabled(this.widgetShadow) ? '#B0000000' : '#00000000',
            offsetX: 0,
            offsetY: 0
          })
      } else {
        Text(this.text)
          .fontSize(15)
          .fontColor(this.isEnabled(this.widgetDark) ? '#1C1C1C' : '#FFFFFF')
          .textAlign(TextAlign.Start)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textShadow({
            radius: this.isEnabled(this.widgetShadow) ? 8 : 0,
            color: this.isEnabled(this.widgetShadow) ? '#B0000000' : '#00000000',
            offsetX: 0,
            offsetY: 0
          })

        if (this.by !== '') {
          Text(`—— ${this.by}`)
            .fontSize(15)
            .fontColor(this.isEnabled(this.widgetDark) ? '#434343' : '#FFFFFF')
            .textAlign(TextAlign.End)
            .width('100%')
            .textShadow({
              radius: this.isEnabled(this.widgetShadow) ? 8 : 0,
              color: this.isEnabled(this.widgetShadow) ? '#B0000000' : '#00000000',
              offsetX: 0,
              offsetY: 0
            })
        }
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility'
      });
    })
  }
}
