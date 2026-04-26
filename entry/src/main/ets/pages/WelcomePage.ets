import { promptAction } from '@kit.ArkUI';
import { AppBackgroundLayer } from '../common/AppBackgroundUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { UiStyle } from '../common/UiStyle';

const WELCOME_RESPONSIVE_WIDE_WIDTH: number = 720;
const WELCOME_CONTENT_MAX_WIDTH_COMPACT: number = 560;
const WELCOME_CONTENT_MAX_WIDTH_WIDE: number = 680;

/**
 * 首次启动引导页 - 对齐原版 WelcomeActivity 的核心流程
 */
@Component
export struct WelcomePageContent {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @State currentStep: number = 0;
  @State pageWidth: number = 0;

  private prefs: PreferencesUtil = PreferencesUtil.getInstance();

  private isWideLayout(): boolean {
    return this.pageWidth >= WELCOME_RESPONSIVE_WIDE_WIDTH;
  }

  private getContentMaxWidth(): number {
    return this.isWideLayout() ? WELCOME_CONTENT_MAX_WIDTH_WIDE : WELCOME_CONTENT_MAX_WIDTH_COMPACT;
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

  private getGlassSelectedColor(): ResourceColor {
    return $r('app.color.colorGlassSelected');
  }

  private async finishWelcome(): Promise<void> {
    await this.prefs.putBoolean('first_run', false);
    this.navPathStack.pop();
    promptAction.showToast({ message: $r('app.string.welcome_done') });
  }

  build() {
    NavDestination() {
      Stack() {
        AppBackgroundLayer()

        Column() {
          Scroll() {
            Column() {
              this.WelcomeContent()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          this.BottomActions()
        }
        .width('100%')
        .height('100%')
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
  WelcomeContent() {
    Column() {
      this.BrandHeader()
      this.QuotePreview()

      Column() {
        this.StepItem(0, $r('app.string.welcome_step1_title'), $r('app.string.welcome_step1_desc'))
        this.StepItem(1, $r('app.string.welcome_step2_title'), $r('app.string.welcome_step2_desc'))
        this.StepItem(2, $r('app.string.welcome_step3_title'), $r('app.string.welcome_step3_desc'))
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor(this.getGlassCardColor())
      .border({ width: 1, color: this.getGlassCardBorder() })
      .borderRadius(UiStyle.CARD_RADIUS)
      .shadow({ radius: 18, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
      .margin({ top: UiStyle.CARD_GAP })

      this.ProgressDots()
    }
    .width('100%')
    .constraintSize({ maxWidth: this.getContentMaxWidth() })
    .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE, top: UiStyle.PAGE_TOP, bottom: UiStyle.BOTTOM_ACTION_HEIGHT + 12 })
  }

  @Builder
  BrandHeader() {
    Row() {
      Image($r('app.media.app_icon'))
        .width(56)
        .height(56)
        .borderRadius(16)
        .backgroundColor($r('app.color.colorSelectedBg'))

      Column() {
        Text('Hitokoto')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))

        Text($r('app.string.welcome_title'))
          .fontSize(13)
          .fontColor($r('app.color.colorText4'))
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })

      Blank()
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  QuotePreview() {
    Column() {
      Text($r('app.string.welcome_subtitle'))
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorText1'))
        .width('100%')
        .textAlign(TextAlign.Center)

      Text($r('app.string.welcome_intro'))
        .fontSize(15)
        .fontColor($r('app.color.colorText3'))
        .lineHeight(24)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })

      Stack() {
        if (this.currentStep === 1) {
          Image($r('app.media.moemiku'))
            .width(118)
            .height(118)
            .opacity(0.2)
            .position({ x: 190, y: 44 })
        }

        Column() {
          Text('“')
            .fontSize(42)
            .fontColor('#D6E1FF')
            .height(36)
            .width('100%')
            .textAlign(TextAlign.Start)

          Text(this.currentStep === 0 ? '把一句话留在今天' : (this.currentStep === 1 ? '把喜欢的文字放到桌面' : '让文字更像你的风格'))
            .fontSize(21)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.colorText1'))
            .lineHeight(32)
            .width('100%')
            .textAlign(TextAlign.Center)

          Text(this.currentStep === 0 ? '主页 · Hitokoto' : (this.currentStep === 1 ? '小组件 · 桌面卡片' : '字体 · 订阅源'))
            .fontSize(13)
            .fontColor($r('app.color.colorText4'))
            .margin({ top: 14 })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 22, right: 22, top: 18, bottom: 18 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height(190)
      .backgroundColor(this.getGlassCardColor())
      .border({ width: 1, color: this.getGlassCardBorder() })
      .borderRadius(UiStyle.CARD_RADIUS)
      .shadow({ radius: 22, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 8 })
      .margin({ top: 22 })
    }
    .width('100%')
    .margin({ top: 24 })
  }

  @Builder
  StepItem(index: number, title: Resource, desc: Resource) {
    Row() {
      Column() {
        Text(`${index + 1}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(index === this.currentStep ? Color.White : $r('app.color.colorPrimary'))
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor(index === this.currentStep ? $r('app.color.colorPrimary') : $r('app.color.colorSelectedBg'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .width('100%')

        Text(desc)
          .fontSize(13)
          .fontColor($r('app.color.colorText3'))
          .lineHeight(21)
          .width('100%')
          .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .borderRadius(20)
    .backgroundColor(index === this.currentStep ? this.getGlassSelectedColor() : UiStyle.TRANSPARENT)
    .onClick(() => {
      this.currentStep = index;
    })
  }

  @Builder
  ProgressDots() {
    Row({ space: 8 }) {
      ForEach([0, 1, 2], (index: number) => {
        Column()
          .width(index === this.currentStep ? 22 : 8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(index === this.currentStep ? $r('app.color.colorPrimary') : '#D8E1F3')
          .animation({ duration: 180, curve: Curve.EaseOut })
      }, (index: number) => index.toString())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 22 })
  }

  @Builder
  BottomActions() {
    Column() {
      Row() {
        Button($r('app.string.welcome_skip'))
          .type(ButtonType.Capsule)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.colorPrimary'))
          .backgroundColor(this.getGlassControlColor())
          .border({ width: 1, color: this.getGlassCardBorder() })
          .height(48)
          .layoutWeight(1)
          .margin({ right: 8 })
          .onClick(async () => {
            await this.finishWelcome();
          })

        Button(this.currentStep < 2 ? $r('app.string.welcome_next') : $r('app.string.welcome_start'))
          .type(ButtonType.Capsule)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.colorPrimary'))
          .height(48)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(async () => {
            if (this.currentStep < 2) {
              this.currentStep++;
            } else {
              await this.finishWelcome();
            }
          })
      }
      .width('100%')

      Text($r('app.string.welcome_hint'))
        .fontSize(12)
        .fontColor($r('app.color.colorText4'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })
    }
    .width('100%')
    .height(UiStyle.BOTTOM_ACTION_HEIGHT)
    .constraintSize({ maxWidth: this.getContentMaxWidth() })
    .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE, top: 12, bottom: 18 })
    .backgroundColor(this.getGlassCardColor())
  }
}
