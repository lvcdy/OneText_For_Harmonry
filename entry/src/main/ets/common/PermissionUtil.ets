import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

export class PermissionUtil {
  static readonly DETECT_GESTURE: Permissions = 'ohos.permission.DETECT_GESTURE';

  static async request(context: common.Context, permission: Permissions, tag: string): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, [permission]);
      return result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      console.warn(tag, `request permission ${permission} skipped: ${JSON.stringify(e)}`);
      return false;
    }
  }
}
