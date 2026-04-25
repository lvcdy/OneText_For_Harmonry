import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { AppLanguageUtil } from '../common/AppLanguageUtil';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

/**
 * 应用入口 Ability
 * HarmonyOS 6: 支持沉浸式状态栏、安全区域适配
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
    await PreferencesUtil.getInstance().init(this.context);
    AppLanguageUtil.apply(this.context, await PreferencesUtil.getInstance().getNumber(AppLanguageUtil.PREF_KEY, 0));

    // 交给系统安全区布局，页面内只维护视觉留白，避免不同设备顶部间距忽高忽低。
    const mainWindow = await windowStage.getMainWindow();
    const sysBarProps: window.SystemBarProperties = {
      statusBarContentColor: '#000000',
      navigationBarContentColor: '#000000'
    };
    await mainWindow.setWindowSystemBarProperties(sysBarProps);

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
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }
}
