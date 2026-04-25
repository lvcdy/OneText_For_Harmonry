import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { CoreUtil } from './CoreUtil';

export class FormUtil {
  static readonly PREF_NAME: string = 'form_ids';
  static readonly FORM_ID_LIST_KEY: string = 'form_id_list';
  static readonly DEFAULT_FORM_DATA: Record<string, string> = {
    'text': '生活不止眼前的苟且，还有诗和远方。',
    'by': '高晓松',
    'widget_dark': 'false',
    'widget_shadow': 'true',
    'widget_center': 'true'
  };

  private static parseFormIds(idsStr: string): string[] {
    return idsStr ? idsStr.split(',').filter((id: string) => id !== '') : [];
  }

  static async getFormIds(context: common.Context): Promise<string[]> {
    const prefs = await preferences.getPreferences(context, FormUtil.PREF_NAME);
    const idsStr = (await prefs.get(FormUtil.FORM_ID_LIST_KEY, '')) as string;
    return FormUtil.parseFormIds(idsStr);
  }

  static async saveFormId(context: common.Context, formId: string): Promise<void> {
    if (formId === '') {
      return;
    }

    const prefs = await preferences.getPreferences(context, FormUtil.PREF_NAME);
    const idsStr = (await prefs.get(FormUtil.FORM_ID_LIST_KEY, '')) as string;
    const ids = FormUtil.parseFormIds(idsStr);
    if (ids.includes(formId)) {
      return;
    }

    ids.push(formId);
    await prefs.put(FormUtil.FORM_ID_LIST_KEY, ids.join(','));
    await prefs.flush();
  }

  static async removeFormId(context: common.Context, formId: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, FormUtil.PREF_NAME);
    const idsStr = (await prefs.get(FormUtil.FORM_ID_LIST_KEY, '')) as string;
    const ids = FormUtil.parseFormIds(idsStr).filter((id: string) => id !== formId);
    await prefs.put(FormUtil.FORM_ID_LIST_KEY, ids.join(','));
    await prefs.flush();
  }

  static async updateForm(formId: string, formData: Record<string, string>): Promise<void> {
    const bindingData = formBindingData.createFormBindingData(formData);
    await formProvider.updateForm(formId, bindingData);
  }

  static async refreshForms(context: common.Context, coreUtil: CoreUtil): Promise<number> {
    const ids = await FormUtil.getFormIds(context);
    if (ids.length === 0) {
      return 0;
    }

    const formData = await coreUtil.buildWidgetFormData();
    if (!formData) {
      return 0;
    }

    const bindingData = formBindingData.createFormBindingData(formData);
    for (const formId of ids) {
      await formProvider.updateForm(formId, bindingData);
    }
    return ids.length;
  }
}
