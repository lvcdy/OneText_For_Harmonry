/**
 * 桌面小组件卡片 - 替代 Android WidgetProvider + widget_layout.xml
 * 显示 Hitokoto 文字和作者
 * HarmonyOS 6: 支持卡片刷新事件和 formId 持久化
 */

import { OneTextMetaUtil } from '../../common/OneTextMetaUtil';

const localStorage = new LocalStorage();
const TRANSPARENT_OPAQUE_ANCHOR_HEIGHT: string = '0%';

@Entry(localStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('text') text: string = '生活不止眼前的苟且，还有诗和远方。';
  @LocalStorageProp('by') by: string = '高晓松';
  @LocalStorageProp('from') from: string = '';
  @LocalStorageProp('time') time: string = '';
  @LocalStorageProp('widget_dark') widgetDark: string = 'false';
  @LocalStorageProp('widget_shadow') widgetShadow: string = 'true';
  @LocalStorageProp('widget_center') widgetCenter: string = 'true';
  @LocalStorageProp('widget_blur_background') widgetBlurBackground: string = 'false';

  private isEnabled(value: string): boolean {
    return value === 'true';
  }

  private hasBlurBackground(): boolean {
    return this.isEnabled(this.widgetBlurBackground);
  }

  private getPrimaryTextColor(): string {
    return this.isEnabled(this.widgetDark) ? '#1C1C1C' : '#FFFFFF';
  }

  private getSecondaryTextColor(): string {
    return this.isEnabled(this.widgetDark) ? '#434343' : '#FFFFFF';
  }

  private getOpaqueAnchorColor(): string {
    return '#00000000';
  }

  private getOpaqueAnchorHeight(): string {
    return TRANSPARENT_OPAQUE_ANCHOR_HEIGHT;
  }

  private getFrostedGlassTintColor(): string {
    return this.isEnabled(this.widgetDark) ? '#22FFFFFF' : '#16000000';
  }

  private getFrostedGlassBorderColor(): string {
    return this.isEnabled(this.widgetDark) ? '#35FFFFFF' : '#22FFFFFF';
  }

  private getMetaText(): string {
    return OneTextMetaUtil.buildMetaText(this.by, this.from, this.time);
  }

  private refreshForm(): void {
    postCardAction(this, {
      action: 'message',
      params: {
        message: 'refresh'
      }
    });
  }

  @Builder
  WidgetBackground() {
    if (this.hasBlurBackground()) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.getFrostedGlassTintColor())
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
        .backdropBlur(30)
        .border({ width: 1, color: this.getFrostedGlassBorderColor() })
        .borderRadius(24)
    }
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
  MetaText(textAlign: TextAlign) {
    if (this.getMetaText() !== '') {
      Text(this.getMetaText())
        .fontSize(13)
        .fontColor(this.getSecondaryTextColor())
        .textAlign(textAlign)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })
        .textShadow({
          radius: this.isEnabled(this.widgetShadow) ? 8 : 0,
          color: this.isEnabled(this.widgetShadow) ? '#B0000000' : '#00000000',
          offsetX: 0,
          offsetY: 0
        })
    }
  }

  build() {
    Stack() {
      this.WidgetBackground()

      Column() {
        Column() {
          if (this.isEnabled(this.widgetCenter)) {
            this.QuoteText(TextAlign.Center)
            this.MetaText(TextAlign.Center)
          } else {
            this.QuoteText(TextAlign.Start)
            this.MetaText(TextAlign.End)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Row()
          .width('100%')
          .height(this.getOpaqueAnchorHeight())
          .backgroundColor(this.getOpaqueAnchorColor())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.refreshForm();
    })
  }
}
