/**
 * 桌面小组件卡片 - 替代 Android WidgetProvider + widget_layout.xml
 * 显示一言文字和作者
 * HarmonyOS 6: 支持卡片刷新事件和 formId 持久化
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
    const darkMode = this.isEnabled(this.widgetDark);
    const shadowMode = this.isEnabled(this.widgetShadow);
    const centerMode = this.isEnabled(this.widgetCenter);
    const textColor = darkMode ? '#F5F7FA' : '#1C1C1C';
    const subTextColor = darkMode ? '#D0D5DD' : '#434343';
    Column() {
      Column() {
        if (centerMode) {
          if (shadowMode) {
            Text(this.text)
              .fontSize(16)
              .fontColor(textColor)
              .textAlign(TextAlign.Center)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 16, right: 16 })
              .textShadow({
                radius: 4,
                color: darkMode ? '#80000000' : '#40000000',
                offsetX: 1,
                offsetY: 1
              })
          } else {
            Text(this.text)
              .fontSize(16)
              .fontColor(textColor)
              .textAlign(TextAlign.Center)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 16, right: 16 })
          }
        } else {
          if (shadowMode) {
            Text(this.text)
              .fontSize(16)
              .fontColor(textColor)
              .textAlign(TextAlign.Start)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 16, right: 16 })
              .textShadow({
                radius: 4,
                color: darkMode ? '#80000000' : '#40000000',
                offsetX: 1,
                offsetY: 1
              })
          } else {
            Text(this.text)
              .fontSize(16)
              .fontColor(textColor)
              .textAlign(TextAlign.Start)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 16, right: 16 })
          }
        }

        // 作者
        if (this.by !== '' && !centerMode) {
          if (shadowMode) {
            Text(`—— ${this.by}`)
              .fontSize(12)
              .fontColor(subTextColor)
              .textAlign(TextAlign.End)
              .width('100%')
              .margin({ top: 8 })
              .padding({ right: 16 })
              .textShadow({
                radius: 3,
                color: darkMode ? '#80000000' : '#40000000',
                offsetX: 1,
                offsetY: 1
              })
          } else {
            Text(`—— ${this.by}`)
              .fontSize(12)
              .fontColor(subTextColor)
              .textAlign(TextAlign.End)
              .width('100%')
              .margin({ top: 8 })
              .padding({ right: 16 })
          }
        }
      }
      .width('100%')
      .alignItems(centerMode ? HorizontalAlign.Center : HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(12)
    .linearGradient(darkMode ? {
      direction: GradientDirection.BottomRight,
      colors: [
        ['#1F2937', 0.0],
        ['#111827', 1.0]
      ]
    } : {
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
