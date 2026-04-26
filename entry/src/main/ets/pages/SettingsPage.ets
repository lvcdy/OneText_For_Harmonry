import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { AppLanguageUtil } from '../common/AppLanguageUtil';
import { AppDisplayModeUtil } from '../common/AppDisplayModeUtil';
import { PermissionUtil } from '../common/PermissionUtil';
import {
  AppBackgroundLayer,
  AppBackgroundMode,
  AppBackgroundUtil,
  WidgetBackgroundMode,
  WidgetBackgroundUtil
} from '../common/AppBackgroundUtil';
import { CoreUtil } from '../common/CoreUtil';
import { FormUtil } from '../common/FormUtil';
import { GripUtil } from '../common/GripUtil';
import { UiStyle } from '../common/UiStyle';
import { FeedConfig, FeedItem } from '../model/DataModels';

const SETTINGS_RESPONSIVE_WIDE_WIDTH: number = 720;
const SETTINGS_CONTENT_MAX_WIDTH_COMPACT: number = 560;
const SETTINGS_CONTENT_MAX_WIDTH_WIDE: number = 1040;
const SETTINGS_CARD_WIDTH_COMPACT: string = '100%';
const SETTINGS_CARD_WIDTH_WIDE: string = '50%';
const WIDGET_BACKGROUND_TRANSPARENT_INDEX: number = 0;
const WIDGET_BACKGROUND_BLUR_INDEX: number = 1;

/**
 * 设置页面 - 替代 Android SettingActivity
 * HarmonyOS 6: 使用 NavDestination 作为导航目的地
 */
@Component
export struct SettingsPageContent {
  @State displayModeIndex: number = 0;
  @State languageTypeIndex: number = 0;
  @State feedAutoUpdate: boolean = true;
  @State feedRefreshTime: number = 1;
  @State widgetDark: boolean = false;
  @State widgetShadow: boolean = true;
  @State widgetCenter: boolean = true;
  @State widgetRefreshTime: number = 30;
  @State feedList: FeedItem[] = [];
  @State selectedFeedIndex: number = 0;
  @State adaptiveGripEnabled: boolean = true;
  @State isLeftHandHeld: boolean = false;
  @State pageWidth: number = 0;
  @State backgroundModeIndex: number = AppBackgroundMode.DEFAULT;
  @State backgroundApiText: string = '';
  @State widgetBackgroundModeIndex: number = WIDGET_BACKGROUND_TRANSPARENT_INDEX;
  @Consume('navPathStack') navPathStack: NavPathStack;
  @StorageLink('appBackgroundUri') appBackgroundUri: string = '';

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private displayModes: string[] = ['跟随系统', '浅色模式', '深色模式'];
  private languageTypes: string[] = ['中文', '繁中', 'English'];
  private backgroundModes: string[] = ['默认纯色', '本地图片', 'API'];
  private widgetBackgroundModes: string[] = ['透明背板', '模糊背板'];
  private holdingHandCallback = (status: motion.HoldingHandStatus): void => {
    const leftHandHeld = GripUtil.getLeftHandHeld(status);
    if (leftHandHeld !== null) {
      this.updateGripSide(leftHandHeld);
    }
  };

  private isWideLayout(): boolean {
    return this.pageWidth >= SETTINGS_RESPONSIVE_WIDE_WIDTH;
  }

  private getContentMaxWidth(): number {
    return this.isWideLayout() ? SETTINGS_CONTENT_MAX_WIDTH_WIDE : SETTINGS_CONTENT_MAX_WIDTH_COMPACT;
  }

  private getCardWidth(): string {
    return this.isWideLayout() ? SETTINGS_CARD_WIDTH_WIDE : SETTINGS_CARD_WIDTH_COMPACT;
  }

  private getGlassCardColor(): ResourceColor {
    return $r('app.color.colorGlassCard');
  }

  private getGlassCardBorder(): ResourceColor {
    return $r('app.color.colorGlassBorder');
  }

  private getGlassControlColor(): ResourceColor {
    return $r('app.color.colorGlassControl');
  }

  private getGlassSelectedColor(): ResourceColor {
    return $r('app.color.colorGlassSelected');
  }

  private getGlassShadowColor(): ResourceColor {
    return $r('app.color.colorGlassShadow');
  }

  private normalizeWidgetRefreshTime(value: number): number {
    if (value < 30) {
      return 30;
    }
    return Math.min(Math.round(value / 30) * 30, 120);
  }

  async aboutToAppear(): Promise<void> {
    this.displayModeIndex = await this.prefs.getNumber(AppDisplayModeUtil.PREF_KEY, 0);
    this.languageTypeIndex = await this.loadLanguageType();
    this.feedAutoUpdate = await this.prefs.getBoolean('feed_auto_update', true);
    this.feedRefreshTime = await this.prefs.getNumber('feed_refresh_time', 1);
    this.widgetDark = await this.prefs.getBoolean('widget_dark', false);
    this.widgetShadow = await this.prefs.getBoolean('widget_shadow', true);
    this.widgetCenter = await this.prefs.getBoolean('widget_center', true);
    const savedWidgetRefreshTime = await this.prefs.getNumber('widget_refresh_time', 30);
    this.widgetRefreshTime = this.normalizeWidgetRefreshTime(savedWidgetRefreshTime);
    if (this.widgetRefreshTime !== savedWidgetRefreshTime) {
      await this.prefs.putNumber('widget_refresh_time', this.widgetRefreshTime);
    }
    this.selectedFeedIndex = await this.prefs.getNumber('feed_code', 0);
    this.adaptiveGripEnabled = await this.prefs.getBoolean('adaptive_grip_enabled', true);
    await this.loadBackgroundSettings();
    await this.loadWidgetBackgroundSettings();
    await this.loadFeedList();
    if (this.adaptiveGripEnabled) {
      await this.startGripAwareness();
    }
  }

  aboutToDisappear(): void {
    this.stopGripAwareness();
  }

  private stopGripAwareness(): void {
    try {
      motion.off('holdingHandChanged', this.holdingHandCallback);
    } catch (e) {
      console.warn('SettingsPage', `holdingHandChanged off skipped: ${JSON.stringify(e)}`);
    }
  }

  private async startGripAwareness(): Promise<boolean> {
    this.stopGripAwareness();
    const hasPermission = await PermissionUtil.request(this.context, PermissionUtil.DETECT_GESTURE, 'SettingsPage');
    if (!hasPermission) {
      this.applyGripSide(false);
      return false;
    }
    try {
      motion.on('holdingHandChanged', this.holdingHandCallback);
      return true;
    } catch (e) {
      console.warn('SettingsPage', `holdingHandChanged unsupported or permission denied: ${JSON.stringify(e)}`);
      return false;
    }
  }

  private updateGripSide(leftHandHeld: boolean): void {
    if (!this.adaptiveGripEnabled) {
      return;
    }
    this.applyGripSide(leftHandHeld);
  }

  private applyGripSide(leftHandHeld: boolean): void {
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

  private async loadBackgroundSettings(): Promise<void> {
    this.backgroundModeIndex = await AppBackgroundUtil.getMode(this.prefs);
    this.backgroundApiText = await AppBackgroundUtil.getApiUri(this.prefs);
    this.appBackgroundUri = await AppBackgroundUtil.getBackgroundUri(this.prefs);
  }

  private async loadWidgetBackgroundSettings(): Promise<void> {
    const mode = await WidgetBackgroundUtil.getMode(this.prefs);
    this.widgetBackgroundModeIndex =
      mode === WidgetBackgroundMode.BLUR ? WIDGET_BACKGROUND_BLUR_INDEX : WIDGET_BACKGROUND_TRANSPARENT_INDEX;
  }

  private async reloadFeedMenu(): Promise<void> {
    this.selectedFeedIndex = await this.prefs.getNumber('feed_code', 0);
    await this.loadFeedList();
  }

  private async loadLanguageType(): Promise<number> {
    const languageType = await this.prefs.getNumber(AppLanguageUtil.PREF_KEY, -1);
    if (languageType >= 0) {
      return Math.min(languageType, this.languageTypes.length - 1);
    }

    const oldChineseType = await this.prefs.getNumber('chinese_type', 0);
    const migratedLanguageType = oldChineseType <= 1 ? 0 : 1;
    await this.prefs.putNumber(AppLanguageUtil.PREF_KEY, migratedLanguageType);
    return migratedLanguageType;
  }

  private async changeLanguageType(index: number): Promise<void> {
    if (index === this.languageTypeIndex) {
      return;
    }
    this.languageTypeIndex = index;
    await this.prefs.putNumber(AppLanguageUtil.PREF_KEY, index);
    AppLanguageUtil.setPreferredLanguage(index);
    setTimeout(() => {
      this.restartForLanguageChange();
    }, 240);
  }

  private restartForLanguageChange(): void {
    try {
      const abilityInfo = this.context.abilityInfo;
      const want: Want = {
        bundleName: abilityInfo.bundleName,
        moduleName: abilityInfo.moduleName,
        abilityName: abilityInfo.name
      };
      this.context.getApplicationContext().restartApp(want);
    } catch (e) {
      console.error('SettingsPage', `restart for language change failed: ${JSON.stringify(e)}`);
    }
  }

  private async changeBackgroundMode(index: number): Promise<void> {
    if (index === AppBackgroundMode.DEFAULT) {
      this.backgroundModeIndex = AppBackgroundMode.DEFAULT;
      this.appBackgroundUri = await AppBackgroundUtil.setDefault(this.prefs);
      return;
    }

    if (index === AppBackgroundMode.LOCAL_IMAGE) {
      await this.pickBackgroundImage();
      return;
    }

    const apiUri = this.backgroundApiText.trim();
    this.backgroundModeIndex = AppBackgroundMode.IMAGE_API;
    if (apiUri !== '') {
      this.appBackgroundUri = await AppBackgroundUtil.setApi(this.prefs, apiUri);
    }
  }

  private async pickBackgroundImage(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      const uri = result.photoUris.length > 0 ? result.photoUris[0] : '';
      if (uri === '') {
        return;
      }
      this.appBackgroundUri = await AppBackgroundUtil.saveLocalImage(this.context, this.prefs, uri);
      this.backgroundModeIndex = AppBackgroundMode.LOCAL_IMAGE;
      promptAction.showToast({ message: $r('app.string.background_image_selected') });
    } catch (e) {
      console.error('SettingsPage', `pick background image failed: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: $r('app.string.background_image_failed') });
    }
  }

  private async applyBackgroundApi(): Promise<void> {
    const apiUri = this.backgroundApiText.trim();
    if (apiUri === '') {
      promptAction.showToast({ message: $r('app.string.background_api_empty') });
      return;
    }
    this.appBackgroundUri = await AppBackgroundUtil.setApi(this.prefs, apiUri);
    this.backgroundModeIndex = AppBackgroundMode.IMAGE_API;
    promptAction.showToast({ message: $r('app.string.succeed') });
  }

  private async changeWidgetBackgroundMode(index: number): Promise<void> {
    if (index === WIDGET_BACKGROUND_TRANSPARENT_INDEX) {
      this.widgetBackgroundModeIndex = WIDGET_BACKGROUND_TRANSPARENT_INDEX;
      await WidgetBackgroundUtil.setDefault(this.prefs);
      await this.refreshWidgetForms();
      return;
    }

    this.widgetBackgroundModeIndex = WIDGET_BACKGROUND_BLUR_INDEX;
    await WidgetBackgroundUtil.setBlur(this.prefs);
    await this.refreshWidgetForms();
  }

  private async selectFeed(index: number): Promise<void> {
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.selectedFeedIndex = index;
    });
    await this.prefs.putNumber('feed_code', index);
    await this.coreUtil.clearOneTextCache();
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.feedList = this.feedList.map((item: FeedItem) => ({
        name: item.name,
        selected: item.index === index,
        index: item.index
      } as FeedItem));
    });
    await this.refreshWidgetForms();
    promptAction.showToast({ message: $r('app.string.succeed') });
  }

  private async refreshWidgetForms(): Promise<void> {
    try {
      await FormUtil.refreshForms(this.context, this.coreUtil);
    } catch (e) {
      console.error('SettingsPage', `refreshWidgetForms error: ${JSON.stringify(e)}`);
    }
  }

  build() {
    NavDestination() {
      Stack() {
        AppBackgroundLayer()

        Column() {
          this.SettingsHeader()

          Scroll() {
            Column() {
              Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                Column() {
                  this.InterfaceCard()
                }
                .width(this.getCardWidth())
                .padding({ left: this.isWideLayout() ? 8 : 0, right: this.isWideLayout() ? 8 : 0 })

                Column() {
                  this.FeedCard()
                }
                .width(this.getCardWidth())
                .padding({ left: this.isWideLayout() ? 8 : 0, right: this.isWideLayout() ? 8 : 0 })

                Column() {
                  this.WidgetCard()
                }
                .width(this.getCardWidth())
                .padding({ left: this.isWideLayout() ? 8 : 0, right: this.isWideLayout() ? 8 : 0 })

                Column() {
                  this.AboutCard()
                }
                .width(this.getCardWidth())
                .padding({ left: this.isWideLayout() ? 8 : 0, right: this.isWideLayout() ? 8 : 0 })
              }
              .width('100%')
              .constraintSize({ maxWidth: this.getContentMaxWidth() })
              .padding({ top: 0, bottom: 34 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(UiStyle.TRANSPARENT)
    .onShown(() => {
      this.reloadFeedMenu();
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageWidth = Number.parseFloat(String(newValue.width));
    })
  }

  @Builder
  SettingsHeader() {
    Column() {
      Row() {
        Image($r('app.media.ic_back'))
          .width(20)
          .height(20)
          .padding(10)
          .backgroundColor(this.getGlassControlColor())
          .border({ width: 1, color: this.getGlassCardBorder() })
          .borderRadius(22)
          .onClick(() => {
            this.navPathStack.pop();
          })

        Text($r('app.string.setting_title'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ left: 14 })

        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE })
    }
    .width('100%')
    .height(UiStyle.HEADER_HEIGHT)
    .padding({ top: UiStyle.PAGE_TOP })
  }

  @Builder
  InterfaceCard() {
    Column() {
      this.SectionTitle($r('app.string.interface_text'))
      this.DisplayModeRow()
      this.SettingDivider()
      this.LanguageTypeRow()
      this.SettingDivider()
      this.BackgroundModeRow()
      if (this.backgroundModeIndex === AppBackgroundMode.LOCAL_IMAGE) {
        this.SettingDivider()
        this.BackgroundImageRow()
      }
      if (this.backgroundModeIndex === AppBackgroundMode.IMAGE_API) {
        this.SettingDivider()
        this.BackgroundApiRow()
      }
      this.SettingDivider()
      this.SettingSwitch($r('app.string.adaptive_grip'), this.adaptiveGripEnabled, async (value: boolean) => {
        this.adaptiveGripEnabled = value;
        await this.prefs.putBoolean('adaptive_grip_enabled', value);
        if (value) {
          const started = await this.startGripAwareness();
          if (!started) {
            this.adaptiveGripEnabled = false;
            await this.prefs.putBoolean('adaptive_grip_enabled', false);
          }
        } else {
          this.stopGripAwareness();
          this.applyGripSide(false);
        }
      })
    }
    .width('100%')
    .backgroundColor(this.getGlassCardColor())
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 18, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
    .margin({ bottom: UiStyle.CARD_GAP })
  }

  @Builder
  FeedCard() {
    Column() {
      Row() {
        if (this.isLeftHandHeld) {
          this.EditFeedIcon()
          this.CardTitle($r('app.string.feed_text'), 16)
        } else {
          this.CardTitle($r('app.string.feed_text'), 0)
          this.EditFeedIcon()
        }
      }
      .width('100%')
      .height(62)
      .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })

      this.SettingDivider()

      ForEach(this.feedList, (item: FeedItem) => {
        this.FeedRow(item)
      }, (item: FeedItem) => `${item.index}-${item.name}`)

      this.SettingDivider()
      this.SettingSwitch($r('app.string.feed_auto_update'), this.feedAutoUpdate, async (value: boolean) => {
        this.feedAutoUpdate = value;
        await this.prefs.putBoolean('feed_auto_update', value);
      })

      this.SettingDivider()
      this.RefreshSliderRow($r('app.string.feed_refresh_text'), this.feedRefreshTime, 1, 24, 1, 'H',
        async (value: number) => {
          this.feedRefreshTime = value;
          await this.prefs.putNumber('feed_refresh_time', value);
        })
    }
    .width('100%')
    .backgroundColor(this.getGlassCardColor())
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 18, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
    .margin({ bottom: UiStyle.CARD_GAP })
  }

  @Builder
  WidgetCard() {
    Column() {
      this.SectionTitle($r('app.string.widget_text'))
      this.SettingSwitch($r('app.string.widget_dark'), this.widgetDark, async (value: boolean) => {
        this.widgetDark = value;
        await this.prefs.putBoolean('widget_dark', value);
        await this.refreshWidgetForms();
      })
      this.SettingDivider()
      this.SettingSwitch($r('app.string.widget_shadow'), this.widgetShadow, async (value: boolean) => {
        this.widgetShadow = value;
        await this.prefs.putBoolean('widget_shadow', value);
        await this.refreshWidgetForms();
      })
      this.SettingDivider()
      this.SettingSwitch($r('app.string.widget_center'), this.widgetCenter, async (value: boolean) => {
        this.widgetCenter = value;
        await this.prefs.putBoolean('widget_center', value);
        await this.refreshWidgetForms();
      })
      this.SettingDivider()
      this.WidgetBackgroundModeRow()
      this.SettingDivider()
      this.RefreshSliderRow($r('app.string.widget_refresh_text'), this.widgetRefreshTime, 30, 120, 30, 'MIN',
        async (value: number) => {
          this.widgetRefreshTime = value;
          await this.prefs.putNumber('widget_refresh_time', value);
          await this.refreshWidgetForms();
        })
    }
    .width('100%')
    .backgroundColor(this.getGlassCardColor())
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 18, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
    .margin({ bottom: UiStyle.CARD_GAP })
  }

  @Builder
  AboutCard() {
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
      .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })
      .onClick(() => {
        this.navPathStack.pushPathByName('AboutPage', null);
      })
    }
    .width('100%')
    .backgroundColor(this.getGlassCardColor())
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 14, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
  }

  @Builder
  CardTitle(title: Resource, leftMargin: number) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.colorText2'))
      .layoutWeight(1)
      .margin({ left: leftMargin })
  }

  @Builder
  DisplayModeRow() {
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
    .height(UiStyle.LIST_ROW_HEIGHT)
    .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })
  }

  @Builder
  LanguageTypeRow() {
    Row() {
      if (this.isLeftHandHeld) {
        this.LanguageTypeSelect()
        Blank()
        this.SettingLabel($r('app.string.chinese_type'))
      } else {
        this.SettingLabel($r('app.string.chinese_type'))
        Blank()
        this.LanguageTypeSelect()
      }
    }
    .width('100%')
    .height(UiStyle.LIST_ROW_HEIGHT)
    .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })
  }

  @Builder
  FeedRow(item: FeedItem) {
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
    .padding({ left: 18, right: 18 })
    .margin({ left: 10, right: 10, top: 2, bottom: 2 })
    .borderRadius(18)
    .backgroundColor(item.selected ? this.getGlassSelectedColor() : UiStyle.TRANSPARENT)
    .animation({ duration: 200, curve: Curve.EaseOut })
    .onClick(async () => {
      await this.selectFeed(item.index);
    })
  }

  @Builder
  RefreshSliderRow(label: Resource, value: number, min: number, max: number, step: number, unit: string,
    onChange: (value: number) => Promise<void>) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.colorText3'))
        .width(unit === 'H' ? 120 : 140)
      Slider({ value: value, min: min, max: max, step: step, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .blockColor($r('app.color.colorPrimary'))
        .trackColor($r('app.color.colorMD2BG'))
        .selectedColor($r('app.color.colorPrimary'))
        .onChange((nextValue: number) => {
          animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
            onChange(nextValue);
          });
        })
      Text(`${Math.round(value)} ${unit}`)
        .fontSize(13)
        .fontColor($r('app.color.colorText3'))
        .width(unit === 'H' ? 50 : 60)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(56)
    .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })
  }

  @Builder
  SettingLabel(label: Resource) {
    Text(label)
      .fontSize(17)
      .fontColor($r('app.color.colorText3'))
  }

  @Builder
  DisplayModeSelect() {
    Select(this.displayModes.map((item: string) => ({ value: item } as SelectOption)))
      .selected(this.displayModeIndex)
      .value(this.displayModes[this.displayModeIndex])
      .font({ size: 16, weight: FontWeight.Medium })
      .fontColor($r('app.color.colorText2'))
      .backgroundColor(this.getGlassControlColor())
      .borderRadius(24)
      .height(44)
      .onSelect(async (index: number) => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.displayModeIndex = index;
        });
        await this.prefs.putNumber(AppDisplayModeUtil.PREF_KEY, index);
        AppDisplayModeUtil.apply(this.context, index);
      })
  }

  @Builder
  LanguageTypeSelect() {
    Select(this.languageTypes.map((item: string) => ({ value: item } as SelectOption)))
      .selected(this.languageTypeIndex)
      .value(this.languageTypes[this.languageTypeIndex])
      .font({ size: 16, weight: FontWeight.Medium })
      .fontColor($r('app.color.colorText2'))
      .backgroundColor(this.getGlassControlColor())
      .borderRadius(24)
      .height(44)
      .onSelect(async (index: number) => {
        await this.changeLanguageType(index);
      })
  }

  @Builder
  BackgroundModeRow() {
    Row() {
      this.SettingLabel($r('app.string.background_mode'))
      Blank()
      Select(this.backgroundModes.map((item: string) => ({ value: item } as SelectOption)))
        .selected(this.backgroundModeIndex)
        .value(this.backgroundModes[this.backgroundModeIndex])
        .font({ size: 16, weight: FontWeight.Medium })
        .fontColor($r('app.color.colorText2'))
        .backgroundColor(this.getGlassControlColor())
        .borderRadius(24)
        .height(44)
        .onSelect(async (index: number) => {
          await this.changeBackgroundMode(index);
        })
    }
    .width('100%')
    .height(UiStyle.LIST_ROW_HEIGHT)
    .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })
  }

  @Builder
  BackgroundImageRow() {
    Row() {
      this.SettingLabel($r('app.string.background_local_image'))
      Blank()
      Button($r('app.string.background_pick_image'))
        .type(ButtonType.Capsule)
        .height(40)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.colorPrimary'))
        .onClick(async () => {
          await this.pickBackgroundImage();
        })
    }
    .width('100%')
    .height(UiStyle.LIST_ROW_HEIGHT)
    .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })
  }

  @Builder
  BackgroundApiRow() {
    Column() {
      TextInput({ placeholder: $r('app.string.background_api_placeholder'), text: this.backgroundApiText })
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor($r('app.color.colorText2'))
        .backgroundColor(this.getGlassControlColor())
        .borderRadius(22)
        .onChange((value: string) => {
          this.backgroundApiText = value;
        })

      Button($r('app.string.background_apply_api'))
        .type(ButtonType.Capsule)
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.colorPrimary'))
        .margin({ top: 10 })
        .onClick(async () => {
          await this.applyBackgroundApi();
        })
    }
    .width('100%')
    .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE, top: 10, bottom: 14 })
  }

  @Builder
  WidgetBackgroundModeRow() {
    Column() {
      Row() {
        this.SettingLabel($r('app.string.widget_background_mode'))
        Blank()
        Select(this.widgetBackgroundModes.map((item: string) => ({ value: item } as SelectOption)))
          .selected(this.widgetBackgroundModeIndex)
          .value(this.widgetBackgroundModes[this.widgetBackgroundModeIndex])
          .font({ size: 16, weight: FontWeight.Medium })
          .fontColor($r('app.color.colorText2'))
          .backgroundColor(this.getGlassControlColor())
          .borderRadius(24)
          .height(44)
          .onSelect(async (index: number) => {
            await this.changeWidgetBackgroundMode(index);
          })
      }
      .width('100%')
      .height(UiStyle.LIST_ROW_HEIGHT)
      .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE })

      if (this.widgetBackgroundModeIndex === WIDGET_BACKGROUND_BLUR_INDEX) {
        Text($r('app.string.widget_blur_flagship_only'))
          .fontSize(12)
          .fontColor($r('app.color.colorText4'))
          .width('100%')
          .padding({ left: UiStyle.CARD_SIDE, right: UiStyle.CARD_SIDE, bottom: 12 })
      }
    }
    .width('100%')
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
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.colorText2'))
      .width('100%')
      .height(58)
      .padding({ left: 22, right: 22, top: 18 })
  }

  @Builder
  SettingDivider() {
    Divider()
      .color('#07000000')
      .margin({ left: 22, right: 22 })
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
    .height(58)
    .padding({ left: 22, right: 22 })
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
