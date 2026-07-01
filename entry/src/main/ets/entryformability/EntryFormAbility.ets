import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CoreUtil } from '../common/CoreUtil';
import { FormUtil } from '../common/FormUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';

const TAG = 'EntryFormAbility';
const DOMAIN = 0x0000;

/**
 * 桌面卡片 FormExtensionAbility
 * HarmonyOS 7: 支持 formId 持久化存储，确保卡片在重启后仍可正常更新
 */
export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'onAddForm');

    // HarmonyOS 7: 持久化存储 formId，确保后续可更新
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;
    if (formId) {
      this.saveFormId(formId);
      this.updateWidgetData(formId, true);
    }

    return formBindingData.createFormBindingData(FormUtil.DEFAULT_FORM_DATA);
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
    if (this.isRefreshMessage(message)) {
      this.updateWidgetData(formId, true);
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
      await FormUtil.saveFormId(this.context, formId);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `saveFormId error: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 移除已删除的 formId
   */
  private async removeFormId(formId: string): Promise<void> {
    try {
      await FormUtil.removeFormId(this.context, formId);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `removeFormId error: ${JSON.stringify(e)}`);
    }
  }

  private isRefreshMessage(message: string): boolean {
    if (message === 'refresh') {
      return true;
    }
    try {
      const params = JSON.parse(message) as Record<string, string>;
      return params.message === 'refresh';
    } catch (e) {
      return false;
    }
  }

  private async updateWidgetData(formId: string, forceRefresh: boolean = false): Promise<void> {
    try {
      await PreferencesUtil.getInstance().init(this.context);
      const coreUtil = new CoreUtil(this.context);
      await coreUtil.initFeedFile();
      const formData = await coreUtil.buildWidgetFormData(forceRefresh);
      if (formData) {
        await FormUtil.updateForm(formId, formData);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `updateWidgetData error: ${JSON.stringify(e)}`);
    }
  }
}
