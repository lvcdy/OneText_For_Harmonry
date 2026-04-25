import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { promptAction } from '@kit.ArkUI';
import { motion } from '@kit.MultimodalAwarenessKit';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { AppLanguageUtil } from '../common/AppLanguageUtil';
import { CoreUtil } from '../common/CoreUtil';
import { UiStyle } from '../common/UiStyle';
import { FeedConfig, FeedItem } from '../model/DataModels';

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
  @State isLeftHandHeld: boolean = false;
  @Consume('navPathStack') navPathStack: NavPathStack;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private displayModes: string[] = ['跟随系统', '浅色模式', '深色模式'];
  private languageTypes: string[] = ['中文', '繁中', 'English'];
  private holdingHandCallback = (status: motion.HoldingHandStatus): void => {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      this.updateGripSide(true);
    } else if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD || status === motion.HoldingHandStatus.BOTH_HANDS_HELD) {
      this.updateGripSide(false);
    }
  };

  async aboutToAppear(): Promise<void> {
    this.displayModeIndex = await this.prefs.getNumber('interface_daynight', 0);
    this.languageTypeIndex = await this.loadLanguageType();
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
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.languageTypeIndex = index;
    });
    await this.prefs.putNumber(AppLanguageUtil.PREF_KEY, index);
    AppLanguageUtil.setPreferredLanguage(index);
    promptAction.showToast({ message: '语言将在下次启动后生效' });
  }

  private async selectFeed(index: number): Promise<void> {
    const oldIndex = this.selectedFeedIndex;
    if (oldIndex !== index) {
      // 如果旧订阅源是远程类型，删除缓存
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
      const formPrefs = await preferences.getPreferences(this.context, 'form_ids');
      const idsStr = (await formPrefs.get('form_id_list', '')) as string;
      const ids = idsStr ? idsStr.split(',').filter((id: string) => id !== '') : [];
      const formData = await this.coreUtil.buildWidgetFormData();
      if (!formData || ids.length === 0) {
        return;
      }
      const bindingData = formBindingData.createFormBindingData(formData);
      for (const formId of ids) {
        await formProvider.updateForm(formId, bindingData);
      }
    } catch (e) {
      console.error('SettingsPage', `refreshWidgetForms error: ${JSON.stringify(e)}`);
    }
  }

  build() {
    NavDestination() {
      Column() {
        this.SettingsHeader()

        Scroll() {
          Column() {
            this.InterfaceCard()
            this.FeedCard()
            this.WidgetCard()
            this.AboutCard()
          }
          .width('100%')
          .padding({ top: 0, bottom: 34 })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(UiStyle.PAGE_BG)
    }
    .hideTitleBar(true)
    .onShown(() => {
      this.reloadFeedMenu();
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
          .backgroundColor($r('app.color.colorCard'))
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
    }
    .width('100%')
    .backgroundColor($r('app.color.colorCard'))
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 18, color: UiStyle.CARD_SHADOW, offsetX: 0, offsetY: 6 })
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
    .backgroundColor($r('app.color.colorCard'))
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 18, color: UiStyle.CARD_SHADOW, offsetX: 0, offsetY: 6 })
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
      this.RefreshSliderRow($r('app.string.widget_refresh_text'), this.widgetRefreshTime, 10, 120, 10, 'MIN',
        async (value: number) => {
          this.widgetRefreshTime = value;
          await this.prefs.putNumber('widget_refresh_time', value);
          await this.refreshWidgetForms();
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.colorCard'))
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 18, color: UiStyle.CARD_SHADOW, offsetX: 0, offsetY: 6 })
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
    .backgroundColor($r('app.color.colorCard'))
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 14, color: UiStyle.CARD_SHADOW_SOFT, offsetX: 0, offsetY: 6 })
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
    .backgroundColor(item.selected ? UiStyle.SELECTED_BG : UiStyle.TRANSPARENT)
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
      .backgroundColor(UiStyle.CONTROL_BG)
      .borderRadius(24)
      .height(44)
      .onSelect(async (index: number) => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.displayModeIndex = index;
        });
        await this.prefs.putNumber('interface_daynight', index);
      })
  }

  @Builder
  LanguageTypeSelect() {
    Select(this.languageTypes.map((item: string) => ({ value: item } as SelectOption)))
      .selected(this.languageTypeIndex)
      .value(this.languageTypes[this.languageTypeIndex])
      .font({ size: 16, weight: FontWeight.Medium })
      .backgroundColor(UiStyle.CONTROL_BG)
      .borderRadius(24)
      .height(44)
      .onSelect(async (index: number) => {
        await this.changeLanguageType(index);
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
