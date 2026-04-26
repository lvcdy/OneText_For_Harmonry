import { common, Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { font, promptAction } from '@kit.ArkUI';
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';
import { image } from '@kit.ImageKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { CoreUtil } from '../common/CoreUtil';
import { OneTextMetaUtil } from '../common/OneTextMetaUtil';
import { PermissionUtil } from '../common/PermissionUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { UiStyle } from '../common/UiStyle';
import { AppBackgroundLayer, AppBackgroundUtil } from '../common/AppBackgroundUtil';
import { FormUtil } from '../common/FormUtil';
import { GripUtil } from '../common/GripUtil';
import { HuaweiAccountUtil } from '../common/HuaweiAccountUtil';
import { OneTextItem } from '../model/DataModels';
import { componentSnapshot } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { SettingsPageContent } from './SettingsPage';
import { AboutPageContent } from './AboutPage';
import { EditFeedPageContent } from './EditFeedPage';
import { WelcomePageContent } from './WelcomePage';

const LOGGED_IN_AVATAR_SIZE: number = 152;
const LOGGED_IN_AVATAR_RADIUS: number = LOGGED_IN_AVATAR_SIZE / 2;
const RESPONSIVE_WIDE_WIDTH: number = 720;
const HOME_CONTENT_MAX_WIDTH_COMPACT: number = 560;
const HOME_CONTENT_MAX_WIDTH_WIDE: number = 980;
const HOME_QUOTE_SPAN_WIDE: number = 58;
const HOME_ACTION_SPAN_WIDE: number = 42;
const MINE_ACCOUNT_HEADER_HEIGHT: number = 198;
const MINE_ACCOUNT_HEADER_OFFSET_Y: number = 0;
const MINE_PAGE_SIDE: number = 0;
const MINE_PAGE_TOP: number = 0;
const MINE_PANE_MAX_WIDTH_COMPACT: number = 440;
const MINE_PANE_MAX_WIDTH_WIDE: number = 560;
const MINE_PANE_MIN_HEIGHT: number = 686;
const MINE_PANE_OFFSET_Y: number = -60;
const MINE_FONT_CARD_TOP: number = 42;
const MINE_FONT_CARD_OFFSET_Y: number = 0;
const MINE_SETTINGS_CARD_TOP: number = 14;
const MINE_SETTINGS_CARD_OFFSET_Y: number = 0;
const DONATE_URL: string = 'https://hitokoto.cn/donate';

/**
 * 主页面 - 替代 Android MainActivity
 * 展示 Hitokoto 内容，支持刷新、保存截图、分享等功能
 * HarmonyOS 6: 使用 Navigation + NavDestination 导航模式
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
  @State isLeftHandHeld: boolean = false;
  @State isRefreshing: boolean = false;
  @State hasShownWelcome: boolean = false;
  @State selectedTabIndex: number = 0;
  @State fontStyleIndex: number = 0;
  @State huaweiAccountName: string = '使用华为账号登录';
  @State huaweiAccountAvatar: string = '';
  @State hasHuaweiAccount: boolean = false;
  @State adaptiveGripEnabled: boolean = true;
  @State pageWidth: number = 0;
  @State showFontSizeControls: boolean = false;
  @StorageLink('appBackgroundUri') appBackgroundUri: string = '';
  @Provide('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private fontStyles: string[] = ['默认', '仓耳今楷', '霞鹜文楷'];
  private fontFamilies: string[] = ['HarmonyOS Sans', 'CangErJinKai', 'LXGWWenKai'];
  private fontSamples: string[] = ['樱', '楷', '文'];
  private fontDescriptions: string[] = ['恢复系统字体', '仓耳今楷 01-W04', '霞鹜文楷 Regular'];
  private isPullRefreshRunning: boolean = false;
  private holdingHandCallback = (status: motion.HoldingHandStatus): void => {
    const leftHandHeld = GripUtil.getLeftHandHeld(status);
    if (leftHandHeld !== null) {
      this.updateGripSide(leftHandHeld);
    }
  };

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
      this.registerCustomFonts();

      // 加载偏好设置
      this.textFontSize = await this.prefs.getNumber('onetext_text_size', 23);
      this.byFontSize = await this.prefs.getNumber('onetext_by_size', 18);
      this.timeFontSize = await this.prefs.getNumber('onetext_time_size', 15);
      this.fromFontSize = await this.prefs.getNumber('onetext_from_size', 15);
      this.fontStyleIndex = Math.min(await this.prefs.getNumber('onetext_font_style', 0), this.fontStyles.length - 1);
      this.sealVisible = await this.prefs.getBoolean('seal_enabled', false);
      this.adaptiveGripEnabled = await this.prefs.getBoolean('adaptive_grip_enabled', true);
      this.appBackgroundUri = await AppBackgroundUtil.getBackgroundUri(this.prefs);
      if (!this.adaptiveGripEnabled) {
        this.applyGripSide(false);
      }
      await this.loadHuaweiAccount();

      // 初始化订阅源
      await this.coreUtil.initFeedFile();

      // 加载 Hitokoto
      await this.loadOneText(false);

      if (!this.hasShownWelcome) {
        const firstRun = await this.prefs.getBoolean('first_run', true);
        if (firstRun) {
          this.hasShownWelcome = true;
          this.navPathStack.pushPathByName('WelcomePage', null);
        }
      }

      if (this.adaptiveGripEnabled) {
        await this.startGripAwareness();
      }
    } catch (e) {
      this.isLoading = false;
      console.error('Index', `aboutToAppear skipped: ${JSON.stringify(e)}`);
    }
  }

  aboutToDisappear(): void {
    this.stopGripAwareness();
  }

  private stopGripAwareness(): void {
    try {
      motion.off('holdingHandChanged', this.holdingHandCallback);
    } catch (e) {
      console.warn('Index', `holdingHandChanged off skipped: ${JSON.stringify(e)}`);
    }
  }

  private async startGripAwareness(): Promise<boolean> {
    this.stopGripAwareness();
    const hasPermission = await PermissionUtil.request(this.context, PermissionUtil.DETECT_GESTURE, 'Index');
    if (!hasPermission) {
      this.applyGripSide(false);
      return false;
    }
    try {
      motion.on('holdingHandChanged', this.holdingHandCallback);
      return true;
    } catch (e) {
      console.warn('Index', `holdingHandChanged unsupported or permission denied: ${JSON.stringify(e)}`);
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
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.isLeftHandHeld = leftHandHeld;
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
      font.registerFont({
        familyName: 'CangErJinKai',
        familySrc: $rawfile('fonts/canger_jinkai.ttf')
      });
      font.registerFont({
        familyName: 'LXGWWenKai',
        familySrc: $rawfile('fonts/lxgw_wenkai.ttf')
      });
    } catch (e) {
      console.warn('Index', `Register custom fonts skipped: ${JSON.stringify(e)}`);
    }
  }

  private showToast(message: ResourceStr | string): void {
    try {
      promptAction.showToast({ message: message });
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
    try {
      const feedCode = await this.prefs.getNumber('feed_code', 0);
      const feedMap = await this.coreUtil.getFeedInformation(feedCode);

      if (feedMap.feed_type === CoreUtil.FEED_TYPE_INTERNET) {
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
      const pixelMap = await componentSnapshot.get('onetext_save_card');
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
    Column() {
      this.HomeHeader()

      // 主内容区域 - 可滚动
      Refresh({ refreshing: $$this.isRefreshing, offset: 72 }) {
        Scroll() {
          Column() {
            Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              Column() {
                this.QuoteCard()
              }
              .width(this.isWideLayout() ? `${HOME_QUOTE_SPAN_WIDE}%` : '100%')
              .padding({ left: this.isWideLayout() ? 8 : 0, right: this.isWideLayout() ? 8 : 0 })

              Column() {
                this.HomeActionCard()
              }
              .width(this.isWideLayout() ? `${HOME_ACTION_SPAN_WIDE}%` : '100%')
              .padding({ left: this.isWideLayout() ? 8 : 0, right: this.isWideLayout() ? 8 : 0 })
            }
            .width('100%')
            .constraintSize({ maxWidth: this.getHomeContentMaxWidth() })
            .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE, bottom: UiStyle.FLOAT_TAB_BOTTOM_SPACE, top: 0 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
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

      if (this.sealVisible) {
        Image($r('app.media.moemiku'))
          .width(142)
          .height(142)
          .opacity(0.16)
          .position({ x: 176, y: 144 })
          .zIndex(1)
      }

      Column() {
        Blank()

        Text(this.oneText.text.replace(CoreUtil.TEXT_REPLACE_HOLDER, CoreUtil.TEXT_REPLACE))
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

      if (this.sealVisible) {
        Image($r('app.media.moemiku'))
          .width(this.isWideLayout() ? 166 : 142)
          .height(this.isWideLayout() ? 166 : 142)
          .opacity(0.18)
          .position({ x: this.isWideLayout() ? 356 : 176, y: this.isWideLayout() ? 166 : 144 })
          .zIndex(1)
      }

      Column() {
        Blank()

        if (this.oneText.text !== '') {
          Text(this.oneText.text.replace(CoreUtil.TEXT_REPLACE_HOLDER, CoreUtil.TEXT_REPLACE))
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
              this.copyToClipboard(this.oneText.text);
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
      .padding({ left: this.isWideLayout() ? 44 : 30, right: this.isWideLayout() ? 44 : 30, top: 62, bottom: 26 })
      .zIndex(2)
    }
    .id('onetext_card')
    .width('100%')
    .height(this.isWideLayout() ? 360 : 306)
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(18)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 24, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 8 })
  }

  @Builder
  HomeActionCard() {
    Column() {
      this.SaveActionRow()

      this.ActionRow($r('app.string.share_text'), $r('app.string.share_button'), () => {
        this.shareCurrentText();
      })

      this.ActionRow($r('app.string.refresh_onetext_text'), $r('app.string.refresh_button'), () => {
        this.refreshByPull();
      })

      this.ActionRow($r('app.string.seal_text'), this.sealVisible ? $r('app.string.seal_button_ison') : $r('app.string.seal_button_isoff'), async () => {
        this.sealVisible = !this.sealVisible;
        await this.prefs.putBoolean('seal_enabled', this.sealVisible);
        this.showToast(this.sealVisible ? $r('app.string.seal_button_ison') : $r('app.string.seal_button_isoff'));
      })

      this.FontSizeToggle()
      if (this.showFontSizeControls) {
        this.FontSizeSliderRow(this.textFontSize, 12, 48, 23, (value: number) => {
          this.setTextFontSize(value);
        })
        this.FontSizeSliderRow(this.byFontSize, 8, 36, 18, (value: number) => {
          this.setByFontSize(value);
        })
        this.FontSizeSliderRow(this.fromFontSize, 8, 24, 15, (value: number) => {
          this.setFromFontSize(value);
        })
        this.FontSizeSliderRow(this.timeFontSize, 8, 24, 15, (value: number) => {
          this.setTimeFontSize(value);
        })
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 20, bottom: 18 })
    .margin({ top: this.isWideLayout() ? 0 : 14 })
    .backgroundColor(this.getGlassCardColor())
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(26)
    .shadow({ radius: 18, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
  }

  @Builder
  HomeHeader() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.app_icon'))
            .width(42)
            .height(42)
            .borderRadius(12)
            .shadow({ radius: 10, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })

          Column() {
            Text('Hitokoto')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.colorText1'))
              .textShadow({ radius: 8, color: '#66000000', offsetX: 0, offsetY: 2 })

            Text($r('app.string.home_subtitle'))
              .fontSize(13)
              .fontColor($r('app.color.colorText4'))
              .margin({ top: 2 })
              .textShadow({ radius: 6, color: '#66000000', offsetX: 0, offsetY: 1 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Row() {
          this.HeaderIconButton($r('app.media.ic_heart'), $r('app.color.colorPrimary'), () => {
            this.openExternalLink(DONATE_URL);
          })
          this.HeaderIconButton($r('app.media.ic_settings'), $r('app.color.colorText2'), () => {
            this.navPathStack.pushPathByName('SettingsPage', null);
          })
        }
        .height(46)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(UiStyle.HEADER_HEIGHT)
    .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE, top: UiStyle.PAGE_TOP })
  }

  @Builder
  HeaderIconButton(icon: ResourceStr, iconColor: ResourceColor, onClick: () => void) {
    Stack() {
      Image(icon)
        .width(25)
        .height(25)
        .fillColor(iconColor)
    }
    .width(46)
    .height(46)
    .backgroundColor(this.getGlassCardColor())
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backdropBlur(18)
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(23)
    .shadow({ radius: 12, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 4 })
    .margin({ left: 12 })
    .onClick(() => {
      onClick();
    })
  }

  @Builder
  MinePage() {
    Column() {
      Scroll() {
        Column() {
          this.MineAccountHeader()
          this.MineFontCard()
          this.MineSettingsCard()
        }
        .width('100%')
        .constraintSize({ maxWidth: this.getMinePaneMaxWidth(), minHeight: MINE_PANE_MIN_HEIGHT })
        .padding({ left: MINE_PAGE_SIDE, right: MINE_PAGE_SIDE, top: MINE_PAGE_TOP, bottom: UiStyle.FLOAT_TAB_BOTTOM_SPACE })
        .alignItems(HorizontalAlign.Center)
        .translate({ y: MINE_PANE_OFFSET_Y })
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.START, SafeAreaEdge.END])
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  @Builder
  MineAccountHeader() {
    Column() {
      if (this.hasHuaweiAccount) {
        if (this.huaweiAccountAvatar.length > 0) {
          Image(this.huaweiAccountAvatar)
            .width(LOGGED_IN_AVATAR_SIZE)
            .height(LOGGED_IN_AVATAR_SIZE)
            .borderRadius(LOGGED_IN_AVATAR_RADIUS)
            .objectFit(ImageFit.Cover)
            .backgroundColor($r('app.color.colorSelectedBg'))
        } else {
          Image($r('app.media.app_icon'))
            .width(LOGGED_IN_AVATAR_SIZE)
            .height(LOGGED_IN_AVATAR_SIZE)
            .borderRadius(LOGGED_IN_AVATAR_RADIUS)
            .backgroundColor($r('app.color.colorSelectedBg'))
            .padding(12)
        }

        Text(this.huaweiAccountName)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ top: 12 })
      } else {
        Image($r('app.media.ic_user'))
          .width(90)
          .height(90)
          .opacity(0.78)

        Text($r('app.string.huawei_login_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.colorText1'))
          .margin({ top: 14 })

        Text($r('app.string.huawei_login_desc'))
          .fontSize(14)
          .fontColor($r('app.color.colorText4'))
          .textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: 18 })

        Button($r('app.string.huawei_login_button'))
          .width(220)
          .height(46)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.colorPrimary'))
          .borderRadius(23)
          .onClick(async () => {
            await this.loginWithHuaweiAccount();
          })
      }
    }
    .width('100%')
    .height(MINE_ACCOUNT_HEADER_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 16, right: 16, top: 5, bottom: 5 })
    .alignItems(HorizontalAlign.Center)
    .translate({ y: MINE_ACCOUNT_HEADER_OFFSET_Y })
  }

  @Builder
  MineFontCard() {
    Column() {
      Text($r('app.string.font_style'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorText1'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 18 })

      this.FontStyleOptions()
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 24, bottom: 12 })
    .backgroundColor(this.getGlassCardColor())
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 20, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
    .margin({ top: MINE_FONT_CARD_TOP })
    .translate({ y: MINE_FONT_CARD_OFFSET_Y })
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
          .color('#EEF2F7')
          .margin({ top: 4, bottom: 4 })

        this.MineLogoutRow()
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 8 })
    .margin({ top: MINE_SETTINGS_CARD_TOP })
    .backgroundColor(this.getGlassCardColor())
    .border({ width: 1, color: this.getGlassCardBorder() })
    .borderRadius(UiStyle.CARD_RADIUS)
    .shadow({ radius: 18, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 6 })
    .translate({ y: MINE_SETTINGS_CARD_OFFSET_Y })
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
  SaveActionRow() {
    Flex({
      direction: this.isLeftHandHeld ? FlexDirection.Row : FlexDirection.RowReverse,
      alignItems: ItemAlign.Center
    }) {
      Column() {
        SaveButton({
          text: SaveDescription.SAVE,
          buttonType: ButtonType.Capsule
        })
          .borderRadius(21)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.colorPrimary'))
          .width(96)
          .height(44)
          .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
            if (result === SaveButtonOnClickResult.SUCCESS) {
              this.saveScreenshot();
              return;
            }
            if (result === SaveButtonOnClickResult.TEMPORARY_AUTHORIZATION_FAILED) {
              this.showToast($r('app.string.save_fail'));
            }
          })
      }
      .width(96)

      Text($r('app.string.save_text'))
        .fontSize(18)
        .fontColor($r('app.color.colorText2'))
        .layoutWeight(1)
        .margin(this.isLeftHandHeld ? { left: 20, right: 0 } : { left: 0, right: 20 })
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height(60)
    .padding({ bottom: 14 })
    .animation({ duration: 360, curve: Curve.Friction })
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
  FontSizeToggle() {
    Flex({
      direction: this.isLeftHandHeld ? FlexDirection.Row : FlexDirection.RowReverse,
      alignItems: ItemAlign.Center
    }) {
      Column() {
        Image($r('app.media.ic_expand'))
          .width(16)
          .height(16)
          .opacity(0.65)
          .rotate({ angle: this.showFontSizeControls ? 180 : 0 })
      }
      .width(96)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text('字号')
        .fontSize(18)
        .fontColor($r('app.color.colorText2'))
        .layoutWeight(1)
        .margin(this.isLeftHandHeld ? { left: 20, right: 0 } : { left: 0, right: 20 })
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height(50)
    .onClick(() => {
      this.showFontSizeControls = !this.showFontSizeControls;
    })
  }

  @Builder
  FontSizeSliderRow(value: number, min: number, max: number, defaultValue: number,
    onValueChange: (value: number) => void) {
    Row() {
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
        .margin({ left: 36, right: 24 })

      Text($r('app.string.default_text'))
        .fontSize(14)
        .fontColor($r('app.color.colorPrimary'))
        .width(82)
        .height(38)
        .textAlign(TextAlign.Center)
        .borderRadius(19)
        .backgroundColor(this.getGlassSelectedColor())
        .border({ width: 1, color: this.getGlassCardBorder() })
        .padding({ top: 10 })
        .onClick(() => {
          onValueChange(defaultValue);
        })
    }
    .width('100%')
    .padding({ bottom: 16 })
  }
}
