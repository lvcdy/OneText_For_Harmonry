import { common, Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { window, componentSnapshot } from '@kit.ArkUI';
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';
import { image } from '@kit.ImageKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { CoreUtil } from '../common/CoreUtil';
import { OneTextMetaUtil } from '../common/OneTextMetaUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { UiStyle } from '../common/UiStyle';
import { AppBackgroundLayer, AppBackgroundUtil } from '../common/AppBackgroundUtil';
import { FormUtil } from '../common/FormUtil';
import { HuaweiAccountUtil } from '../common/HuaweiAccountUtil';
import { OneTextItem } from '../model/DataModels';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { SettingsPageContent } from './SettingsPage';
import { AboutPageContent } from './AboutPage';
import { EditFeedPageContent } from './EditFeedPage';
import { WelcomePageContent } from './WelcomePage';

const LOGGED_IN_AVATAR_SIZE: number = 152;
const LOGGED_IN_AVATAR_RADIUS: number = LOGGED_IN_AVATAR_SIZE / 2;
const RESPONSIVE_WIDE_WIDTH: number = 720;
const HOME_CONTENT_MAX_WIDTH_COMPACT: number = 560;
const HOME_CONTENT_MAX_WIDTH_WIDE: number = 980;
const HOME_CONTENT_TOP_SPACE: number = 16;
const MINE_ACCOUNT_HEADER_HEIGHT: number = 140;
const MINE_PAGE_SIDE: number = UiStyle.PAGE_SIDE;
const MINE_PANE_MAX_WIDTH_COMPACT: number = 560;
const MINE_PANE_MAX_WIDTH_WIDE: number = 680;
const MINE_FONT_CARD_TOP: number = 16;
const MINE_SETTINGS_CARD_TOP: number = 14;
const DONATE_URL: string = 'https://hitokoto.cn/donate';

/**
 * 主页面 - 替代 Android MainActivity
 * 展示 Hitokoto 内容，支持刷新、保存截图、分享等功能
 * HarmonyOS 7: 使用 Navigation + NavDestination 导航模式
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
  @State sealVisible: boolean = false;
  @State isRefreshing: boolean = false;
  @State hasShownWelcome: boolean = false;
  @State selectedTabIndex: number = 0;
  @State fontStyleIndex: number = 0;
  @State huaweiAccountName: string = '使用华为账号登录';
  @State huaweiAccountAvatar: string = '';
  @State hasHuaweiAccount: boolean = false;
  @State pageWidth: number = 0;
  @State showFontSizeSheet: boolean = false;
  @State apiConfigMissing: boolean = false;
  @State statusBarHeight: number = 0;
  @StorageLink('appBackgroundUri') appBackgroundUri: string = '';
  @StorageLink('feedConfigUpdatedAt')
  @Watch('onFeedConfigUpdated')
  feedConfigUpdatedAt: number = 0;
  @Provide('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  private context!: common.UIAbilityContext;
  private coreUtil!: CoreUtil;
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private fontStyles: string[] = ['默认', '仓耳今楷', '霞鹜文楷'];
  private fontFamilies: string[] = ['HarmonyOS Sans', 'CangErJinKai', 'LXGWWenKai'];
  private fontSamples: string[] = ['樱', '楷', '文'];
  private fontDescriptions: string[] = ['恢复系统字体', '仓耳今楷 01-W04', '霞鹜文楷 Regular'];
  private isPullRefreshRunning: boolean = false;

  private isWideLayout(): boolean {
    return this.pageWidth >= RESPONSIVE_WIDE_WIDTH;
  }

  private getHomeContentMaxWidth(): number {
    return this.isWideLayout() ? HOME_CONTENT_MAX_WIDTH_WIDE : HOME_CONTENT_MAX_WIDTH_COMPACT;
  }

  private getMinePaneMaxWidth(): number {
    return this.isWideLayout() ? MINE_PANE_MAX_WIDTH_WIDE : MINE_PANE_MAX_WIDTH_COMPACT;
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

  async aboutToAppear(): Promise<void> {
    try {
      this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.coreUtil = new CoreUtil(this.context);
      this.registerCustomFonts();

      // 获取状态栏高度
      try {
        const win = await window.getLastWindow(this.context);
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.statusBarHeight = this.getUIContext().px2vp(avoidArea.topRect.height);
      } catch (e) {
        this.statusBarHeight = 44;
        console.warn('Index', `getStatusBarHeight fallback: ${JSON.stringify(e)}`);
      }

      // 加载偏好设置
      this.textFontSize = await this.prefs.getNumber('onetext_text_size', 23);
      this.byFontSize = await this.prefs.getNumber('onetext_by_size', 18);
      this.timeFontSize = await this.prefs.getNumber('onetext_time_size', 15);
      this.fromFontSize = await this.prefs.getNumber('onetext_from_size', 15);
      this.fontStyleIndex = Math.min(await this.prefs.getNumber('onetext_font_style', 0), this.fontStyles.length - 1);
      this.sealVisible = await this.prefs.getBoolean('seal_enabled', false);
      this.appBackgroundUri = await AppBackgroundUtil.getBackgroundUri(this.prefs);
      await this.loadHuaweiAccount();

      // 初始化订阅源
      await this.coreUtil.initFeedFile();

      if (!this.hasShownWelcome) {
        const firstRun = await this.prefs.getBoolean('first_run', true);
        if (firstRun) {
          this.hasShownWelcome = true;
          this.isLoading = false;
          this.navPathStack.pushPathByName('WelcomePage', null);
        } else {
          await this.loadOneText(false);
        }
      } else {
        await this.loadOneText(false);
      }

    } catch (e) {
      this.isLoading = false;
      console.error('Index', `aboutToAppear skipped: ${JSON.stringify(e)}`);
    }
  }

  private onFeedConfigUpdated(): void {
    if (this.feedConfigUpdatedAt <= 0) {
      return;
    }
    this.loadOneText(false).catch((e: Error) => {
      console.error('Index', `reload one text error: ${JSON.stringify(e)}`);
    });
  }

  private async refreshByPull(): Promise<void> {
    if (this.isPullRefreshRunning) {
      return;
    }
    this.isPullRefreshRunning = true;
    this.isRefreshing = true;
    try {
      await this.loadOneText(true);
    } finally {
      this.isRefreshing = false;
      this.isPullRefreshRunning = false;
    }
  }

  private getCurrentFontFamily(): string {
    return this.fontFamilies[this.fontStyleIndex] ?? 'HarmonyOS Sans';
  }

  private registerCustomFonts(): void {
    try {
      const fontManager = this.getUIContext().getFont();
      fontManager.registerFont({
        familyName: 'CangErJinKai',
        familySrc: $rawfile('fonts/canger_jinkai.ttf')
      });
      fontManager.registerFont({
        familyName: 'LXGWWenKai',
        familySrc: $rawfile('fonts/lxgw_wenkai.ttf')
      });
    } catch (e) {
      console.warn('Index', `Register custom fonts skipped: ${JSON.stringify(e)}`);
    }
  }

  private showToast(message: ResourceStr | string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      console.warn('Index', `showToast skipped: ${JSON.stringify(e)}`);
    }
  }

  private async openExternalLink(url: string): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url
    };
    try {
      await this.context.startAbility(want);
    } catch (e) {
      console.error('Index', `openExternalLink error: ${JSON.stringify(e)}`);
      this.showToast('无法打开链接');
    }
  }

  private async loadHuaweiAccount(): Promise<void> {
    const idToken = await this.prefs.getString('huawei_id_token', '');
    const isLoggedIn = await this.prefs.getBoolean('huawei_account_logged_in', false);
    if (idToken.length === 0 && !isLoggedIn) {
      this.huaweiAccountName = HuaweiAccountUtil.FALLBACK_NAME;
      this.huaweiAccountAvatar = '';
      this.hasHuaweiAccount = false;
      return;
    }
    const profile = HuaweiAccountUtil.parseIdToken(idToken);
    const savedName = await this.prefs.getString('huawei_account_name', '');
    const savedAvatar = await this.prefs.getString('huawei_account_avatar', '');
    this.huaweiAccountName = savedName.length > 0 ? savedName :
      (profile.name.length > 0 ? profile.name : HuaweiAccountUtil.FALLBACK_NAME);
    this.huaweiAccountAvatar = savedAvatar.length > 0 ? savedAvatar : profile.avatar;
    this.hasHuaweiAccount = true;
  }

  private async loginWithHuaweiAccount(): Promise<void> {
    try {
      const profile = await HuaweiAccountUtil.authorize(this.context);
      await this.saveHuaweiAccount(profile.idToken, profile.name, profile.avatar);
    } catch (e) {
      console.error('Index', `Huawei account login failed: ${JSON.stringify(e)}`);
      this.showToast('华为账号登录失败');
    }
  }

  private async saveHuaweiAccount(idToken: string, name: string, avatar: string): Promise<boolean> {
    if (idToken.length === 0 && name.length === 0 && avatar.length === 0) {
      this.showToast('未获取到华为账号信息');
      return false;
    }
    this.huaweiAccountName = name.length > 0 ? name : HuaweiAccountUtil.FALLBACK_NAME;
    this.huaweiAccountAvatar = avatar;
    this.hasHuaweiAccount = true;
    await this.prefs.putString('huawei_id_token', idToken);
    await this.prefs.putString('huawei_account_name', this.huaweiAccountName);
    await this.prefs.putString('huawei_account_avatar', this.huaweiAccountAvatar);
    await this.prefs.putBoolean('huawei_account_logged_in', true);
    this.showToast('华为账号登录成功');
    return true;
  }

  private async logoutHuaweiAccount(): Promise<void> {
    await this.cancelHuaweiAuthorization();
    await this.prefs.remove('huawei_id_token');
    await this.prefs.remove('huawei_account_name');
    await this.prefs.remove('huawei_account_avatar');
    await this.prefs.remove('huawei_account_logged_in');
    this.huaweiAccountName = HuaweiAccountUtil.FALLBACK_NAME;
    this.huaweiAccountAvatar = '';
    this.hasHuaweiAccount = false;
    this.showToast('已退出华为账号');
  }

  private async cancelHuaweiAuthorization(): Promise<void> {
    try {
      await HuaweiAccountUtil.cancelAuthorization(this.context);
    } catch (e) {
      console.warn('Index', `Cancel Huawei authorization skipped: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 加载 Hitokoto 数据
   */
  private async loadOneText(forceRefresh: boolean): Promise<void> {
    this.isLoading = true;
    this.apiConfigMissing = false;
    try {
      const feedCode = await this.prefs.getNumber('feed_code', 0);
      const feedMap = await this.coreUtil.getFeedInformation(feedCode);

      if (feedMap.feed_type === CoreUtil.FEED_TYPE_INTERNET) {
        const apiUrl = (feedMap.api_url ?? feedMap.feed_url ?? '').trim();
        if (apiUrl === '') {
          this.oneText = this.createApiMissingOneText();
          this.apiConfigMissing = true;
          await this.prefs.remove('api_string');
          await this.coreUtil.saveCurrentOneText(this.oneText);
          await this.refreshWidgetForms();
          return;
        }

        // API 类型订阅源
        const apiString = await this.prefs.getString('api_string', '');
        const shouldUpdate = await this.coreUtil.ifOneTextShouldUpdate(false);
        if (apiString === '' || shouldUpdate || forceRefresh) {
          this.oneText = await this.coreUtil.getOneTextFromApi(feedMap);
          await this.coreUtil.refreshLatestRefreshTime();
        } else {
          this.oneText = this.coreUtil.convertApiResponse(apiString, feedMap) ??
            await this.coreUtil.getOneTextFromApi(feedMap);
        }
      } else {
        // 远程/本地类型订阅源
        const initSuccess = await this.coreUtil.initOneText();
        if (initSuccess) {
          this.oneText = await this.coreUtil.getOneText(forceRefresh, false);
          // 后台更新检查
          await this.coreUtil.runOneTextUpdate();
        } else {
          this.showToast($r('app.string.init_failed'));
        }
      }
      await this.coreUtil.saveCurrentOneText(this.oneText);
      await this.refreshWidgetForms();
    } catch (e) {
      console.error('Index', `loadOneText error: ${JSON.stringify(e)}`);
      this.showToast($r('app.string.refresh_failed'));
    } finally {
      this.isLoading = false;
    }
  }

  private createApiMissingOneText(): OneTextItem {
    return {
      text: CoreUtil.API_MISSING_TEXT,
      by: '',
      from: '',
      time: '',
      uri: '',
      quote1: '\u201C',
      quote2: '\u201D'
    };
  }

  private async refreshWidgetForms(): Promise<void> {
    try {
      await FormUtil.refreshForms(this.context, this.coreUtil);
    } catch (e) {
      console.error('Index', `refreshWidgetForms error: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 复制文本到剪贴板
   */
  private copyToClipboard(text: string): void {
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setDataSync(pasteData);
    this.showToast($r('app.string.copied'));
  }

  private buildShareText(): string {
    return OneTextMetaUtil.buildShareText(this.oneText, CoreUtil.TEXT_REPLACE_HOLDER, CoreUtil.TEXT_REPLACE);
  }

  private getDisplayText(text: string): string {
    return OneTextMetaUtil.replaceTextHolder(text, CoreUtil.TEXT_REPLACE_HOLDER, CoreUtil.TEXT_REPLACE);
  }

  private setTextFontSize(value: number): void {
    this.textFontSize = value;
    this.prefs.putNumber('onetext_text_size', value);
  }

  private setByFontSize(value: number): void {
    this.byFontSize = value;
    this.prefs.putNumber('onetext_by_size', value);
  }

  private setFromFontSize(value: number): void {
    this.fromFontSize = value;
    this.prefs.putNumber('onetext_from_size', value);
  }

  private setTimeFontSize(value: number): void {
    this.timeFontSize = value;
    this.prefs.putNumber('onetext_time_size', value);
  }

  private async shareCurrentText(): Promise<void> {
    try {
      const shareText = this.buildShareText();
      if (shareText === '') {
        this.showToast($r('app.string.share_empty'));
        return;
      }
      const record: systemShare.SharedRecord = {
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        content: shareText,
        title: 'Hitokoto',
        description: this.oneText.from
      };
      const shareData = new systemShare.SharedData(record);
      const controller = new systemShare.ShareController(shareData);
      await controller.show(this.context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (e) {
      console.error('Index', `shareCurrentText error: ${JSON.stringify(e)}`);
      this.showToast($r('app.string.share_failed'));
    }
  }

  /**
   * 保存纯色卡片截图
   */
  private async saveScreenshot(): Promise<void> {
    try {
      const pixelMap: image.PixelMap = await componentSnapshot.get('onetext_save_card');
      const packer = image.createImagePacker();
      const data = await packer.packing(pixelMap, { format: 'image/jpeg', quality: 100 });
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg', {
        title: `Hitokoto_${Date.now()}`
      });
      const file = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY);
      try {
        fileIo.writeSync(file.fd, data);
      } finally {
        fileIo.closeSync(file);
      }
      this.showToast($r('app.string.save_succeed'));
    } catch (e) {
      console.error('Index', `saveScreenshot error: ${JSON.stringify(e)}`);
      this.showToast($r('app.string.save_fail'));
    }
  }

  build() {
    Stack() {
      this.SaveImageCard()
      AppBackgroundLayer()

      Navigation(this.navPathStack) {
        HdsTabs({ barPosition: BarPosition.End, index: this.selectedTabIndex }) {
          TabContent() {
            this.HomePage()
          }
          .backgroundColor(UiStyle.TRANSPARENT)
          .tabBar(this.OfficialBottomTabStyle($r('app.media.ic_home'), $r('app.string.tab_home')))

          TabContent() {
            this.MinePage()
          }
          .backgroundColor(UiStyle.TRANSPARENT)
          .tabBar(this.OfficialBottomTabStyle($r('app.media.ic_user'), $r('app.string.tab_mine')))
        }
        .width('100%')
        .height('100%')
        .backgroundColor(UiStyle.TRANSPARENT)
        .barMode(BarMode.Fixed)
        .barHeight(64)
        .barOverlap(true)
        .barFloatingStyle({
          barWidth: {
            smallWidth: 250,
            mediumWidth: 286,
            largeWidth: 320
          },
          barSideMargin: 32,
          barBottomMargin: 30,
          gradientMask: {
            maskColor: UiStyle.TRANSPARENT,
            maskHeight: 112
          },
          adaptToHandedness: false,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          },
          thermoCtrl: true
        })
        .scrollable(false)
        .animationDuration(180)
        .onChange((index: number) => {
          this.selectedTabIndex = index;
        })
      }
      .hideTitleBar(true)
      .navDestination(this.PageMap)
      .mode(NavigationMode.Stack)
      .backgroundColor(UiStyle.TRANSPARENT)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.pageWidth = Number.parseFloat(String(newValue.width));
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(UiStyle.TRANSPARENT)
  }

  private OfficialBottomTabStyle(icon: ResourceStr, label: ResourceStr): BottomTabBarStyle {
    return BottomTabBarStyle
      .of(icon, label)
      .labelStyle({
        font: { size: 12, weight: FontWeight.Bold },
        selectedColor: $r('app.color.colorPrimary'),
        unselectedColor: '#4F5A60'
      })
      .iconStyle({
        selectedColor: $r('app.color.colorPrimary'),
        unselectedColor: '#4F5A60'
      })
      .padding({ left: 4, right: 4, top: 4, bottom: 4 })
      .layoutMode(LayoutMode.VERTICAL)
      .verticalAlign(VerticalAlign.Center)
      .symmetricExtensible(false);
  }

  @Builder
  HomePage() {
    Stack() {
      Column() {
        // 顶部安全区占位
        Row()
          .width('100%')
          .height(this.getStatusBarHeight())

        this.HomeHeader()

        // 主内容区域 - 可滚动
        Refresh({ refreshing: $$this.isRefreshing, offset: 72 }) {
          Scroll() {
            Column() {
              this.QuoteCard()
              this.ActionGrid()
            }
            .width('100%')
            .constraintSize({ maxWidth: this.getHomeContentMaxWidth() })
            .padding({
              left: UiStyle.PAGE_SIDE,
              right: UiStyle.PAGE_SIDE,
              bottom: UiStyle.FLOAT_TAB_BOTTOM_SPACE,
              top: HOME_CONTENT_TOP_SPACE
            })
          }
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .layoutWeight(1)
        .pullDownRatio(0.72)
        .refreshOffset(72)
        .onRefreshing(async () => {
          await this.refreshByPull();
        })
      }
      .height('100%')

      // 字号调节弹窗
      if (this.showFontSizeSheet) {
        this.FontSizeSheet()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SaveImageCard() {
    Stack() {
      Text('“')
        .fontSize(72)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorPrimary'))
        .opacity(0.18)
        .position({ x: 24, y: 14 })
        .zIndex(0)

      Column()
        .width(72)
        .height(3)
        .backgroundColor($r('app.color.colorPrimary'))
        .borderRadius(2)
        .opacity(0.54)
        .position({ x: 30, y: 34 })
        .zIndex(1)

      Image($r('app.media.moemiku'))
        .width(142)
        .height(142)
        .opacity(0.75)
        .position({ x: 176, y: 144 })
        .zIndex(1)
        .visibility(this.sealVisible ? Visibility.Visible : Visibility.None)

      Column() {
        Blank()

        Text(this.getDisplayText(this.oneText.text))
          .fontSize(this.textFontSize)
          .fontFamily(this.getCurrentFontFamily())
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.colorText1'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .lineHeight(this.textFontSize * 1.55)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        Column() {
          if (OneTextMetaUtil.getAuthor(this.oneText.by) !== '') {
            Text(`-- ${OneTextMetaUtil.getAuthor(this.oneText.by)}`)
              .fontSize(this.byFontSize)
              .fontFamily(this.getCurrentFontFamily())
              .fontColor($r('app.color.colorText3'))
              .textAlign(TextAlign.Center)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          Row() {
            if (OneTextMetaUtil.shouldShowSource(this.oneText.by, this.oneText.from)) {
              Text(this.oneText.from)
                .fontSize(this.fromFontSize)
                .fontFamily(this.getCurrentFontFamily())
                .fontColor($r('app.color.colorText4'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }

            if (OneTextMetaUtil.shouldShowSource(this.oneText.by, this.oneText.from) && this.oneText.time !== '') {
              Text(' · ')
                .fontSize(this.fromFontSize)
                .fontColor($r('app.color.colorText4'))
            }

            if (this.oneText.time !== '') {
              Text(this.oneText.time)
                .fontSize(this.timeFontSize)
                .fontFamily(this.getCurrentFontFamily())
                .fontColor($r('app.color.colorText4'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ top: 10 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 30, right: 30, top: 62, bottom: 26 })
      .zIndex(2)
    }
    .id('onetext_save_card')
    .width(360)
    .height(306)
    .backgroundColor($r('app.color.colorCard'))
    .border({ width: 1, color: $r('app.color.colorCardBorder') })
    .borderRadius(UiStyle.CARD_RADIUS)
    .position({ x: 0, y: 0 })
    .zIndex(0)
  }

  @Builder
  QuoteCard() {
    Stack() {
      Text('“')
        .fontSize(this.isWideLayout() ? 86 : 72)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorPrimary'))
        .opacity(0.16)
        .position({ x: 24, y: 14 })
        .zIndex(0)

      Column()
        .width(this.isWideLayout() ? 92 : 72)
        .height(3)
        .backgroundColor($r('app.color.colorPrimary'))
        .borderRadius(2)
        .opacity(0.48)
        .position({ x: 30, y: 34 })
        .zIndex(1)

      Image($r('app.media.moemiku'))
        .width(this.isWideLayout() ? 166 : 142)
        .height(this.isWideLayout() ? 166 : 142)
        .opacity(0.75)
        .position({ x: this.isWideLayout() ? 356 : 176, y: this.isWideLayout() ? 166 : 144 })
        .zIndex(1)
        .visibility(this.sealVisible ? Visibility.Visible : Visibility.None)

      Column() {
        Blank()

        if (this.apiConfigMissing) {
          Text(CoreUtil.API_MISSING_TEXT)
            .fontSize(this.isWideLayout() ? 24 : 21)
            .fontFamily(this.getCurrentFontFamily())
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.colorText1'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .lineHeight(32)
        } else if (this.oneText.text !== '') {
          Text(this.getDisplayText(this.oneText.text))
            .fontSize(this.textFontSize)
            .fontFamily(this.getCurrentFontFamily())
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.colorText1'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .lineHeight(this.textFontSize * 1.55)
            .maxLines(this.isWideLayout() ? 6 : 4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.copyToClipboard(this.getDisplayText(this.oneText.text));
            })
        }

        Blank()

        Column() {
          if (this.oneText.by !== '') {
            Text(`-- ${OneTextMetaUtil.getAuthor(this.oneText.by)}`)
              .fontSize(this.byFontSize)
              .fontFamily(this.getCurrentFontFamily())
              .fontColor($r('app.color.colorText3'))
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.copyToClipboard(this.oneText.by);
              })
          }

          Row() {
            if (OneTextMetaUtil.shouldShowSource(this.oneText.by, this.oneText.from)) {
              Text(this.oneText.from)
                .fontSize(this.fromFontSize)
                .fontFamily(this.getCurrentFontFamily())
                .fontColor($r('app.color.colorText4'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  this.copyToClipboard(this.oneText.from);
                })
            }

            if (OneTextMetaUtil.shouldShowSource(this.oneText.by, this.oneText.from) && this.oneText.time !== '') {
              Text(' · ')
                .fontSize(this.fromFontSize)
                .fontColor($r('app.color.colorText4'))
            }

            if (this.oneText.time !== '') {
              Text(this.oneText.time)
                .fontSize(this.timeFontSize)
                .fontFamily(this.getCurrentFontFamily())
                .fontColor($r('app.color.colorText4'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  this.copyToClipboard(this.oneText.time);
                })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ top: 10 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: this.isWideLayout() ? 48 : 28, right: this.isWideLayout() ? 48 : 28, top: 56, bottom: 28 })
      .zIndex(2)
    }
    .id('onetext_card')
    .width('100%')
    .height(this.isWideLayout() ? 380 : 340)
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(18)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 28, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 10 })
  }

  @Builder
  ActionGrid() {
    Column({ space: 12 }) {
      // 第一行: 保存、分享、刷新
      Row({ space: 0 }) {
        this.ActionIconButton($r('app.media.ic_download'), '保存', () => {
          this.saveScreenshot().catch((e: Error) => {
            console.error('Index', `save screenshot error: ${JSON.stringify(e)}`);
          });
        })
        Blank()
        this.ActionIconButton($r('app.media.ic_share'), '分享', async () => {
          await this.shareCurrentText();
        })
        Blank()
        this.ActionIconButton($r('app.media.ic_refresh'), '刷新', async () => {
          await this.refreshByPull();
        })
      }
      .width('100%')

      // 第二行: 印章、字号、设置
      Row({ space: 0 }) {
        Column({ space: 6 }) {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.ic_heart'))
              .width(22)
              .height(22)
              .fillColor(this.sealVisible ? $r('app.color.colorPrimary') : $r('app.color.colorText3'))
              .opacity(this.sealVisible ? 1.0 : 0.6)
          }
          .width(52)
          .height(52)
          .backgroundColor(this.sealVisible ? '#1A2F6BFF' : this.getGlassControlColor())
          .border({ width: 0.5, color: this.sealVisible ? '#332F6BFF' : this.getGlassCardBorder() })
          .borderRadius(16)
          .shadow({ radius: 6, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 2 })

          Text(this.sealVisible ? '印章开' : '印章关')
            .fontSize(11)
            .fontColor(this.sealVisible ? $r('app.color.colorPrimary') : $r('app.color.colorText2'))
        }
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
        .onClick(async () => {
          this.sealVisible = !this.sealVisible;
          await this.prefs.putBoolean('seal_enabled', this.sealVisible);
          this.showToast(this.sealVisible ? $r('app.string.seal_button_ison') : $r('app.string.seal_button_isoff'));
        })

        Blank()
        this.ActionIconButton($r('app.media.ic_edit'), '字号', () => {
          this.showFontSizeSheet = !this.showFontSizeSheet;
        })
        Blank()
        this.ActionIconButton($r('app.media.ic_settings'), '设置', () => {
          this.navPathStack.pushPathByName('SettingsPage', null);
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    .margin({ top: 14 })
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(16)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(26)
    .shadow({ radius: 16, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 5 })
  }

  @Builder
  ActionIconButton(icon: ResourceStr, label: string, onClick: () => void | Promise<void>) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(icon)
          .width(22)
          .height(22)
          .fillColor($r('app.color.colorPrimary'))
      }
      .width(52)
      .height(52)
      .backgroundColor(this.getGlassControlColor())
      .border({ width: 0.5, color: this.getGlassCardBorder() })
      .borderRadius(16)
      .shadow({ radius: 6, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 2 })

      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.colorText2'))
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
    .onClick(() => {
      Promise.resolve(onClick()).catch((e: Error) => {
        console.error('Index', `action icon error: ${JSON.stringify(e)}`);
      });
    })
  }

  @Builder
  FontSizeSheet() {
    Column() {
      // 半透明遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(UiStyle.OVERLAY_BG)
        .onClick(() => {
          this.showFontSizeSheet = false;
        })

      // 底部面板
      Column() {
        // 顶部拖拽指示条
        Column()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor('#D0D0D0')
          .margin({ top: 10, bottom: 6 })

        Row() {
          Text('字号调节')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.colorText1'))

          Blank()

          Text('完成')
            .fontSize(15)
            .fontColor($r('app.color.colorPrimary'))
            .onClick(() => {
              this.showFontSizeSheet = false;
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 8, bottom: 12 })

        Column({ space: 4 }) {
          this.FontSizeSliderRow('正文', this.textFontSize, 12, 48, 23, (value: number) => {
            this.setTextFontSize(value);
          })
          this.FontSizeSliderRow('署名', this.byFontSize, 8, 36, 18, (value: number) => {
            this.setByFontSize(value);
          })
          this.FontSizeSliderRow('来源', this.fromFontSize, 8, 24, 15, (value: number) => {
            this.setFromFontSize(value);
          })
          this.FontSizeSliderRow('时间', this.timeFontSize, 8, 24, 15, (value: number) => {
            this.setTimeFontSize(value);
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 40 })
      }
      .width('100%')
      .backgroundColor(this.getGlassCardColor())
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
      .backdropBlur(20)
      .border({ width: 1, color: this.getGlassCardBorder() })
      .borderRadius({ topLeft: 28, topRight: 28 })
      .shadow({ radius: 20, color: this.getGlassShadowColor(), offsetX: 0, offsetY: -6 })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(100)
  }

  @Builder
  HomeHeader() {
    Row() {
      Row() {
        Image($r('app.media.app_icon'))
          .width(36)
          .height(36)
          .borderRadius(10)
          .shadow({ radius: 10, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 3 })

        Text('Hitokoto')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ left: 10 })
          .textShadow({ radius: 6, color: '#33000000', offsetX: 0, offsetY: 1 })
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        this.HeaderIconButton($r('app.media.ic_heart'), $r('app.color.colorPrimary'), async () => {
          await this.openExternalLink(DONATE_URL);
        })
        this.HeaderIconButton($r('app.media.ic_settings'), $r('app.color.colorText2'), () => {
          this.navPathStack.pushPathByName('SettingsPage', null);
        })
      }
      .height(40)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 获取状态栏高度（vp），使用鸿蒙7响应式环境变量
   */
  private getStatusBarHeight(): number {
    return this.statusBarHeight > 0 ? this.statusBarHeight : 44;
  }

  @Builder
  HeaderIconButton(icon: ResourceStr, iconColor: ResourceColor, onClick: () => void | Promise<void>) {
    Stack() {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor(iconColor)
    }
    .width(38)
    .height(38)
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(18)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(19)
    .shadow({ radius: 10, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 3 })
    .onClick(() => {
      Promise.resolve(onClick()).catch((e: Error) => {
        console.error('Index', `header action error: ${JSON.stringify(e)}`);
      });
    })
  }

  @Builder
  MinePage() {
    Column() {
      // 顶部安全区占位
      Row()
        .width('100%')
        .height(this.getStatusBarHeight())

      // 页面标题
      this.MineHeader()

      List() {
        ListItem() {
          this.MineAccountHeader()
        }

        ListItem() {
          this.MineFontCard()
        }

        ListItem() {
          this.MineSettingsCard()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.getMinePaneMaxWidth() })
      .layoutWeight(1)
      .padding({
        left: MINE_PAGE_SIDE,
        right: MINE_PAGE_SIDE,
        top: 0,
        bottom: UiStyle.FLOAT_TAB_BOTTOM_SPACE
      })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .divider({ strokeWidth: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  MineHeader() {
    Row() {
      Text($r('app.string.tab_mine'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorText1'))

      Blank()
    }
    .width('100%')
    .height(52)
    .padding({ left: MINE_PAGE_SIDE, right: MINE_PAGE_SIDE })
  }

  @Builder
  MineAccountHeader() {
    Column() {
      if (this.hasHuaweiAccount) {
        Row({ space: 14 }) {
          if (this.huaweiAccountAvatar.length > 0) {
            Image(this.huaweiAccountAvatar)
              .width(52)
              .height(52)
              .borderRadius(26)
              .objectFit(ImageFit.Cover)
              .backgroundColor($r('app.color.colorSelectedBg'))
          } else {
            Image($r('app.media.app_icon'))
              .width(52)
              .height(52)
              .borderRadius(26)
              .backgroundColor($r('app.color.colorSelectedBg'))
              .padding(8)
          }

          Column() {
            Text(this.huaweiAccountName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.colorText1'))

            Text($r('app.string.huawei_login_desc'))
              .fontSize(12)
              .fontColor($r('app.color.colorText4'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      } else {
        Row({ space: 14 }) {
          Image($r('app.media.ic_user'))
            .width(52)
            .height(52)
            .opacity(0.78)

          Column() {
            Text($r('app.string.huawei_login_title'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.colorText1'))

            Text($r('app.string.huawei_login_desc'))
              .fontSize(12)
              .fontColor($r('app.color.colorText4'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button($r('app.string.huawei_login_button'))
            .height(36)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.colorPrimary'))
            .borderRadius(18)
            .padding({ left: 18, right: 18 })
            .onClick(async () => {
              await this.loginWithHuaweiAccount();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 20, bottom: 20 })
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(18)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 16, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })
  }

  @Builder
  MineFontCard() {
    Column() {
      Row() {
        Text($r('app.string.font_style'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))

        Blank()
      }
      .width('100%')
      .margin({ bottom: 16 })

      this.FontStyleOptions()
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 20, bottom: 16 })
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(18)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 16, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })
    .margin({ top: MINE_FONT_CARD_TOP })
  }

  @Builder
  MineSettingsCard() {
    Column() {
      this.MineSettingRow($r('app.string.setting_title'), $r('app.string.mine_settings_desc'), () => {
        this.navPathStack.pushPathByName('SettingsPage', null);
      })

      if (this.hasHuaweiAccount) {
        Divider()
          .strokeWidth(1)
          .color(this.getGlassCardBorder())
          .margin({ left: 18, right: 18 })

        this.MineLogoutRow()
      }
    }
    .width('100%')
    .margin({ top: MINE_SETTINGS_CARD_TOP })
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(18)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 16, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })
  }

  @Builder
  FontStyleOptions() {
    Scroll() {
      Row({ space: 14 }) {
        ForEach(this.fontStyles, (name: string, index: number) => {
          Row() {
            Text(this.fontSamples[index])
              .fontSize(58)
              .fontFamily(this.fontFamilies[index])
              .fontWeight(FontWeight.Medium)
              .fontColor(this.fontStyleIndex === index ? $r('app.color.colorPrimary') : $r('app.color.colorText2'))
              .width(74)
              .textAlign(TextAlign.Center)

            Column() {
              Text(name)
                .fontSize(17)
                .fontWeight(this.fontStyleIndex === index ? FontWeight.Bold : FontWeight.Medium)
                .fontColor($r('app.color.colorText1'))

              Text(this.fontDescriptions[index])
                .fontSize(12)
                .fontColor($r('app.color.colorText4'))
                .margin({ top: 6 })

              if (this.fontStyleIndex === index) {
                Text('当前使用')
                  .fontSize(11)
                  .fontColor($r('app.color.colorPrimary'))
                  .margin({ top: 12 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width(226)
          .height(112)
          .padding({ left: 14, right: 14, top: 14, bottom: 14 })
          .borderRadius(18)
          .backgroundColor(this.fontStyleIndex === index ? this.getGlassSelectedColor() : this.getGlassControlColor())
          .border({ width: 1, color: this.fontStyleIndex === index ? '#662F6BFF' : this.getGlassCardBorder() })
          .shadow({ radius: this.fontStyleIndex === index ? 12 : 0, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 5 })
          .onClick(async () => {
            this.fontStyleIndex = index;
            await this.prefs.putNumber('onetext_font_style', index);
          })
        }, (name: string, index: number) => `${index}-${name}`)
      }
      .padding({ left: 0, right: 20 })
    }
    .width('100%')
    .height(120)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  MineSettingRow(title: ResourceStr, desc: ResourceStr, onClick: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.colorText2'))

        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.colorText4'))
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
    .height(62)
    .padding({ left: 18, right: 18 })
    .onClick(() => {
      onClick();
    })
  }

  @Builder
  MineLogoutRow() {
    Row() {
      Column() {
        Text($r('app.string.logout_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiStyle.DANGER)

        Text($r('app.string.logout_desc'))
          .fontSize(12)
          .fontColor($r('app.color.colorText4'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(62)
    .padding({ left: 18, right: 18 })
    .onClick(async () => {
      await this.logoutHuaweiAccount();
    })
  }

  @Builder
  PageMap(name: string) {
    if (name === 'SettingsPage') {
      SettingsPageContent()
    } else if (name === 'AboutPage') {
      AboutPageContent()
    } else if (name === 'EditFeedPage') {
      EditFeedPageContent()
    } else if (name === 'WelcomePage') {
      WelcomePageContent()
    }
  }

  @Builder
  FontSizeSliderRow(label: string, value: number, min: number, max: number, defaultValue: number,
    onValueChange: (value: number) => void) {
    Column({ space: 2 }) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor($r('app.color.colorText2'))
          .width(36)

        Slider({
          value: value,
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
            onValueChange(value);
          })

        Text(`${Math.round(value)}`)
          .fontSize(13)
          .fontColor($r('app.color.colorText3'))
          .width(28)
          .textAlign(TextAlign.Center)

        Text($r('app.string.default_text'))
          .fontSize(11)
          .fontColor($r('app.color.colorPrimary'))
          .width(46)
          .height(26)
          .textAlign(TextAlign.Center)
          .borderRadius(13)
          .backgroundColor(this.getGlassSelectedColor())
          .border({ width: 0.5, color: this.getGlassCardBorder() })
          .padding({ top: 7 })
          .onClick(() => {
            onValueChange(defaultValue);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ bottom: 6 })
  }
}
