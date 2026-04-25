/**
 * 桌面小组件卡片 - 替代 Android WidgetProvider + widget_layout.xml
 * 显示 Hitokoto 文字和作者
 * HarmonyOS 6: 支持卡片刷新事件和 formId 持久化
 */

const localStorage = new LocalStorage();
const OPAQUE_ANCHOR_HEIGHT: string = '12%';

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

  private getPrimaryTextColor(): string {
    return this.isEnabled(this.widgetDark) ? '#1C1C1C' : '#FFFFFF';
  }

  private getSecondaryTextColor(): string {
    return this.isEnabled(this.widgetDark) ? '#434343' : '#FFFFFF';
  }

  private getOpaqueAnchorColor(): string {
    return this.isEnabled(this.widgetDark) ? '#1C1C1C' : '#FFFFFF';
  }

  @Builder
  QuoteText(textAlign: TextAlign) {
    Text(this.text)
      .fontSize(15)
      .fontColor(this.getPrimaryTextColor())
      .textAlign(textAlign)
      .maxLines(4)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .textShadow({
        radius: this.isEnabled(this.widgetShadow) ? 8 : 0,
        color: this.isEnabled(this.widgetShadow) ? '#B0000000' : '#00000000',
        offsetX: 0,
        offsetY: 0
      })
  }

  @Builder
  AuthorText() {
    if (this.by !== '') {
      Text(`—— ${this.by}`)
        .fontSize(15)
        .fontColor(this.getSecondaryTextColor())
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

  build() {
    Column() {
      Column() {
        if (this.isEnabled(this.widgetCenter)) {
          this.QuoteText(TextAlign.Center)
        } else {
          this.QuoteText(TextAlign.Start)
          this.AuthorText()
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Row()
        .width('100%')
        // Keep the transparent widget's opaque area above the 10% review threshold.
        .height(OPAQUE_ANCHOR_HEIGHT)
        .backgroundColor(this.getOpaqueAnchorColor())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceBetween)
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
