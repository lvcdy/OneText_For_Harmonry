import { common, ConfigurationConstant } from '@kit.AbilityKit';

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

  static apply(context: common.Context, index: number): void {
    try {
      context.getApplicationContext().setColorMode(AppDisplayModeUtil.getColorMode(index));
    } catch (e) {
      console.warn('AppDisplayModeUtil', `setColorMode failed: ${JSON.stringify(e)}`);
    }
  }
}
