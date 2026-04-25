import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';

export class AppLanguageUtil {
  static readonly PREF_KEY: string = 'language_type';
  private static readonly LANGUAGES: string[] = ['zh-Hans', 'zh-Hant', 'en'];

  static getLanguage(index: number): string {
    if (index < 0 || index >= AppLanguageUtil.LANGUAGES.length) {
      return AppLanguageUtil.LANGUAGES[0];
    }
    return AppLanguageUtil.LANGUAGES[index];
  }

  static apply(context: common.Context, index: number): void {
    const language = AppLanguageUtil.getLanguage(index);
    try {
      i18n.System.setAppPreferredLanguage(language);
      context.getApplicationContext().setLanguage(language);
    } catch (e) {
      console.warn('AppLanguageUtil', `setLanguage failed: ${JSON.stringify(e)}`);
    }
  }

  static setPreferredLanguage(index: number): void {
    const language = AppLanguageUtil.getLanguage(index);
    try {
      i18n.System.setAppPreferredLanguage(language);
    } catch (e) {
      console.warn('AppLanguageUtil', `setAppPreferredLanguage failed: ${JSON.stringify(e)}`);
    }
  }
}
