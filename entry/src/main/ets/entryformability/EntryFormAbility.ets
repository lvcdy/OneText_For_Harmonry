import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { CoreUtil } from '../common/CoreUtil';

const TAG = 'EntryFormAbility';
const DOMAIN = 0x0000;

/**
 * 桌面卡片 FormExtensionAbility
 * HarmonyOS 6: 支持 formId 持久化存储，确保卡片在重启后仍可正常更新
 */
export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'onAddForm');

    // HarmonyOS 6: 持久化存储 formId，确保后续可更新
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;
    if (formId) {
      this.saveFormId(formId);
    }

    const formData: Record<string, string> = {
      'text': '生活不止眼前的苟且，还有诗和远方。',
      'by': '高晓松',
      'widget_dark': 'false',
      'widget_shadow': 'true',
      'widget_center': 'true'
    };
    return formBindingData.createFormBindingData(formData);
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onCastToNormalForm, formId: ${formId}`);
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onUpdateForm, formId: ${formId}`);
    this.updateWidgetData(formId);
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, `onFormEvent, formId: ${formId}, message: ${message}`);
    if (message === 'refresh') {
      this.updateWidgetData(formId);
    }
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onRemoveForm, formId: ${formId}`);
    this.removeFormId(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  /**
   * 持久化存储 formId
   */
  private async saveFormId(formId: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'form_ids');
      const idsStr = (await prefs.get('form_id_list', '')) as string;
      const ids = idsStr ? idsStr.split(',') : [];
      if (!ids.includes(formId)) {
        ids.push(formId);
        await prefs.put('form_id_list', ids.join(','));
        await prefs.flush();
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `saveFormId error: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 移除已删除的 formId
   */
  private async removeFormId(formId: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, 'form_ids');
      const idsStr = (await prefs.get('form_id_list', '')) as string;
      const ids = idsStr ? idsStr.split(',').filter((id: string) => id !== formId) : [];
      await prefs.put('form_id_list', ids.join(','));
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, `removeFormId error: ${JSON.stringify(e)}`);
    }
  }

  private async updateWidgetData(formId: string): Promise<void> {
    try {
      const coreUtil = new CoreUtil(this.context);
      const formData = await coreUtil.buildWidgetFormData();
      if (formData) {
        const formBindData = formBindingData.createFormBindingData(formData);
        await formProvider.updateForm(formId, formBindData);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `updateWidgetData error: ${JSON.stringify(e)}`);
    }
  }
}
