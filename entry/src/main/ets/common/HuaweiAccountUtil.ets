import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { authentication } from '@kit.AccountKit';

export interface HuaweiAccountProfile {
  name: string;
  avatar: string;
}

export interface HuaweiAccountLoginResult extends HuaweiAccountProfile {
  idToken: string;
}

export class HuaweiAccountUtil {
  static readonly FALLBACK_NAME: string = '华为账号用户';

  static parseIdToken(idToken: string): HuaweiAccountProfile {
    const profile: HuaweiAccountProfile = { name: '', avatar: '' };
    const parts = idToken.split('.');
    if (parts.length < 2) {
      return profile;
    }

    try {
      let payload = parts[1];
      while (payload.length % 4 !== 0) {
        payload += '=';
      }
      const base64Helper = new util.Base64Helper();
      const payloadBytes = base64Helper.decodeSync(payload, util.Type.BASIC_URL_SAFE);
      const decoder = new util.TextDecoder('utf-8');
      const payloadJson = decoder.decodeToString(payloadBytes);
      const payloadObj = JSON.parse(payloadJson) as Record<string, string>;
      profile.name = payloadObj.name ?? payloadObj.nickname ?? payloadObj.display_name ?? '';
      profile.avatar = payloadObj.picture ?? payloadObj.avatar ?? '';
    } catch (e) {
      console.warn('HuaweiAccountUtil', `Parse Huawei ID Token skipped: ${JSON.stringify(e)}`);
    }
    return profile;
  }

  static async authorize(context: common.UIAbilityContext): Promise<HuaweiAccountLoginResult> {
    const provider = new authentication.HuaweiIDProvider();
    const request = provider.createAuthorizationWithHuaweiIDRequest();
    request.scopes = ['profile'];
    request.forceAuthorization = true;
    request.state = 'onetext_login';
    request.nonce = 'onetext_login_nonce';
    request.supportAtomicService = true;

    const controller = new authentication.AuthenticationController(context);
    const response = await controller.executeRequest(request) as authentication.AuthorizationWithHuaweiIDResponse;
    const idToken = response.data?.idToken ?? '';
    const tokenProfile = HuaweiAccountUtil.parseIdToken(idToken);
    return {
      idToken: idToken,
      name: response.data?.nickName ?? tokenProfile.name,
      avatar: response.data?.avatarUri ?? tokenProfile.avatar
    };
  }

  static async cancelAuthorization(context: common.UIAbilityContext): Promise<void> {
    const provider = new authentication.HuaweiIDProvider();
    const request = provider.createCancelAuthorizationRequest();
    request.state = 'onetext_logout';
    const controller = new authentication.AuthenticationController(context);
    await controller.executeRequest(request);
  }
}
