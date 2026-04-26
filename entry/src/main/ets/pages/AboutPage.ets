import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { UiStyle } from '../common/UiStyle';
import { AppBackgroundLayer } from '../common/AppBackgroundUtil';

const ABOUT_CONTENT_MAX_WIDTH_COMPACT: number = 560;
const ABOUT_CONTENT_MAX_WIDTH_WIDE: number = 760;
const ABOUT_RESPONSIVE_WIDE_WIDTH: number = 720;
const APP_VERSION_NAME: string = '1.0.0';

/**
 * 关于页面 - 替代 Android AboutActivity
 * HarmonyOS 6: 使用 NavDestination 作为导航目的地
 */
@Component
export struct AboutPageContent {
  @State pageWidth: number = 0;
  @Consume('navPathStack') navPathStack: NavPathStack;

  private isWideLayout(): boolean {
    return this.pageWidth >= ABOUT_RESPONSIVE_WIDE_WIDTH;
  }

  private getContentMaxWidth(): number {
    return this.isWideLayout() ? ABOUT_CONTENT_MAX_WIDTH_WIDE : ABOUT_CONTENT_MAX_WIDTH_COMPACT;
  }

  private getGlassCardColor(): ResourceColor {
    return $r('app.color.colorGlassCard');
  }

  private getGlassCardBorder(): ResourceColor {
    return $r('app.color.colorGlassBorder');
  }

  private async openLink(url: string): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url
    };

    try {
      const context = getContext(this) as common.UIAbilityContext;
      await context.startAbility(want);
    } catch (e) {
      console.error('AboutPage', `openLink error: ${JSON.stringify(e)}`);
      this.showToast('无法打开链接');
    }
  }

  private showToast(message: string): void {
    try {
      promptAction.showToast({ message: message });
    } catch (e) {
      console.warn('AboutPage', `showToast skipped: ${JSON.stringify(e)}`);
    }
  }

  build() {
    NavDestination() {
      Stack() {
        AppBackgroundLayer()

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
          .height(UiStyle.HEADER_ROW_HEIGHT)
          .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE })

          Scroll() {
            Column() {
              this.AboutContent()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
        .padding({ top: UiStyle.PAGE_TOP })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(UiStyle.TRANSPARENT)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageWidth = Number.parseFloat(String(newValue.width));
    })
  }

  @Builder
  AboutContent() {
    Column() {
      Column() {
        Image($r('app.media.app_icon'))
          .width(80)
          .height(80)
          .borderRadius(16)

        Text('Hitokoto')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ top: 12 })

        Text('一句话')
          .fontSize(14)
          .fontColor($r('app.color.colorText3'))
          .margin({ top: 4 })

        Text(`v${APP_VERSION_NAME} · HarmonyOS 6`)
          .fontSize(12)
          .fontColor($r('app.color.colorText4'))
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ top: 32, bottom: 32 })
      .alignItems(HorizontalAlign.Center)

      this.AboutInfoCard($r('app.string.about_introduction'))
      this.AboutTextCard('许可证', 'Hitokoto 遵循 LGPL v3 许可证，在这个基础上你可以修改它。')
      this.AboutTextCard('致谢', '在开发过程中，我们特别感谢：\nlz233 · XiaoMengXinX · Kanglyh · NekoInverter · RebornQ')

      Column() {
        Text('相关链接')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.colorPrimary'))
          .width('100%')
          .padding({ bottom: 8 })

        this.LinkItem('项目主页', 'https://github.com/lvcdy/OneText_For_Harmonry')
        this.LinkItem('使用API地址', 'https://v1.hitokoto.cn')
        this.LinkItem('隐私政策', 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1936386579987723392')
      }
      .width('100%')
      .padding(20)
      .backgroundColor(this.getGlassCardColor())
      .borderRadius(UiStyle.DIALOG_RADIUS)
      .border({ width: 1, color: this.getGlassCardBorder() })
      .margin({ left: 20, right: 20, top: 20 })

      this.AboutTextCard('本项目的开发离不开以下项目：', 'HarmonyOS · ArkUI · ArkTS · Material Design Icons')
    }
    .width('100%')
    .constraintSize({ maxWidth: this.getContentMaxWidth() })
  }

  @Builder
  AboutInfoCard(text: ResourceStr) {
    Column() {
      Text(text)
        .fontSize(15)
        .fontColor($r('app.color.colorText2'))
        .lineHeight(24)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .backgroundColor(this.getGlassCardColor())
    .borderRadius(UiStyle.DIALOG_RADIUS)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .margin({ left: 20, right: 20 })
  }

  @Builder
  AboutTextCard(title: string, text: string) {
    Column() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.colorPrimary'))
        .width('100%')
        .padding({ bottom: 8 })

      Text(text)
        .fontSize(14)
        .fontColor($r('app.color.colorText2'))
        .lineHeight(22)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.getGlassCardColor())
    .borderRadius(UiStyle.DIALOG_RADIUS)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .margin({ left: 20, right: 20, top: 20 })
  }

  @Builder
  LinkItem(title: string, url: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor($r('app.color.colorText1'))

      Text(url)
        .fontSize(13)
        .fontColor($r('app.color.colorPrimary'))
        .width('100%')
        .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 10 })
    .onClick(async () => {
      await this.openLink(url);
    })
  }
}
