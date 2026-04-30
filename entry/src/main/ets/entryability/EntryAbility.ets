import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { AppLanguageUtil } from '../common/AppLanguageUtil';
import { AppDisplayModeUtil } from '../common/AppDisplayModeUtil';
import { AppBackgroundUtil } from '../common/AppBackgroundUtil';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

/**
 * 应用入口 Ability
 * HarmonyOS 6: 支持全面屏沉浸式布局，页面内容自行处理安全区间距
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');

    // 初始化偏好设置
    const prefs = PreferencesUtil.getInstance();
    await prefs.init(this.context);
    AppLanguageUtil.apply(this.context, await prefs.getNumber(AppLanguageUtil.PREF_KEY, 0));
    const displayModeIndex = await prefs.getNumber(AppDisplayModeUtil.PREF_KEY, 0);
    AppDisplayModeUtil.apply(this.context, displayModeIndex);

    // 开启全屏布局，让页面背景延伸到系统栏区域。
    const mainWindow = await windowStage.getMainWindow();
    await mainWindow.setWindowLayoutFullScreen(true);
    await mainWindow.setWindowSystemBarProperties(AppDisplayModeUtil.getSystemBarProperties(this.context,
      displayModeIndex));

    // 加载主页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, `Failed to load content. Code: ${err.code}, message: ${err.message}`);
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
    this.refreshAppBackground();
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }

  private async refreshAppBackground(): Promise<void> {
    try {
      const prefs = PreferencesUtil.getInstance();
      await prefs.init(this.context);
      await AppBackgroundUtil.refreshApiBackground(prefs);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `refreshAppBackground skipped: ${JSON.stringify(e)}`);
    }
  }
}
