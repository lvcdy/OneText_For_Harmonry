import { common } from '@kit.AbilityKit';
import { OneTextItem, FeedConfig } from '../model/DataModels';
import { PreferencesUtil } from './PreferencesUtil';
import { FileUtil } from './FileUtil';
import { HttpUtil } from './HttpUtil';
import { WidgetBackgroundUtil } from './AppBackgroundUtil';
import { AppLanguageUtil } from './AppLanguageUtil';

/**
 * 核心业务逻辑工具类 - 替代 Android CoreUtil
 * 负责 Hitokoto 数据的读取、随机选取、订阅源管理等
 */
export class CoreUtil {
  static readonly API_MISSING_TEXT: string = '把一句话留在今天';
  static readonly TEXT_REPLACE_HOLDER: string = '@@';
  static readonly TEXT_REPLACE: string = '\n';
  static readonly FEED_TYPE_REMOTE: string = 'remote';
  static readonly FEED_TYPE_LOCAL: string = 'local';
  static readonly FEED_TYPE_INTERNET: string = 'internet';

  private static readonly ONE_TEXT_DIR_NAME: string = 'OneText';
  private static readonly ONE_TEXT_FILE_NAME: string = 'OneText-Library.json';
  private static readonly FEED_DIR_NAME: string = 'Feed';
  private static readonly FEED_FILE_NAME: string = 'Feed.json';
  private static readonly ONE_TEXT_MISSING_JSON: string = '[{"text":"File does not exist."}]';
  private static readonly FEED_MISSING_JSON: string =
    '[{"feed_name":"File does not exist.","feed_type":"remote","text_key":"text"}]';

  private context: common.Context;
  private prefs: PreferencesUtil;

  constructor(context: common.Context) {
    this.context = context;
    this.prefs = PreferencesUtil.getInstance();
  }

  private getOneTextDir(): string {
    return `${this.context.filesDir}/${CoreUtil.ONE_TEXT_DIR_NAME}`;
  }

  private getOneTextFilePath(): string {
    return `${this.getOneTextDir()}/${CoreUtil.ONE_TEXT_FILE_NAME}`;
  }

  private getFeedDir(): string {
    return `${this.context.filesDir}/${CoreUtil.FEED_DIR_NAME}`;
  }

  private getFeedFilePath(): string {
    return `${this.getFeedDir()}/${CoreUtil.FEED_FILE_NAME}`;
  }

  private createEmptyOneText(): OneTextItem {
    return {
      text: '',
      by: '',
      from: '',
      time: '',
      uri: '',
      quote1: '"',
      quote2: '"'
    };
  }

  private createApiMissingOneText(): OneTextItem {
    return {
      text: CoreUtil.API_MISSING_TEXT,
      by: '',
      from: '',
      time: '',
      uri: '',
      quote1: '"',
      quote2: '"'
    };
  }

  private parseOneTextArray(arrayStr: string, feedMap: FeedConfig, action: string): Record<string, string>[] {
    try {
      const payload = JSON.parse(arrayStr) as Object;
      const resolvedPayload = this.resolveFeedPayload(payload, feedMap);
      if (Array.isArray(resolvedPayload)) {
        return resolvedPayload as Record<string, string>[];
      }
      if (this.isJsonObject(resolvedPayload)) {
        return [resolvedPayload as Record<string, string>];
      }
      return [];
    } catch (e) {
      console.error('CoreUtil', `${action} error: ${JSON.stringify(e)}`);
      return [];
    }
  }

  private isJsonObject(value: Object | null | undefined): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value);
  }

  private resolveFeedPayload(payload: Object, feedMap: FeedConfig): Object {
    if (feedMap.object_key && feedMap.object_key.trim() !== '') {
      const nestedValue = this.getNestedValue(payload, feedMap.object_key.trim());
      if (nestedValue !== null) {
        return nestedValue;
      }
    }

    if (Array.isArray(payload)) {
      return payload;
    }

    if (this.isJsonObject(payload)) {
      const objectPayload = payload as Record<string, Object>;
      const candidateKeys = ['data', 'list', 'items', 'result', 'results'];
      for (const key of candidateKeys) {
        const candidate = objectPayload[key];
        if (Array.isArray(candidate) || this.isJsonObject(candidate)) {
          return candidate;
        }
      }
    }

    return payload;
  }

  private getNestedValue(payload: Object, objectKey: string): Object | null {
    const keys = objectKey.split('.');
    let current: Object = payload;
    for (const key of keys) {
      if (!this.isJsonObject(current)) {
        return null;
      }
      const nextValue = (current as Record<string, Object>)[key];
      if (nextValue === null || nextValue === undefined) {
        return null;
      }
      current = nextValue;
    }
    return current;
  }

  private getStringValue(jsonObj: Record<string, string>, key: string | undefined, defaultKey: string): string {
    const value = jsonObj[key ?? defaultKey] ?? '';
    if (typeof value === 'string') {
      return value;
    }
    return String(value);
  }

  private convertPreferredLanguage(text: string): string {
    if (text === '') {
      return '';
    }
    return AppLanguageUtil.convertText(text);
  }

  private convertOneTextLanguage(oneText: OneTextItem): OneTextItem {
    return {
      text: this.convertPreferredLanguage(oneText.text),
      by: this.convertPreferredLanguage(oneText.by),
      from: this.convertPreferredLanguage(oneText.from),
      time: this.convertPreferredLanguage(oneText.time),
      uri: oneText.uri,
      quote1: oneText.quote1,
      quote2: oneText.quote2
    };
  }

  private parseFeedArray(action: string): FeedConfig[] {
    try {
      return JSON.parse(this.getFeedArray()) as FeedConfig[];
    } catch (e) {
      console.error('CoreUtil', `${action} error: ${JSON.stringify(e)}`);
      return [];
    }
  }

  private writeFeeds(feeds: FeedConfig[]): boolean {
    return FileUtil.writeTextToFile(JSON.stringify(feeds), this.getFeedDir(), CoreUtil.FEED_FILE_NAME);
  }

  /**
   * 检查 Hitokoto 数据文件是否存在
   */
  private ifHaveOneTextFiles(): boolean {
    return FileUtil.isFile(this.getOneTextFilePath());
  }

  /**
   * 获取 Hitokoto 数据数组（JSON 字符串）
   */
  private async getOneTextArray(): Promise<string> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    if (feedMap.feed_type === CoreUtil.FEED_TYPE_REMOTE) {
      if (this.ifHaveOneTextFiles()) {
        return FileUtil.readTextFromFile(this.getOneTextFilePath());
      }

      return CoreUtil.ONE_TEXT_MISSING_JSON;
    } else if (feedMap.feed_type === CoreUtil.FEED_TYPE_LOCAL) {
      return FileUtil.readTextFromFile(feedMap.feed_path ?? '');
    }
    return '[]';
  }

  /**
   * 获取 Hitokoto 编号（随机或缓存）
   */
  private async getOneTextCode(forceRefresh: boolean, ifFromWidget: boolean): Promise<number> {
    if (forceRefresh) {
      return await this.generateNewOneTextCode();
    } else {
      if (await this.ifOneTextShouldUpdate(ifFromWidget)) {
        return await this.generateNewOneTextCode();
      } else {
        return await this.prefs.getNumber('onetext_code', 0);
      }
    }
  }

  /**
   * 生成新的随机 Hitokoto 编号
   */
  private async generateNewOneTextCode(): Promise<number> {
    const arrayStr = await this.getOneTextArray();
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    let code = 0;
    const arr = this.parseOneTextArray(arrayStr, feedMap, 'generateNewOneTextCode');
    if (arr.length > 0) {
      code = Math.floor(Math.random() * arr.length);
    }
    await this.refreshLatestRefreshTime();
    await this.prefs.putNumber('onetext_code', code);
    return code;
  }

  /**
   * 判断是否应该更新 Hitokoto
   */
  async ifOneTextShouldUpdate(ifFromWidget: boolean): Promise<boolean> {
    const currentTimeMillis = Date.now();
    if (ifFromWidget) {
      const latestRefreshTime = await this.prefs.getNumber('onetext_latest_refresh_time', 0);
      const refreshTime = Math.max(await this.prefs.getNumber('widget_refresh_time', 30), 30);
      return (currentTimeMillis - latestRefreshTime) >= (refreshTime * 60000);
    }

    const autoUpdate = await this.prefs.getBoolean('feed_auto_update', true);
    if (!autoUpdate) {
      return false;
    }
    const latestRefreshTime = await this.prefs.getNumber('onetext_latest_refresh_time', 0);
    const refreshTime = await this.prefs.getNumber('feed_refresh_time', 1);
    return (currentTimeMillis - latestRefreshTime) >= (refreshTime * 3600000);
  }

  /**
   * 刷新最新更新时间
   */
  async refreshLatestRefreshTime(): Promise<void> {
    await this.prefs.putNumber('onetext_latest_refresh_time', Date.now());
  }

  /**
   * 获取 Hitokoto 数据
   */
  async getOneText(forceRefresh: boolean, ifFromWidget: boolean): Promise<OneTextItem> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    const arrayStr = await this.getOneTextArray();
    const code = await this.getOneTextCode(forceRefresh, ifFromWidget);
    const arr = this.parseOneTextArray(arrayStr, feedMap, 'getOneText');
    if (arr.length > 0 && code < arr.length) {
      return this.convertOneText(arr[code], feedMap);
    }
    return this.createEmptyOneText();
  }

  async saveCurrentOneText(oneText: OneTextItem): Promise<void> {
    await this.prefs.putString('current_onetext', JSON.stringify(oneText));
  }

  async getCurrentOneText(): Promise<OneTextItem | null> {
    const currentOneText = await this.prefs.getString('current_onetext', '');
    if (currentOneText === '') {
      return null;
    }
    try {
      return JSON.parse(currentOneText) as OneTextItem;
    } catch (e) {
      console.error('CoreUtil', `getCurrentOneText error: ${JSON.stringify(e)}`);
      return null;
    }
  }

  /**
   * 获取组合文本（支持 && 多字段拼接）
   */
  getComposeText(jsonObj: Record<string, string>, feedMap: FeedConfig): string {
    const textKey = feedMap.text_key ?? 'text';
    if (textKey.includes('&&')) {
      const keys = textKey.split('&&');
      let text = '';
      for (let i = 0; i < keys.length; i++) {
        text += this.getStringValue(jsonObj, keys[i], 'text');
        if (i < keys.length - 1) {
          text += CoreUtil.TEXT_REPLACE_HOLDER;
        }
      }
      return text;
    }
    return this.getStringValue(jsonObj, textKey, 'text');
  }

  /**
   * 转换 Hitokoto 数据（包括简繁转换）
   */
  convertOneText(jsonObj: Record<string, string>, feedMap: FeedConfig): OneTextItem {
    const text = this.getComposeText(jsonObj, feedMap);
    const by = this.getStringValue(jsonObj, feedMap.by_key, 'by');
    const from = this.getStringValue(jsonObj, feedMap.from_key, 'from');
    const uri = this.getStringValue(jsonObj, feedMap.uri_key, 'uri');

    // 处理时间字段
    let time = '';
    try {
      const timeStr = this.getStringValue(jsonObj, feedMap.time_key, 'time');
      if (timeStr.startsWith('[')) {
        const timeArr: string[] = JSON.parse(timeStr) as string[];
        const timeOfRecord = timeArr[0] ?? '';
        const timeOfCreation = timeArr.length > 1 ? timeArr[1] : '';
        if (timeOfCreation) {
          time = `记录于：${timeOfRecord} 创作于：${timeOfCreation}`;
        } else if (timeOfRecord) {
          time = `记录于：${timeOfRecord}`;
        }
      } else {
        time = timeStr;
      }
    } catch (e) {
      time = this.getStringValue(jsonObj, feedMap.time_key, 'time');
    }

    return {
      text: this.convertPreferredLanguage(text),
      by: this.convertPreferredLanguage(by),
      from: this.convertPreferredLanguage(from),
      time: this.convertPreferredLanguage(time),
      uri: uri,
      quote1: '"',
      quote2: '"'
    };
  }

  /**
   * 初始化订阅源文件
   */
  async initFeedFile(): Promise<boolean> {
    if (!FileUtil.isFile(this.getFeedFilePath())) {
      return await FileUtil.copyRawFileToDir(this.context, CoreUtil.FEED_FILE_NAME, this.getFeedDir(),
        CoreUtil.FEED_FILE_NAME);
    }
    return true;
  }

  /**
   * 初始化 Hitokoto（下载远程数据或读取本地文件）
   */
  async initOneText(): Promise<boolean> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    if (feedMap.feed_type === CoreUtil.FEED_TYPE_REMOTE) {
      if (this.ifHaveOneTextFiles()) {
        return true;
      }
      // 下载远程数据
      try {
        const data = await HttpUtil.downloadText(feedMap.feed_url ?? '');
        FileUtil.writeTextToFile(data, this.getOneTextDir(), CoreUtil.ONE_TEXT_FILE_NAME);
        return true;
      } catch (e) {
        console.error('CoreUtil', `initOneText download error: ${JSON.stringify(e)}`);
        return false;
      }
    } else if (feedMap.feed_type === CoreUtil.FEED_TYPE_LOCAL) {
      return FileUtil.isFile(feedMap.feed_path ?? '');
    }
    return true;
  }

  /**
   * 通过 API 获取 Hitokoto（internet 类型订阅源）
   */
  async getOneTextFromApi(feedMap: FeedConfig): Promise<OneTextItem> {
    try {
      const apiUrl = (feedMap.api_url ?? feedMap.feed_url ?? '').trim();
      if (apiUrl === '') {
        return this.createApiMissingOneText();
      }
      const result = await HttpUtil.request(apiUrl, feedMap.api_method ?? 'GET');
      await this.prefs.putString('api_string', result);
      return this.convertApiResponse(result, feedMap) ?? this.createEmptyOneText();
    } catch (e) {
      console.error('CoreUtil', `getOneTextFromApi error: ${JSON.stringify(e)}`);
      return this.createEmptyOneText();
    }
  }

  convertApiResponse(result: string, feedMap: FeedConfig): OneTextItem | null {
    try {
      const payload = JSON.parse(result) as Object;
      const resolvedPayload = this.resolveFeedPayload(payload, feedMap);
      let jsonObj: Record<string, string> | null = null;
      if (Array.isArray(resolvedPayload) && resolvedPayload.length > 0) {
        const index = Math.floor(Math.random() * resolvedPayload.length);
        jsonObj = resolvedPayload[index] as Record<string, string>;
      } else if (this.isJsonObject(resolvedPayload)) {
        jsonObj = resolvedPayload as Record<string, string>;
      }
      if (jsonObj === null) {
        return null;
      }
      return this.convertOneText(jsonObj, feedMap);
    } catch (e) {
      console.error('CoreUtil', `convertApiResponse error: ${JSON.stringify(e)}`);
      return null;
    }
  }

  /**
   * 获取订阅源配置信息
   */
  async getFeedInformation(position: number): Promise<FeedConfig> {
    const feeds = this.parseFeedArray('getFeedInformation');
    if (position >= 0 && position < feeds.length) {
      return feeds[position];
    }
    return {
      feed_name: 'Unknown',
      feed_type: CoreUtil.FEED_TYPE_REMOTE,
      text_key: 'text'
    };
  }

  /**
   * 获取订阅源数组 JSON 字符串
   */
  private getFeedArray(): string {
    if (FileUtil.isFile(this.getFeedFilePath())) {
      return FileUtil.readTextFromFile(this.getFeedFilePath());
    }
    return CoreUtil.FEED_MISSING_JSON;
  }

  /**
   * 获取所有订阅源列表
   */
  getAllFeeds(): FeedConfig[] {
    return this.parseFeedArray('getAllFeeds');
  }

  /**
   * 添加订阅源
   */
  async addFeed(feedName: string, feedType: string, feedURL?: string, feedPath?: string, textKey: string = 'text',
    byKey: string = 'by', fromKey: string = 'from', timeKey: string = 'time', uriKey: string = 'uri',
    objectKey: string = '', apiMethod: string = 'GET'): Promise<void> {
    const feeds = this.getAllFeeds();
    const newFeed: FeedConfig = {
      feed_name: feedName,
      feed_type: feedType,
      feed_url: feedType === CoreUtil.FEED_TYPE_REMOTE ? (feedURL ?? '') : '',
      feed_path: feedPath ?? '',
      api_url: feedType === CoreUtil.FEED_TYPE_INTERNET ? (feedURL ?? '') : '',
      api_method: apiMethod,
      text_key: textKey,
      by_key: byKey,
      from_key: fromKey,
      time_key: timeKey,
      uri_key: uriKey,
      object_key: objectKey
    };
    feeds.push(newFeed);
    this.writeFeeds(feeds);
  }

  async updateFeed(position: number, feedName: string, feedUrl: string, textKey?: string, byKey?: string,
    fromKey?: string, timeKey?: string, uriKey?: string, objectKey?: string, apiMethod?: string): Promise<void> {
    const feeds = this.getAllFeeds();
    if (position < 0 || position >= feeds.length) {
      return;
    }
    const feed = feeds[position];
    feed.feed_name = feedName;
    if (feed.feed_type === CoreUtil.FEED_TYPE_INTERNET) {
      feed.api_url = feedUrl;
      feed.feed_url = '';
    } else if (feed.feed_type === CoreUtil.FEED_TYPE_LOCAL) {
      feed.feed_path = feedUrl;
    } else {
      feed.feed_url = feedUrl;
    }
    feed.text_key = textKey ?? feed.text_key ?? 'text';
    feed.by_key = byKey ?? feed.by_key ?? 'by';
    feed.from_key = fromKey ?? feed.from_key ?? 'from';
    feed.time_key = timeKey ?? feed.time_key ?? 'time';
    feed.uri_key = uriKey ?? feed.uri_key ?? 'uri';
    feed.object_key = objectKey ?? feed.object_key ?? '';
    feed.api_method = apiMethod ?? feed.api_method ?? 'GET';
    this.writeFeeds(feeds);
    await this.clearOneTextCache();
  }

  async clearOneTextCache(): Promise<void> {
    await this.prefs.remove('api_string');
    await this.prefs.remove('current_onetext');
    await this.prefs.remove('onetext_code');
    await this.prefs.remove('onetext_latest_refresh_time');
    await this.prefs.remove('feed_latest_refresh_time');
    FileUtil.deleteFile(this.getOneTextFilePath());
  }

  /**
   * 删除订阅源
   */
  async deleteFeed(position: number): Promise<void> {
    const feeds = this.getAllFeeds();
    if (position < 0 || position >= feeds.length) {
      return;
    }

    const feedCode = await this.prefs.getNumber('feed_code', 0);
    if (feedCode > position) {
      await this.prefs.putNumber('feed_code', feedCode - 1);
    } else if (feedCode === position) {
      const feedInfo = await this.getFeedInformation(position);
      if (feedInfo.feed_type === CoreUtil.FEED_TYPE_REMOTE) {
        FileUtil.deleteFile(this.getOneTextFilePath());
      }
      await this.prefs.remove('feed_code');
      await this.prefs.remove('feed_latest_refresh_time');
      await this.clearOneTextCache();
    }
    feeds.splice(position, 1);
    this.writeFeeds(feeds);
  }

  /**
   * 运行 Hitokoto 更新检查
   */
  async runOneTextUpdate(): Promise<boolean> {
    const currentTimeMillis = Date.now();
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    if (feedMap.feed_type === CoreUtil.FEED_TYPE_REMOTE) {
      const autoUpdate = await this.prefs.getBoolean('feed_auto_update', true);
      if (autoUpdate) {
        const latestRefreshTime = await this.prefs.getNumber('feed_latest_refresh_time', 0);
        const refreshTime = await this.prefs.getNumber('feed_refresh_time', 1);
        if ((currentTimeMillis - latestRefreshTime) > (refreshTime * 3600000)) {
          try {
            const data = await HttpUtil.downloadText(feedMap.feed_url ?? '');
            FileUtil.writeTextToFile(data, this.getOneTextDir(), CoreUtil.ONE_TEXT_FILE_NAME);
            await this.prefs.putNumber('feed_latest_refresh_time', currentTimeMillis);
            return true;
          } catch (e) {
            return false;
          }
        }
      }
    }
    return true;
  }

  /**
   * 构建小组件可直接使用的数据，包含正文和样式设置
   */
  async buildWidgetFormData(forceRefresh: boolean = false): Promise<Record<string, string> | null> {
    try {
      const feedCode = await this.prefs.getNumber('feed_code', 0);
      const feedMap = await this.getFeedInformation(feedCode);
      const isInternetFeed = feedMap.feed_type === CoreUtil.FEED_TYPE_INTERNET;
      const apiUrl = (feedMap.api_url ?? feedMap.feed_url ?? '').trim();
      let oneText: OneTextItem | null = null;

      if (isInternetFeed && apiUrl === '') {
        oneText = this.createApiMissingOneText();
      } else {
        oneText = await this.getCurrentOneText();
        if (!oneText) {
          oneText = isInternetFeed
            ? await this.getOneTextFromApi(feedMap)
            : (await this.initOneText() ? await this.getOneText(forceRefresh, true) : null);
        }
      }

      if (!oneText) {
        return null;
      }
      const convertedOneText = this.convertOneTextLanguage(oneText);
      await this.saveCurrentOneText(convertedOneText);

      const widgetDark = await this.prefs.getBoolean('widget_dark', false);
      const widgetShadow = await this.prefs.getBoolean('widget_shadow', true);
      const widgetCenter = await this.prefs.getBoolean('widget_center', true);
      const widgetBlurBackground = await WidgetBackgroundUtil.isBlurEnabled(this.prefs);

      return {
        'text': convertedOneText.text ?? '',
        'by': convertedOneText.by ?? '',
        'from': convertedOneText.from ?? '',
        'time': convertedOneText.time ?? '',
        'uri': convertedOneText.uri ?? '',
        'widget_dark': widgetDark ? 'true' : 'false',
        'widget_shadow': widgetShadow ? 'true' : 'false',
        'widget_center': widgetCenter ? 'true' : 'false',
        'widget_blur_background': widgetBlurBackground ? 'true' : 'false'
      };
    } catch (e) {
      console.error('CoreUtil', `buildWidgetFormData error: ${JSON.stringify(e)}`);
      return null;
    }
  }
}
