import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { CoreUtil } from '../common/CoreUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { OneTextItem, FeedConfig } from '../model/DataModels';
import { componentSnapshot, image } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

/**
 * 主页面 - 替代 Android MainActivity
 * 展示一言内容，支持刷新、保存截图、分享等功能
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
  @State textFontSize: number = 24;
  @State byFontSize: number = 16;
  @State timeFontSize: number = 12;
  @State fromFontSize: number = 12;
  @State showSizeControls: boolean = false;
  @State sealVisible: boolean = false;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();

  async aboutToAppear(): Promise<void> {
    // 加载偏好设置
    this.textFontSize = await this.prefs.getNumber('onetext_text_size', 24);
    this.byFontSize = await this.prefs.getNumber('onetext_by_size', 16);
    this.timeFontSize = await this.prefs.getNumber('onetext_time_size', 12);
    this.fromFontSize = await this.prefs.getNumber('onetext_from_size', 12);
    this.sealVisible = await this.prefs.getBoolean('seal_enabled', false);

    // 初始化订阅源
    await this.coreUtil.initFeedFile();

    // 加载一言
    await this.loadOneText(false);
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
        // API 类型订阅源
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
        // 远程/本地类型订阅源
        const initSuccess = await this.coreUtil.initOneText();
        if (initSuccess) {
          this.oneText = await this.coreUtil.getOneText(forceRefresh, false);
          // 后台更新检查
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
      const file = await import('@kit.CoreFileKit').then(m => m.fileIo.openSync(uri, 0x2));
      const packer = image.createImagePacker();
      const data = await packer.packing(pixelMap, { format: 'image/jpeg', quality: 100 });
      const { fileIo } = await import('@kit.CoreFileKit');
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      promptAction.showToast({ message: $r('app.string.save_succeed') });
    } catch (e) {
      console.error('Index', `saveScreenshot error: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: $r('app.string.save_fail') });
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('OneText')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))

        Blank()

        Image($r('app.media.ic_settings'))
          .width(24)
          .height(24)
          .onClick(() => {
            router.pushUrl({ url: 'pages/SettingsPage' });
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // 主内容区域 - 可滚动
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
            Column() {
              // 引号和文本
              if (this.oneText.text !== '') {
                Text(this.oneText.quote1)
                  .fontSize(this.textFontSize)
                  .fontColor($r('app.color.colorText1'))
                  .width('100%')
                  .textAlign(TextAlign.Start)

                Text(this.oneText.text.replace(CoreUtil.TEXT_REPLACE_HOLDER, CoreUtil.TEXT_REPLACE))
                  .fontSize(this.textFontSize)
                  .fontColor($r('app.color.colorText1'))
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .lineHeight(this.textFontSize * 1.8)
                  .padding({ top: 8, bottom: 8 })
                  .onClick(() => {
                    this.copyToClipboard(this.oneText.text);
                  })

                Text(this.oneText.quote2)
                  .fontSize(this.textFontSize)
                  .fontColor($r('app.color.colorText1'))
                  .width('100%')
                  .textAlign(TextAlign.End)
              }

              // 作者
              if (this.oneText.by !== '') {
                Text(`—— ${this.oneText.by}`)
                  .fontSize(this.byFontSize)
                  .fontColor($r('app.color.colorText2'))
                  .width('100%')
                  .textAlign(TextAlign.End)
                  .margin({ top: 16 })
                  .onClick(() => {
                    this.copyToClipboard(this.oneText.by);
                  })
              }

              // 时间
              if (this.oneText.time !== '') {
                Text(this.oneText.time)
                  .fontSize(this.timeFontSize)
                  .fontColor($r('app.color.colorText4'))
                  .width('100%')
                  .textAlign(TextAlign.End)
                  .margin({ top: 8 })
                  .onClick(() => {
                    this.copyToClipboard(this.oneText.time);
                  })
              }

              // 来源
              if (this.oneText.from !== '') {
                Text(this.oneText.from)
                  .fontSize(this.fromFontSize)
                  .fontColor($r('app.color.colorText3'))
                  .width('100%')
                  .textAlign(TextAlign.End)
                  .margin({ top: 4 })
                  .onClick(() => {
                    this.copyToClipboard(this.oneText.from);
                  })
              }

              // 印章图片（miku）
              if (this.sealVisible) {
                Image($r('app.media.green_android'))
                  .width(80)
                  .height(80)
                  .margin({ top: 16 })
                  .alignSelf(ItemAlign.End)
              }
            }
            .id('onetext_card')
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.colorCard'))
            .borderRadius(16)
            .shadow({
              radius: 8,
              color: '#1A000000',
              offsetX: 0,
              offsetY: 2
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })

          // 操作按钮行
          Row() {
            Button($r('app.string.save_button'))
              .type(ButtonType.Normal)
              .borderRadius(8)
              .fontSize(14)
              .fontColor($r('app.color.colorText1'))
              .backgroundColor($r('app.color.colorCard'))
              .height(40)
              .layoutWeight(1)
              .margin({ right: 8 })
              .onClick(() => {
                this.saveScreenshot();
              })

            Button($r('app.string.refresh_button'))
              .type(ButtonType.Normal)
              .borderRadius(8)
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.colorPrimary'))
              .height(40)
              .layoutWeight(1)
              .margin({ left: 4, right: 4 })
              .onClick(() => {
                this.loadOneText(true);
              })

            Button(this.sealVisible ? '隐藏' : '印章')
              .type(ButtonType.Normal)
              .borderRadius(8)
              .fontSize(14)
              .fontColor($r('app.color.colorText1'))
              .backgroundColor($r('app.color.colorCard'))
              .height(40)
              .layoutWeight(1)
              .margin({ left: 8 })
              .onClick(async () => {
                this.sealVisible = !this.sealVisible;
                await this.prefs.putBoolean('seal_enabled', this.sealVisible);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16 })

          // 字体大小控制区域
          Column() {
            Row() {
              Text('字体大小设置')
                .fontSize(14)
                .fontColor($r('app.color.colorText2'))
              Blank()
              Image($r('app.media.ic_expand'))
                .width(20)
                .height(20)
                .rotate({ angle: this.showSizeControls ? 180 : 0 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })
            .onClick(() => {
              this.showSizeControls = !this.showSizeControls;
            })

            if (this.showSizeControls) {
              Column() {
                // 一言字体大小
                this.SizeSlider('一言大小', this.textFontSize, 12, 48, (value: number) => {
                  this.textFontSize = value;
                  this.prefs.putNumber('onetext_text_size', value);
                })
                // 作者字体大小
                this.SizeSlider('作者大小', this.byFontSize, 8, 36, (value: number) => {
                  this.byFontSize = value;
                  this.prefs.putNumber('onetext_by_size', value);
                })
                // 时间字体大小
                this.SizeSlider('时间大小', this.timeFontSize, 8, 24, (value: number) => {
                  this.timeFontSize = value;
                  this.prefs.putNumber('onetext_time_size', value);
                })
                // 来源字体大小
                this.SizeSlider('来源大小', this.fromFontSize, 8, 24, (value: number) => {
                  this.fromFontSize = value;
                  this.prefs.putNumber('onetext_from_size', value);
                })
              }
              .padding({ left: 16, right: 16, bottom: 16 })
              .transition({ type: TransitionType.Insert, opacity: 0 })
            }
          }
          .width('100%')
          .margin({ top: 16 })
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 16 })
        }
        .width('100%')
        .padding({ bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.colorBackground'))
  }

  @Builder
  SizeSlider(label: string, currentValue: number, min: number, max: number, onChange: (value: number) => void) {
    Row() {
      Text(`${label}: ${Math.round(currentValue)}`)
        .fontSize(13)
        .fontColor($r('app.color.colorText3'))
        .width(100)

      Slider({
        value: currentValue,
        min: min,
        max: max,
        step: 1,
        style: SliderStyle.OutSet
      })
        .layoutWeight(1)
        .blockColor($r('app.color.colorPrimary'))
        .trackColor($r('app.color.colorMD2BG'))
        .selectedColor($r('app.color.colorPrimary'))
        .onChange((value: number) => {
          onChange(value);
        })

      Text($r('app.string.default_text'))
        .fontSize(12)
        .fontColor($r('app.color.colorPrimary'))
        .onClick(() => {
          if (label.includes('一言')) onChange(24);
          else if (label.includes('作者')) onChange(16);
          else onChange(12);
        })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }
}
