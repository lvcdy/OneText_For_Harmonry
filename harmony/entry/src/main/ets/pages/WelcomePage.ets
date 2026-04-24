import { promptAction } from '@kit.ArkUI';
import { PreferencesUtil } from '../common/PreferencesUtil';

/**
 * 首次启动引导页 - 对齐原版 WelcomeActivity 的核心流程
 */
@Component
export struct WelcomePageContent {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @State currentStep: number = 0;

  private prefs: PreferencesUtil = PreferencesUtil.getInstance();

  private async finishWelcome(): Promise<void> {
    await this.prefs.putBoolean('first_run', false);
    this.navPathStack.pop();
    promptAction.showToast({ message: $r('app.string.welcome_done') });
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text($r('app.string.welcome_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.colorText1'))
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 24, bottom: 16 })

        Column() {
          Text($r('app.string.welcome_subtitle'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.colorPrimary'))
            .width('100%')
            .margin({ bottom: 12 })

          Text($r('app.string.welcome_intro'))
            .fontSize(15)
            .fontColor($r('app.color.colorText2'))
            .lineHeight(24)

          Text(`Step ${this.currentStep + 1}/3`)
            .fontSize(12)
            .fontColor($r('app.color.colorText4'))
            .margin({ top: 12 })
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('app.color.colorCard'))
        .borderRadius(16)
        .margin({ left: 16, right: 16 })

        Column() {
          this.StepItem($r('app.string.welcome_step1_title'), $r('app.string.welcome_step1_desc'))
          this.StepItem($r('app.string.welcome_step2_title'), $r('app.string.welcome_step2_desc'))
          this.StepItem($r('app.string.welcome_step3_title'), $r('app.string.welcome_step3_desc'))
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('app.color.colorCard'))
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 16 })

        Row() {
          Button($r('app.string.welcome_skip'))
            .type(ButtonType.Normal)
            .borderRadius(8)
            .fontSize(14)
            .fontColor($r('app.color.colorText2'))
            .backgroundColor($r('app.color.colorCard'))
            .height(40)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(async () => {
              await this.finishWelcome();
            })

          Button($r('app.string.welcome_next'))
            .type(ButtonType.Normal)
            .borderRadius(8)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.colorPrimary'))
            .height(40)
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
        .padding({ left: 16, right: 16, top: 20 })

        Text($r('app.string.welcome_hint'))
          .fontSize(12)
          .fontColor($r('app.color.colorText4'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 12, left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.colorBackground'))
      .padding({ bottom: 24 })
    }
    .hideTitleBar(true)
  }

  @Builder
  StepItem(title: Resource, desc: Resource) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.colorText1'))
        .width('100%')
      Text(desc)
        .fontSize(13)
        .fontColor($r('app.color.colorText3'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 6 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }
}
