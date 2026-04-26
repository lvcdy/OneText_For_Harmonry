import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export class AppDisplayModeUtil {
  static readonly PREF_KEY: string = 'interface_daynight';

  static getColorMode(index: number): ConfigurationConstant.ColorMode {
    if (index === 1) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    if (index === 2) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }

  private static isDarkMode(context: common.UIAbilityContext, index: number): boolean {
    if (index === 2) {
      return true;
    }
    if (index === 1) {
      return false;
    }
    return context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  static getSystemBarProperties(context: common.UIAbilityContext, index: number): window.SystemBarProperties {
    const darkMode = AppDisplayModeUtil.isDarkMode(context, index);
    const contentColor = darkMode ? '#FFFFFF' : '#000000';
    return {
      statusBarColor: '#00000000',
      statusBarContentColor: contentColor,
      isStatusBarLightIcon: darkMode,
      navigationBarColor: '#00000000',
      navigationBarContentColor: contentColor,
      isNavigationBarLightIcon: darkMode
    };
  }

  static apply(context: common.UIAbilityContext, index: number): void {
    try {
      context.getApplicationContext().setColorMode(AppDisplayModeUtil.getColorMode(index));
    } catch (e) {
      console.warn('AppDisplayModeUtil', `setColorMode failed: ${JSON.stringify(e)}`);
    }
  }

  static async applySystemBars(context: common.UIAbilityContext, index: number): Promise<void> {
    try {
      const currentWindow = await window.getLastWindow(context);
      await currentWindow.setWindowSystemBarProperties(AppDisplayModeUtil.getSystemBarProperties(context, index));
    } catch (e) {
      console.warn('AppDisplayModeUtil', `setWindowSystemBarProperties failed: ${JSON.stringify(e)}`);
    }
  }
}
