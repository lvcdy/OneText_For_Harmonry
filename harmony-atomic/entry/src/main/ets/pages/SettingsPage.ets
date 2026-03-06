import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
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
  @Consume('navPathStack') navPathStack: NavPathStack;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private displayModes: string[] = ['跟随系统', '浅色模式', '深色模式'];
  private chineseTypes: string[] = ['自动', '简体', '繁体', '港繁', '台繁'];

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
        const { fileIo } = await import('@kit.CoreFileKit');
        const cachePath = `${this.context.filesDir}/OneText/OneText-Library.json`;
        try {
          fileIo.unlinkSync(cachePath);
        } catch (e) {
          // 忽略
        }
      }
    }
    this.selectedFeedIndex = index;
    await this.prefs.putNumber('feed_code', index);
    await this.prefs.remove('onetext_code');
    await this.prefs.remove('api_string');
    this.feedList = this.feedList.map((item: FeedItem) => ({
      name: item.name,
      selected: item.index === index,
      index: item.index
    } as FeedItem));
    promptAction.showToast({ message: $r('app.string.succeed') });
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部标题栏
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.navPathStack.pop();
            })

        Text($r('app.string.setting_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // 设置内容
      Scroll() {
        Column() {
          // ===== 界面设置 =====
          this.SectionTitle($r('app.string.interface_text'))

          // 显示模式
          Row() {
            Text($r('app.string.interface_daynight'))
              .fontSize(16)
              .fontColor($r('app.color.colorText1'))
            Blank()
            Select(this.displayModes.map((item: string) => ({ value: item } as SelectOption)))
              .selected(this.displayModeIndex)
              .value(this.displayModes[this.displayModeIndex])
              .font({ size: 14 })
              .onSelect(async (index: number) => {
                this.displayModeIndex = index;
                await this.prefs.putNumber('interface_daynight', index);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })

          // 中文类型
          Row() {
            Text($r('app.string.chinese_type'))
              .fontSize(16)
              .fontColor($r('app.color.colorText1'))
            Blank()
            Select(this.chineseTypes.map((item: string) => ({ value: item } as SelectOption)))
              .selected(this.chineseTypeIndex)
              .value(this.chineseTypes[this.chineseTypeIndex])
              .font({ size: 14 })
              .onSelect(async (index: number) => {
                this.chineseTypeIndex = index;
                await this.prefs.putNumber('chinese_type', index);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Divider().margin({ left: 16, right: 16 })

          // ===== 订阅源设置 =====
          Row() {
            this.SectionTitle($r('app.string.feed_text'))
            Blank()
            Image($r('app.media.ic_edit'))
              .width(20)
              .height(20)
              .margin({ right: 16 })
              .onClick(() => {
                this.navPathStack.pushPathByName('EditFeedPage', null);
              })
          }
          .width('100%')

          // 订阅源列表
          ForEach(this.feedList, (item: FeedItem) => {
            Row() {
              Radio({ value: item.name, group: 'feed' })
                .checked(item.selected)
                .onChange(async (isChecked: boolean) => {
                  if (isChecked) {
                    await this.selectFeed(item.index);
                  }
                })
              Text(item.name)
                .fontSize(15)
                .fontColor($r('app.color.colorText1'))
                .margin({ left: 8 })
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .onClick(async () => {
              await this.selectFeed(item.index);
            })
          })

          // 自动更新开关
          this.SettingSwitch($r('app.string.feed_auto_update'), this.feedAutoUpdate, async (value: boolean) => {
            this.feedAutoUpdate = value;
            await this.prefs.putBoolean('feed_auto_update', value);
          })

          // 源刷新时间
          Row() {
            Text($r('app.string.feed_refresh_text'))
              .fontSize(14)
              .fontColor($r('app.color.colorText2'))
              .width(120)
            Slider({
              value: this.feedRefreshTime,
              min: 1,
              max: 24,
              step: 1,
              style: SliderStyle.OutSet
            })
              .layoutWeight(1)
              .blockColor($r('app.color.colorPrimary'))
              .trackColor($r('app.color.colorMD2BG'))
              .selectedColor($r('app.color.colorPrimary'))
              .onChange(async (value: number) => {
                this.feedRefreshTime = value;
                await this.prefs.putNumber('feed_refresh_time', value);
              })
            Text(`${Math.round(this.feedRefreshTime)} H`)
              .fontSize(13)
              .fontColor($r('app.color.colorText3'))
              .width(50)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })

          Divider().margin({ left: 16, right: 16 })

          // ===== 小组件设置 =====
          this.SectionTitle($r('app.string.widget_text'))

          this.SettingSwitch($r('app.string.widget_dark'), this.widgetDark, async (value: boolean) => {
            this.widgetDark = value;
            await this.prefs.putBoolean('widget_dark', value);
          })

          this.SettingSwitch($r('app.string.widget_shadow'), this.widgetShadow, async (value: boolean) => {
            this.widgetShadow = value;
            await this.prefs.putBoolean('widget_shadow', value);
          })

          this.SettingSwitch($r('app.string.widget_center'), this.widgetCenter, async (value: boolean) => {
            this.widgetCenter = value;
            await this.prefs.putBoolean('widget_center', value);
          })

          // 小组件刷新时间
          Row() {
            Text($r('app.string.widget_refresh_text'))
              .fontSize(14)
              .fontColor($r('app.color.colorText2'))
              .width(140)
            Slider({
              value: this.widgetRefreshTime,
              min: 10,
              max: 120,
              step: 10,
              style: SliderStyle.OutSet
            })
              .layoutWeight(1)
              .blockColor($r('app.color.colorPrimary'))
              .trackColor($r('app.color.colorMD2BG'))
              .selectedColor($r('app.color.colorPrimary'))
              .onChange(async (value: number) => {
                this.widgetRefreshTime = value;
                await this.prefs.putNumber('widget_refresh_time', value);
              })
            Text(`${Math.round(this.widgetRefreshTime)} MIN`)
              .fontSize(13)
              .fontColor($r('app.color.colorText3'))
              .width(60)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })

          Divider().margin({ left: 16, right: 16 })

          // ===== 关于 =====
          this.SectionTitle($r('app.string.about_text'))

          Row() {
            Text($r('app.string.about_text'))
              .fontSize(16)
              .fontColor($r('app.color.colorText1'))
            Blank()
            Image($r('app.media.ic_arrow_right'))
              .width(16)
              .height(16)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.navPathStack.pushPathByName('AboutPage', null);
          })
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
    .hideTitleBar(true)
  }

  @Builder
  SectionTitle(title: Resource) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.colorPrimary'))
      .width('100%')
      .padding({ left: 16, top: 20, bottom: 8 })
  }

  @Builder
  SettingSwitch(label: Resource, isOn: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.colorText1'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.colorPrimary'))
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }
}
