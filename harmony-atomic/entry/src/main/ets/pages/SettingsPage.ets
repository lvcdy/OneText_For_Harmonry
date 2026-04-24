import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { motion } from '@kit.MultimodalAwarenessKit';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { CoreUtil } from '../common/CoreUtil';
import { FeedConfig, FeedItem } from '../model/DataModels';

/**
 * 设置页面 - 元服务版
 * 使用 NavDestination 作为导航目的地
 */
@Component
export struct SettingsPageContent {
  @State displayModeIndex: number = 0;
  @State chineseTypeIndex: number = 0;
  @State feedAutoUpdate: boolean = true;
  @State feedRefreshTime: number = 1;
  @State widgetDark: boolean = false;
  @State widgetShadow: boolean = true;
  @State widgetCenter: boolean = true;
  @State widgetRefreshTime: number = 30;
  @State feedList: FeedItem[] = [];
  @State selectedFeedIndex: number = 0;
  @State isLeftHandHeld: boolean = false;
  @Consume('navPathStack') navPathStack: NavPathStack;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private displayModes: string[] = ['跟随系统', '浅色模式', '深色模式'];
  private chineseTypes: string[] = ['自动', '简体', '繁体', '港繁', '台繁'];
  private holdingHandCallback = (status: motion.HoldingHandStatus): void => {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      this.updateGripSide(true);
    } else if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD || status === motion.HoldingHandStatus.BOTH_HANDS_HELD) {
      this.updateGripSide(false);
    }
  };

  async aboutToAppear(): Promise<void> {
    this.displayModeIndex = await this.prefs.getNumber('interface_daynight', 0);
    this.chineseTypeIndex = await this.prefs.getNumber('chinese_type', 0);
    this.feedAutoUpdate = await this.prefs.getBoolean('feed_auto_update', true);
    this.feedRefreshTime = await this.prefs.getNumber('feed_refresh_time', 1);
    this.widgetDark = await this.prefs.getBoolean('widget_dark', false);
    this.widgetShadow = await this.prefs.getBoolean('widget_shadow', true);
    this.widgetCenter = await this.prefs.getBoolean('widget_center', true);
    this.widgetRefreshTime = await this.prefs.getNumber('widget_refresh_time', 30);
    this.selectedFeedIndex = await this.prefs.getNumber('feed_code', 0);
    await this.loadFeedList();
    this.startGripAwareness();
  }

  aboutToDisappear(): void {
    try {
      motion.off('holdingHandChanged', this.holdingHandCallback);
    } catch (e) {
      console.warn('SettingsPage', `holdingHandChanged off skipped: ${JSON.stringify(e)}`);
    }
  }

  private startGripAwareness(): void {
    try {
      motion.on('holdingHandChanged', this.holdingHandCallback);
    } catch (e) {
      console.warn('SettingsPage', `holdingHandChanged unsupported or permission denied: ${JSON.stringify(e)}`);
    }
  }

  private updateGripSide(leftHandHeld: boolean): void {
    if (this.isLeftHandHeld === leftHandHeld) {
      return;
    }
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.isLeftHandHeld = leftHandHeld;
    });
  }

  private async loadFeedList(): Promise<void> {
    const feeds = this.coreUtil.getAllFeeds();
    this.feedList = feeds.map((feed: FeedConfig, index: number) => ({
      name: feed.feed_name,
      selected: index === this.selectedFeedIndex,
      index: index
    } as FeedItem));
  }

  private async selectFeed(index: number): Promise<void> {
    const oldIndex = this.selectedFeedIndex;
    if (oldIndex !== index) {
      const oldFeed = await this.coreUtil.getFeedInformation(oldIndex);
      if (oldFeed.feed_type === 'remote') {
        const cachePath = `${this.context.filesDir}/OneText/OneText-Library.json`;
        try {
          fileIo.unlinkSync(cachePath);
        } catch (e) {
          // 忽略
        }
      }
    }
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.selectedFeedIndex = index;
    });
    await this.prefs.putNumber('feed_code', index);
    await this.prefs.remove('onetext_code');
    await this.prefs.remove('api_string');
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.feedList = this.feedList.map((item: FeedItem) => ({
        name: item.name,
        selected: item.index === index,
        index: item.index
      } as FeedItem));
    });
    promptAction.showToast({ message: $r('app.string.succeed') });
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部标题栏
        Row() {
          Image($r('app.media.ic_back'))
            .width(22)
            .height(22)
            .onClick(() => {
              this.navPathStack.pop();
            })
            .padding(12)
            .backgroundColor($r('app.color.colorCard'))
            .borderRadius(23)

        Text($r('app.string.setting_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 18, right: 18 })

      // 设置内容
      Scroll() {
        Column() {
          Column() {
            this.SectionTitle($r('app.string.interface_text'))
            Row() {
              if (this.isLeftHandHeld) {
                this.DisplayModeSelect()
                Blank()
                this.SettingLabel($r('app.string.interface_daynight'))
              } else {
                this.SettingLabel($r('app.string.interface_daynight'))
                Blank()
                this.DisplayModeSelect()
              }
            }
            .width('100%')
            .height(54)
            .padding({ left: 20, right: 20 })

            this.SettingDivider()

            Row() {
              if (this.isLeftHandHeld) {
                this.ChineseTypeSelect()
                Blank()
                this.SettingLabel($r('app.string.chinese_type'))
              } else {
                this.SettingLabel($r('app.string.chinese_type'))
                Blank()
                this.ChineseTypeSelect()
              }
            }
            .width('100%')
            .height(54)
            .padding({ left: 20, right: 20 })
          }
          .width('100%')
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(24)
          .margin({ bottom: 14 })

          Column() {
            Row() {
              if (this.isLeftHandHeld) {
                this.EditFeedIcon()
                Text($r('app.string.feed_text'))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.colorText2'))
                  .layoutWeight(1)
                  .margin({ left: 16 })
              } else {
                Text($r('app.string.feed_text'))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.colorText2'))
                  .layoutWeight(1)
                this.EditFeedIcon()
              }
            }
            .width('100%')
            .height(58)
            .padding({ left: 20, right: 20 })

            this.SettingDivider()

            ForEach(this.feedList, (item: FeedItem) => {
              Row() {
                if (this.isLeftHandHeld) {
                  this.FeedRadio(item)
                  this.FeedNameAfterControl(item)
                } else {
                  this.FeedNameBeforeControl(item)
                  this.FeedRadio(item)
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .margin({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(18)
              .backgroundColor(item.selected ? '#EEF3FF' : '#00FFFFFF')
              .animation({ duration: 200, curve: Curve.EaseOut })
              .onClick(async () => {
                await this.selectFeed(item.index);
              })
            })

            this.SettingDivider()

            this.SettingSwitch($r('app.string.feed_auto_update'), this.feedAutoUpdate, async (value: boolean) => {
              this.feedAutoUpdate = value;
              await this.prefs.putBoolean('feed_auto_update', value);
            })

            this.SettingDivider()

            Row() {
              Text($r('app.string.feed_refresh_text'))
                .fontSize(14)
                .fontColor($r('app.color.colorText3'))
                .width(120)
              Slider({ value: this.feedRefreshTime, min: 1, max: 24, step: 1, style: SliderStyle.OutSet })
                .layoutWeight(1)
                .blockColor($r('app.color.colorPrimary'))
                .trackColor($r('app.color.colorMD2BG'))
                .selectedColor($r('app.color.colorPrimary'))
                .onChange(async (value: number) => {
                  animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
                    this.feedRefreshTime = value;
                  });
                  await this.prefs.putNumber('feed_refresh_time', value);
                })
              Text(`${Math.round(this.feedRefreshTime)} H`)
                .fontSize(13)
                .fontColor($r('app.color.colorText3'))
                .width(50)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .height(56)
            .padding({ left: 20, right: 20 })
          }
          .width('100%')
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(24)
          .margin({ bottom: 14 })

          Column() {
            this.SectionTitle($r('app.string.widget_text'))
            this.SettingSwitch($r('app.string.widget_dark'), this.widgetDark, async (value: boolean) => {
              this.widgetDark = value;
              await this.prefs.putBoolean('widget_dark', value);
            })
            this.SettingDivider()
            this.SettingSwitch($r('app.string.widget_shadow'), this.widgetShadow, async (value: boolean) => {
              this.widgetShadow = value;
              await this.prefs.putBoolean('widget_shadow', value);
            })
            this.SettingDivider()
            this.SettingSwitch($r('app.string.widget_center'), this.widgetCenter, async (value: boolean) => {
              this.widgetCenter = value;
              await this.prefs.putBoolean('widget_center', value);
            })
            this.SettingDivider()
            Row() {
              Text($r('app.string.widget_refresh_text'))
                .fontSize(14)
                .fontColor($r('app.color.colorText3'))
                .width(140)
              Slider({ value: this.widgetRefreshTime, min: 10, max: 120, step: 10, style: SliderStyle.OutSet })
                .layoutWeight(1)
                .blockColor($r('app.color.colorPrimary'))
                .trackColor($r('app.color.colorMD2BG'))
                .selectedColor($r('app.color.colorPrimary'))
                .onChange(async (value: number) => {
                  animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
                    this.widgetRefreshTime = value;
                  });
                  await this.prefs.putNumber('widget_refresh_time', value);
                })
              Text(`${Math.round(this.widgetRefreshTime)} MIN`)
                .fontSize(13)
                .fontColor($r('app.color.colorText3'))
                .width(60)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .height(56)
            .padding({ left: 20, right: 20 })
          }
          .width('100%')
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(24)
          .margin({ bottom: 14 })

          Column() {
            Row() {
              Text($r('app.string.about_text'))
                .fontSize(15)
                .fontColor($r('app.color.colorText3'))
              Blank()
              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .opacity(0.55)
            }
            .width('100%')
            .height(56)
            .padding({ left: 20, right: 20 })
            .onClick(() => {
              this.navPathStack.pushPathByName('AboutPage', null);
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(24)
        }
        .width('100%')
        .padding({ top: 16, bottom: 28 })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 18, right: 18 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 36 })
      .backgroundColor($r('app.color.colorBackground'))
    }
    .hideTitleBar(true)
  }

  @Builder
  SettingLabel(label: Resource) {
    Text(label)
      .fontSize(15)
      .fontColor($r('app.color.colorText3'))
  }

  @Builder
  DisplayModeSelect() {
    Select(this.displayModes.map((item: string) => ({ value: item } as SelectOption)))
      .selected(this.displayModeIndex)
      .value(this.displayModes[this.displayModeIndex])
      .font({ size: 14 })
      .onSelect(async (index: number) => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.displayModeIndex = index;
        });
        await this.prefs.putNumber('interface_daynight', index);
      })
  }

  @Builder
  ChineseTypeSelect() {
    Select(this.chineseTypes.map((item: string) => ({ value: item } as SelectOption)))
      .selected(this.chineseTypeIndex)
      .value(this.chineseTypes[this.chineseTypeIndex])
      .font({ size: 14 })
      .onSelect(async (index: number) => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.chineseTypeIndex = index;
        });
        await this.prefs.putNumber('chinese_type', index);
      })
  }

  @Builder
  EditFeedIcon() {
    Image($r('app.media.ic_edit'))
      .width(20)
      .height(20)
      .opacity(0.65)
      .onClick(() => {
        this.navPathStack.pushPathByName('EditFeedPage', null);
      })
  }

  @Builder
  FeedRadio(item: FeedItem) {
    Radio({ value: item.name, group: 'feed' })
      .checked(item.selected)
      .onChange(async (isChecked: boolean) => {
        if (isChecked) {
          await this.selectFeed(item.index);
        }
      })
  }

  @Builder
  FeedNameAfterControl(item: FeedItem) {
    Text(item.name)
      .fontSize(15)
      .fontColor(item.selected ? $r('app.color.colorPrimary') : $r('app.color.colorText3'))
      .margin({ left: 8, right: 0 })
      .layoutWeight(1)
  }

  @Builder
  FeedNameBeforeControl(item: FeedItem) {
    Text(item.name)
      .fontSize(15)
      .fontColor(item.selected ? $r('app.color.colorPrimary') : $r('app.color.colorText3'))
      .margin({ left: 0, right: 8 })
      .layoutWeight(1)
  }

  @Builder
  SectionTitle(title: Resource) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.colorText2'))
      .width('100%')
      .height(58)
      .padding({ left: 20, right: 20, top: 18 })
  }

  @Builder
  SettingDivider() {
    Divider()
      .color('#08000000')
      .margin({ left: 20, right: 20 })
  }

  @Builder
  SettingSwitch(label: Resource, isOn: boolean, onChange: (value: boolean) => void) {
    Row() {
      if (this.isLeftHandHeld) {
        this.SwitchControl(isOn, onChange)
        Blank()
        this.SettingLabel(label)
      } else {
        this.SettingLabel(label)
        Blank()
        this.SwitchControl(isOn, onChange)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
    .animation({ duration: 180, curve: Curve.EaseOut })
  }

  @Builder
  SwitchControl(isOn: boolean, onChange: (value: boolean) => void) {
    Toggle({ type: ToggleType.Switch, isOn: isOn })
      .selectedColor($r('app.color.colorPrimary'))
      .onChange((isOn: boolean) => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          onChange(isOn);
        });
      })
  }
}
