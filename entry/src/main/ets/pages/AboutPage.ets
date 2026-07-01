import { common, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { UiStyle } from '../common/UiStyle';
import { AppBackgroundLayer } from '../common/AppBackgroundUtil';

const ABOUT_CONTENT_MAX_WIDTH_COMPACT: number = 560;
const ABOUT_CONTENT_MAX_WIDTH_WIDE: number = 760;
const ABOUT_RESPONSIVE_WIDE_WIDTH: number = 720;
const APP_VERSION_NAME: string = '2.0.0';

/**
 * 关于页面 - 重新设计
 * HarmonyOS 7: 使用 NavDestination 作为导航目的地
 */
@Component
export struct AboutPageContent {
  @Env(SystemProperties.WINDOW_AVOID_AREA) avoidAreas!: window.UIEnvWindowAvoidAreaInfoVP
  @State statusBarHeight: number = 0;
  @State pageWidth: number = 0;
  @Consume('navPathStack') navPathStack: NavPathStack;

  private isWideLayout(): boolean {
    return this.pageWidth >= ABOUT_RESPONSIVE_WIDE_WIDTH;
  }

  private getContentMaxWidth(): number {
    return this.isWideLayout() ? ABOUT_CONTENT_MAX_WIDTH_WIDE : ABOUT_CONTENT_MAX_WIDTH_COMPACT;
  }

  private getStatusBarHeight(): number {
    if (this.statusBarHeight > 0) {
      return this.statusBarHeight;
    }
    const statusBarHeightPx: number = this.avoidAreas.statusBar?.topRect?.height ?? 0;
    return statusBarHeightPx > 0 ? this.getUIContext().px2vp(statusBarHeightPx) : 44;
  }

  async aboutToAppear(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const win = await window.getLastWindow(context);
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = this.getUIContext().px2vp(avoidArea.topRect.height);
    } catch (e) {
      console.warn('AboutPage', `get status bar height failed: ${JSON.stringify(e)}`);
      this.statusBarHeight = 44;
    }
  }

  private getGlassCardColor(): ResourceColor {
    return $r('app.color.colorGlassCard');
  }

  private getGlassCardBorder(): ResourceColor {
    return $r('app.color.colorGlassBorder');
  }

  private getGlassShadowColor(): ResourceColor {
    return $r('app.color.colorGlassShadow');
  }

  private getGlassControlColor(): ResourceColor {
    return $r('app.color.colorGlassControl');
  }

  private async openLink(url: string): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url
    };

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility(want);
    } catch (e) {
      console.error('AboutPage', `openLink error: ${JSON.stringify(e)}`);
      this.showToast('无法打开链接');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
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
              this.AboutHeroSection()
              this.AboutInfoSection()
              this.AboutLinksSection()
              this.AboutCreditsSection()
              this.AboutFooter()
            }
            .width('100%')
            .constraintSize({ maxWidth: this.getContentMaxWidth() })
            .padding({ bottom: 40 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.getStatusBarHeight() })
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
  AboutHeroSection() {
    Column() {
      // 应用图标和名称
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image($r('app.media.app_icon'))
            .width(96)
            .height(96)
            .borderRadius(24)
            .shadow({ radius: 20, color: '#33000000', offsetX: 0, offsetY: 8 })

          // 版本徽章
          Text(`v${APP_VERSION_NAME}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.colorPrimary'))
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        .width(110)
        .height(110)

        Text('Hitokoto')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ top: 16 })

        Text('一言 · 世间万物，皆可为言')
          .fontSize(15)
          .fontColor($r('app.color.colorText3'))
          .margin({ top: 6 })

        Text(`HarmonyOS 7 · API 26`)
          .fontSize(12)
          .fontColor($r('app.color.colorText4'))
          .margin({ top: 12 })
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor(this.getGlassControlColor())
      }
      .width('100%')
      .padding({ top: 40, bottom: 32 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .margin({ left: 20, right: 20 })
  }

  @Builder
  AboutInfoSection() {
    Column() {
      Text('关于一言')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorText1'))
        .width('100%')
        .margin({ bottom: 12 })

      Text($r('app.string.about_introduction'))
        .fontSize(14)
        .fontColor($r('app.color.colorText2'))
        .lineHeight(24)

      Divider()
        .strokeWidth(1)
        .color(this.getGlassCardBorder())
        .margin({ top: 16, bottom: 16 })

      Row() {
        this.StatItem('开源协议', 'LGPL v3')
        this.StatItem('框架', 'ArkUI')
        this.StatItem('语言', 'ArkTS')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.getGlassCardColor())
    .borderRadius(UiStyle.CARD_RADIUS)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .shadow({ radius: 16, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })
    .margin({ left: 20, right: 20, top: 8 })
  }

  @Builder
  StatItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorPrimary'))

      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.colorText4'))
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  AboutLinksSection() {
    Column() {
      Text('相关链接')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorText1'))
        .width('100%')
        .margin({ bottom: 12 })

      this.LinkItem('项目主页', 'github.com/lvcdy/OneText_For_Harmonry',
        'https://github.com/lvcdy/OneText_For_Harmonry')
      this.LinkItem('API 服务', 'v1.hitokoto.cn',
        'https://v1.hitokoto.cn')
      this.LinkItem('隐私政策', '华为应用市场隐私协议',
        'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1937206089888053568')
      this.LinkItem('用户协议', '华为应用市场用户协议',
        'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1937206089888053568')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.getGlassCardColor())
    .borderRadius(UiStyle.CARD_RADIUS)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .shadow({ radius: 16, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })
    .margin({ left: 20, right: 20, top: 16 })
  }

  @Builder
  LinkItem(title: string, subtitle: string, url: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.colorText1'))

        Text(subtitle)
          .fontSize(12)
          .fontColor($r('app.color.colorPrimary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.ic_arrow_right'))
        .width(16)
        .height(16)
        .opacity(0.55)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(async () => {
      await this.openLink(url);
    })
  }

  @Builder
  AboutCreditsSection() {
    Column() {
      Text('致谢')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorText1'))
        .width('100%')
        .margin({ bottom: 12 })

      Text('感谢以下开发者的贡献：')
        .fontSize(13)
        .fontColor($r('app.color.colorText3'))
        .width('100%')
        .margin({ bottom: 12 })

      // 贡献者网格
      Flex({ wrap: FlexWrap.Wrap }) {
        this.ContributorChip('lz233')
        this.ContributorChip('XiaoMengXinX')
        this.ContributorChip('Kanglyh')
        this.ContributorChip('NekoInverter')
        this.ContributorChip('RebornQ')
      }
      .width('100%')

      Divider()
        .strokeWidth(1)
        .color(this.getGlassCardBorder())
        .margin({ top: 16, bottom: 16 })

      Text('本项目的开发离不开以下项目：')
        .fontSize(13)
        .fontColor($r('app.color.colorText3'))
        .width('100%')
        .margin({ bottom: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        this.TechChip('HarmonyOS')
        this.TechChip('ArkUI')
        this.TechChip('ArkTS')
        this.TechChip('Material Icons')
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.getGlassCardColor())
    .borderRadius(UiStyle.CARD_RADIUS)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .shadow({ radius: 16, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })
    .margin({ left: 20, right: 20, top: 16 })
  }

  @Builder
  ContributorChip(name: string) {
    Text(name)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.colorText2'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(20)
      .backgroundColor(this.getGlassControlColor())
      .border({ width: 1, color: this.getGlassCardBorder() })
      .margin({ right: 10, bottom: 10 })
  }

  @Builder
  TechChip(name: string) {
    Text(name)
      .fontSize(12)
      .fontColor($r('app.color.colorPrimary'))
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(12)
      .backgroundColor('#1A6B5EFF')
      .border({ width: 1, color: '#336B5EFF' })
      .margin({ right: 8, bottom: 8 })
  }

  @Builder
  AboutFooter() {
    Column() {
      Text('Copyright © 2024-2026 lvcdy')
        .fontSize(11)
        .fontColor($r('app.color.colorText4'))

      Text('All rights reserved')
        .fontSize(11)
        .fontColor($r('app.color.colorText4'))
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ top: 32 })
    .alignItems(HorizontalAlign.Center)
  }
}
