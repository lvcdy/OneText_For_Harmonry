import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { CoreUtil } from '../common/CoreUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { OneTextItem } from '../model/DataModels';
import { componentSnapshot } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { SettingsPageContent } from './SettingsPage';
import { AboutPageContent } from './AboutPage';
import { EditFeedPageContent } from './EditFeedPage';

/**
 * 主页面 - 元服务入口页面
 * 展示一言内容，支持刷新、保存截图、分享等功能
 * 使用 Navigation + NavDestination 导航模式
 */
@Entry
@Component
struct Index {
  @State oneText: OneTextItem = {
    text: '',
    by: '',
    from: '',
    time: '',
    uri: '',
    quote1: '\u201C',
    quote2: '\u201D'
  };
  @State isLoading: boolean = true;
  @State textFontSize: number = 23;
  @State byFontSize: number = 18;
  @State timeFontSize: number = 15;
  @State fromFontSize: number = 15;
  @State showSizeControls: boolean = false;
  @State sealVisible: boolean = false;
  @State isLeftHandHeld: boolean = false;
  @State isRefreshing: boolean = false;
  @Provide('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private holdingHandCallback = (status: motion.HoldingHandStatus): void => {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      this.updateGripSide(true);
    } else if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD || status === motion.HoldingHandStatus.BOTH_HANDS_HELD) {
      this.updateGripSide(false);
    }
  };

  async aboutToAppear(): Promise<void> {
    // 加载偏好设置
    this.textFontSize = await this.prefs.getNumber('onetext_text_size', 23);
    this.byFontSize = await this.prefs.getNumber('onetext_by_size', 18);
    this.timeFontSize = await this.prefs.getNumber('onetext_time_size', 15);
    this.fromFontSize = await this.prefs.getNumber('onetext_from_size', 15);
    this.sealVisible = await this.prefs.getBoolean('seal_enabled', false);

    // 初始化订阅源
    await this.coreUtil.initFeedFile();

    // 加载一言
    await this.loadOneText(false);
    this.startGripAwareness();
  }

  aboutToDisappear(): void {
    try {
      motion.off('holdingHandChanged', this.holdingHandCallback);
    } catch (e) {
      console.warn('Index', `holdingHandChanged off skipped: ${JSON.stringify(e)}`);
    }
  }

  private startGripAwareness(): void {
    try {
      motion.on('holdingHandChanged', this.holdingHandCallback);
    } catch (e) {
      console.warn('Index', `holdingHandChanged unsupported or permission denied: ${JSON.stringify(e)}`);
    }
  }

  private updateGripSide(leftHandHeld: boolean): void {
    if (this.isLeftHandHeld === leftHandHeld) {
      return;
    }
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.isLeftHandHeld = leftHandHeld;
    });
  }

  private async refreshByPull(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    await this.loadOneText(true);
    this.isRefreshing = false;
  }

  /**
   * 加载一言数据
   */
  private async loadOneText(forceRefresh: boolean): Promise<void> {
    this.isLoading = true;
    try {
      const feedCode = await this.prefs.getNumber('feed_code', 0);
      const feedMap = await this.coreUtil.getFeedInformation(feedCode);

      if (feedMap.feed_type === 'internet') {
        const apiString = await this.prefs.getString('api_string', '');
        const shouldUpdate = await this.coreUtil.ifOneTextShouldUpdate(false);
        if (apiString === '' || shouldUpdate || forceRefresh) {
          this.oneText = await this.coreUtil.getOneTextFromApi(feedMap);
          await this.coreUtil.refreshLatestRefreshTime();
        } else {
          try {
            const jsonObj = JSON.parse(apiString) as Record<string, string>;
            this.oneText = this.coreUtil.convertOneText(jsonObj, feedMap);
          } catch (e) {
            this.oneText = await this.coreUtil.getOneTextFromApi(feedMap);
          }
        }
      } else {
        const initSuccess = await this.coreUtil.initOneText();
        if (initSuccess) {
          this.oneText = await this.coreUtil.getOneText(forceRefresh, false);
          await this.coreUtil.runOneTextUpdate();
        } else {
          promptAction.showToast({ message: $r('app.string.init_failed') });
        }
      }
    } catch (e) {
      console.error('Index', `loadOneText error: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: $r('app.string.refresh_failed') });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 复制文本到剪贴板
   */
  private copyToClipboard(text: string): void {
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setDataSync(pasteData);
    promptAction.showToast({ message: $r('app.string.copied') });
  }

  /**
   * 保存截图
   */
  private async saveScreenshot(): Promise<void> {
    try {
      const pixelMap = await componentSnapshot.get('onetext_card');
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const file = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY);
      const packer = image.createImagePacker();
      const data = await packer.packing(pixelMap, { format: 'image/jpeg', quality: 100 });
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      promptAction.showToast({ message: $r('app.string.save_succeed') });
    } catch (e) {
      console.error('Index', `saveScreenshot error: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: $r('app.string.save_fail') });
    }
  }

  build() {
    Navigation(this.navPathStack) {
      Column() {
        // 顶部标题栏
        Row() {
          Column() {
            Text('OneText')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.colorText1'))

            Text('把一句话留在今天')
              .fontSize(13)
              .fontColor($r('app.color.colorText4'))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Image($r('app.media.ic_heart'))
            .width(28)
            .height(28)
            .margin({ right: 18 })

          Image($r('app.media.ic_settings'))
            .width(28)
            .height(28)
            .onClick(() => {
              this.navPathStack.pushPathByName('SettingsPage', null);
            })
        }
        .width('100%')
        .height(112)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 24, right: 24, top: 36 })

      // 主内容区域
      Refresh({ refreshing: $$this.isRefreshing, offset: 72 }) {
        Scroll() {
          Column() {
          // 一言卡片
          Column() {
            // 加载指示器
            if (this.isLoading) {
              LoadingProgress()
                .width(40)
                .height(40)
                .color($r('app.color.colorPrimary'))
            }

            // 一言内容卡片（可截图区域）
            Stack() {
              Column() {
              }
                .width(190)
                .height(190)
                .backgroundColor('#EEF3FF')
                .borderRadius(95)
                .opacity(0.78)
                .position({ x: -54, y: -62 })
                .zIndex(0)

              Column() {
              }
                .width(120)
                .height(120)
                .backgroundColor('#F7FAFF')
                .borderRadius(60)
                .opacity(0.9)
                .position({ x: 248, y: 202 })
                .zIndex(0)

              if (this.sealVisible) {
                Image($r('app.media.moemiku'))
                  .width(158)
                  .height(158)
                  .opacity(0.42)
                  .position({ x: 198, y: 112 })
                  .zIndex(1)
              }

              if (this.oneText.text !== '') {
                Column() {
                  Text(this.oneText.text.replace(CoreUtil.TEXT_REPLACE_HOLDER, CoreUtil.TEXT_REPLACE))
                    .fontSize(this.textFontSize)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.colorText1'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .lineHeight(this.textFontSize * 1.55)
                    .maxLines(4)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .onClick(() => {
                      this.copyToClipboard(this.oneText.text);
                    })

                  if (this.oneText.by !== '') {
                    Text(`-- ${this.oneText.by}`)
                      .fontSize(this.byFontSize)
                      .fontColor($r('app.color.colorText3'))
                      .textAlign(TextAlign.Center)
                      .margin({ top: 18 })
                      .onClick(() => {
                        this.copyToClipboard(this.oneText.by);
                      })
                  }

                  if (this.oneText.from !== '' || this.oneText.time !== '') {
                    Text(this.oneText.from !== '' ? this.oneText.from : this.oneText.time)
                      .fontSize(this.fromFontSize)
                      .fontColor($r('app.color.colorText4'))
                      .textAlign(TextAlign.Center)
                      .margin({ top: 18 })
                      .onClick(() => {
                        this.copyToClipboard(this.oneText.from !== '' ? this.oneText.from : this.oneText.time);
                      })
                  }
                }
                .width('100%')
                .height('100%')
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .padding({ left: 24, right: 24, top: 24, bottom: 24 })
                .zIndex(2)
              }
            }
            .id('onetext_card')
            .width('100%')
            .height(286)
            .backgroundColor($r('app.color.colorCard'))
            .borderRadius(28)
            .shadow({ radius: 24, color: '#14000000', offsetX: 0, offsetY: 10 })
          }
          .width('100%')
          .padding({ top: 0 })

          Column() {
            this.ActionRow($r('app.string.save_text'), $r('app.string.save_button'), () => {
              this.saveScreenshot();
            })

            this.ActionRow($r('app.string.refresh_onetext_text'), $r('app.string.refresh_button'), () => {
              this.loadOneText(true);
            })

            this.ActionRow($r('app.string.seal_text'), this.sealVisible ? $r('app.string.seal_button_ison') : $r('app.string.seal_button_isoff'), async () => {
              this.sealVisible = !this.sealVisible;
              await this.prefs.putBoolean('seal_enabled', this.sealVisible);
              promptAction.showToast({ message: this.sealVisible ? $r('app.string.seal_button_ison') : $r('app.string.seal_button_isoff') });
            })

            this.TextSizeSlider()
            this.BySizeSlider()
            this.TimeSizeSlider()
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 26, bottom: 24 })
          .margin({ top: 18 })
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(24)
          .shadow({ radius: 18, color: '#10000000', offsetX: 0, offsetY: 8 })
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 46, top: 8 })
        }
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .layoutWeight(1)
      .pullDownRatio(0.72)
      .refreshOffset(72)
      .onRefreshing(() => {
        this.refreshByPull();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.colorBackground'))
    }
    .hideTitleBar(true)
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
  }

  @Builder
  PageMap(name: string) {
    if (name === 'SettingsPage') {
      SettingsPageContent()
    } else if (name === 'AboutPage') {
      AboutPageContent()
    } else if (name === 'EditFeedPage') {
      EditFeedPageContent()
    }
  }

  @Builder
  ActionRow(label: ResourceStr, buttonText: ResourceStr, onClick: () => void) {
    Flex({
      direction: this.isLeftHandHeld ? FlexDirection.Row : FlexDirection.RowReverse,
      alignItems: ItemAlign.Center
    }) {
      Column() {
        this.ActionButton(buttonText, onClick)
      }
      .width(96)

      Text(label)
        .fontSize(18)
        .fontColor($r('app.color.colorText2'))
        .layoutWeight(1)
        .margin(this.isLeftHandHeld ? { left: 20, right: 0 } : { left: 0, right: 20 })
        .textAlign(this.isLeftHandHeld ? TextAlign.Start : TextAlign.Start)
    }
    .width('100%')
    .height(60)
    .padding({ bottom: 14 })
    .animation({ duration: 360, curve: Curve.Friction })
  }

  @Builder
  ActionButton(buttonText: ResourceStr, onClick: () => void) {
    Button(buttonText)
      .type(ButtonType.Normal)
      .borderRadius(21)
      .fontSize(14)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.colorPrimary'))
      .width(96)
      .height(44)
      .onClick(() => {
        onClick();
      })
  }

  @Builder
  TextSizeSlider() {
    Row() {
      Slider({
        value: this.textFontSize,
        min: 12,
        max: 48,
        step: 1,
        style: SliderStyle.OutSet
      })
        .layoutWeight(1)
        .blockColor($r('app.color.colorPrimary'))
        .trackColor($r('app.color.colorMD2BG'))
        .selectedColor($r('app.color.colorPrimary'))
        .onChange((value: number) => {
          this.textFontSize = value;
          this.prefs.putNumber('onetext_text_size', value);
        })
        .margin({ left: 36, right: 24 })

      Text($r('app.string.default_text'))
        .fontSize(14)
        .fontColor($r('app.color.colorPrimary'))
        .width(82)
        .height(38)
        .textAlign(TextAlign.Center)
        .borderRadius(19)
        .backgroundColor('#EEF3FF')
        .padding({ top: 10 })
        .onClick(() => {
          this.textFontSize = 23;
          this.prefs.putNumber('onetext_text_size', 23);
        })
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  @Builder
  BySizeSlider() {
    Row() {
      Slider({ value: this.byFontSize, min: 8, max: 36, step: 1, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .blockColor($r('app.color.colorPrimary'))
        .trackColor($r('app.color.colorMD2BG'))
        .selectedColor($r('app.color.colorPrimary'))
        .onChange((value: number) => {
          this.byFontSize = value;
          this.prefs.putNumber('onetext_by_size', value);
        })
        .margin({ left: 36, right: 24 })

      Text($r('app.string.default_text'))
        .fontSize(14)
        .fontColor($r('app.color.colorPrimary'))
        .width(82)
        .height(38)
        .textAlign(TextAlign.Center)
        .borderRadius(19)
        .backgroundColor('#EEF3FF')
        .padding({ top: 10 })
        .onClick(() => {
          this.byFontSize = 18;
          this.prefs.putNumber('onetext_by_size', 18);
        })
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  @Builder
  TimeSizeSlider() {
    Row() {
      Slider({ value: this.timeFontSize, min: 8, max: 24, step: 1, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .blockColor($r('app.color.colorPrimary'))
        .trackColor($r('app.color.colorMD2BG'))
        .selectedColor($r('app.color.colorPrimary'))
        .onChange((value: number) => {
          this.timeFontSize = value;
          this.fromFontSize = value;
          this.prefs.putNumber('onetext_time_size', value);
          this.prefs.putNumber('onetext_from_size', value);
        })
        .margin({ left: 36, right: 24 })

      Text($r('app.string.default_text'))
        .fontSize(14)
        .fontColor($r('app.color.colorPrimary'))
        .width(82)
        .height(38)
        .textAlign(TextAlign.Center)
        .borderRadius(19)
        .backgroundColor('#EEF3FF')
        .padding({ top: 10 })
        .onClick(() => {
          this.timeFontSize = 15;
          this.fromFontSize = 15;
          this.prefs.putNumber('onetext_time_size', 15);
          this.prefs.putNumber('onetext_from_size', 15);
        })
    }
    .width('100%')
    .padding({ bottom: 16 })
  }
}
