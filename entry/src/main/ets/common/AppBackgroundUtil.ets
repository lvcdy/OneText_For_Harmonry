import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { PreferencesUtil } from './PreferencesUtil';

export enum AppBackgroundMode {
  DEFAULT = 0,
  LOCAL_IMAGE = 1,
  IMAGE_API = 2
}

export class AppBackgroundUtil {
  static readonly STORAGE_KEY: string = 'appBackgroundUri';
  static readonly MODE_KEY: string = 'app_background_mode';
  static readonly LOCAL_URI_KEY: string = 'app_background_local_uri';
  private static readonly LOCAL_PATH_KEY: string = 'app_background_local_path';
  static readonly API_URI_KEY: string = 'app_background_api_uri';
  private static readonly BACKGROUND_DIR_NAME: string = 'Background';
  private static readonly LEGACY_BACKGROUND_FILE_NAME: string = 'app_background.jpg';

  private static ensureBackgroundDir(context: common.Context): string {
    const backgroundDir = `${context.filesDir}/${AppBackgroundUtil.BACKGROUND_DIR_NAME}`;
    try {
      if (fileIo.accessSync(backgroundDir)) {
        return backgroundDir;
      }
    } catch (e) {
    }
    fileIo.mkdirSync(backgroundDir, true);
    return backgroundDir;
  }

  private static deleteFileIfExists(path: string): void {
    if (path === '') {
      return;
    }
    try {
      fileIo.unlinkSync(path);
    } catch (e) {
    }
  }

  static async getMode(prefs: PreferencesUtil): Promise<AppBackgroundMode> {
    const mode = await prefs.getNumber(AppBackgroundUtil.MODE_KEY, AppBackgroundMode.DEFAULT);
    if (mode === AppBackgroundMode.LOCAL_IMAGE || mode === AppBackgroundMode.IMAGE_API) {
      return mode;
    }
    return AppBackgroundMode.DEFAULT;
  }

  static async getApiUri(prefs: PreferencesUtil): Promise<string> {
    return await prefs.getString(AppBackgroundUtil.API_URI_KEY, '');
  }

  static async getBackgroundUri(prefs: PreferencesUtil): Promise<string> {
    const mode = await AppBackgroundUtil.getMode(prefs);
    if (mode === AppBackgroundMode.LOCAL_IMAGE) {
      const uri = await prefs.getString(AppBackgroundUtil.LOCAL_URI_KEY, '');
      AppBackgroundUtil.syncStorage(uri);
      return uri;
    }
    if (mode === AppBackgroundMode.IMAGE_API) {
      const uri = await prefs.getString(AppBackgroundUtil.API_URI_KEY, '');
      AppBackgroundUtil.syncStorage(uri);
      return uri;
    }
    AppBackgroundUtil.syncStorage('');
    return '';
  }

  static async setDefault(prefs: PreferencesUtil): Promise<string> {
    await prefs.putNumber(AppBackgroundUtil.MODE_KEY, AppBackgroundMode.DEFAULT);
    AppBackgroundUtil.syncStorage('');
    return '';
  }

  static async setApi(prefs: PreferencesUtil, apiUri: string): Promise<string> {
    await prefs.putString(AppBackgroundUtil.API_URI_KEY, apiUri);
    await prefs.putNumber(AppBackgroundUtil.MODE_KEY, AppBackgroundMode.IMAGE_API);
    AppBackgroundUtil.syncStorage(apiUri);
    return apiUri;
  }

  static async saveLocalImage(context: common.Context, prefs: PreferencesUtil, sourceUri: string): Promise<string> {
    const backgroundDir = AppBackgroundUtil.ensureBackgroundDir(context);
    AppBackgroundUtil.deleteFileIfExists(await prefs.getString(AppBackgroundUtil.LOCAL_PATH_KEY, ''));
    AppBackgroundUtil.deleteFileIfExists(`${backgroundDir}/${AppBackgroundUtil.LEGACY_BACKGROUND_FILE_NAME}`);

    const targetPath = `${backgroundDir}/app_background_${Date.now()}.jpg`;
    const sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.copyFileSync(sourceFile.fd, targetPath);
    } finally {
      fileIo.closeSync(sourceFile);
    }

    const targetUri = fileUri.getUriFromPath(targetPath);
    await prefs.putString(AppBackgroundUtil.LOCAL_PATH_KEY, targetPath);
    await prefs.putString(AppBackgroundUtil.LOCAL_URI_KEY, targetUri);
    await prefs.putNumber(AppBackgroundUtil.MODE_KEY, AppBackgroundMode.LOCAL_IMAGE);
    AppBackgroundUtil.syncStorage(targetUri);
    return targetUri;
  }

  static syncStorage(uri: string): void {
    AppStorage.setOrCreate<string>(AppBackgroundUtil.STORAGE_KEY, uri);
  }
}

@Component
export struct AppBackgroundLayer {
  @StorageLink('appBackgroundUri') backgroundUri: string = '';

  build() {
    Stack() {
      if (this.backgroundUri !== '') {
        Image(this.backgroundUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(0.9)

        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#26000000')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.colorBackground'))
  }
}
