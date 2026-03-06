import { common } from '@kit.AbilityKit';
import { OneTextItem, FeedConfig } from '../model/DataModels';
import { PreferencesUtil } from './PreferencesUtil';
import { FileUtil } from './FileUtil';
import { HttpUtil } from './HttpUtil';

/**
 * 核心业务逻辑工具类
 * 元服务版：负责一言数据的读取、随机选取、订阅源管理等
 */
export class CoreUtil {
  static readonly TEXT_REPLACE_HOLDER: string = '@@';
  static readonly TEXT_REPLACE: string = '\n';

  private context: common.UIAbilityContext;
  private prefs: PreferencesUtil;
  private currentTimeMillis: number;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.prefs = PreferencesUtil.getInstance();
    this.currentTimeMillis = Date.now();
  }

  /**
   * 检查一言数据文件是否存在
   */
  private ifHaveOneTextFiles(): boolean {
    return FileUtil.isFile(`${this.context.filesDir}/OneText/OneText-Library.json`);
  }

  /**
   * 获取一言数据数组（JSON 字符串）
   */
  private async getOneTextArray(): Promise<string> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    if (feedMap.feed_type === 'remote') {
      if (this.ifHaveOneTextFiles()) {
        return FileUtil.readTextFromFile(`${this.context.filesDir}/OneText/OneText-Library.json`);
      } else {
        return '[{"text":"File does not exist."}]';
      }
    } else if (feedMap.feed_type === 'local') {
      return FileUtil.readTextFromFile(feedMap.feed_path ?? '');
    }
    return '[]';
  }

  /**
   * 获取一言编号（随机或缓存）
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
   * 生成新的随机一言编号
   */
  private async generateNewOneTextCode(): Promise<number> {
    const arrayStr = await this.getOneTextArray();
    let code = 0;
    try {
      const arr: object[] = JSON.parse(arrayStr) as object[];
      code = Math.floor(Math.random() * arr.length);
    } catch (e) {
      console.error('CoreUtil', `generateNewOneTextCode error: ${JSON.stringify(e)}`);
    }
    await this.refreshLatestRefreshTime();
    await this.prefs.putNumber('onetext_code', code);
    return code;
  }

  /**
   * 判断是否应该更新一言
   */
  async ifOneTextShouldUpdate(ifFromWidget: boolean): Promise<boolean> {
    const widgetEnabled = await this.prefs.getBoolean('widget_enabled', false);
    if (ifFromWidget || !widgetEnabled) {
      const latestRefreshTime = await this.prefs.getNumber('onetext_latest_refresh_time', 0);
      const refreshTime = await this.prefs.getNumber('onetext_refresh_time', 30);
      return ifFromWidget && ((this.currentTimeMillis - latestRefreshTime) >= (refreshTime * 60000));
    }
    return false;
  }

  /**
   * 刷新最新更新时间
   */
  async refreshLatestRefreshTime(): Promise<void> {
    await this.prefs.putNumber('onetext_latest_refresh_time', this.currentTimeMillis);
  }

  /**
   * 获取一言数据
   */
  async getOneText(forceRefresh: boolean, ifFromWidget: boolean): Promise<OneTextItem> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    const arrayStr = await this.getOneTextArray();
    const code = await this.getOneTextCode(forceRefresh, ifFromWidget);
    try {
      const arr: object[] = JSON.parse(arrayStr) as object[];
      if (arr.length > 0 && code < arr.length) {
        const jsonObj = arr[code] as Record<string, string>;
        return this.convertOneText(jsonObj, feedMap);
      }
    } catch (e) {
      console.error('CoreUtil', `getOneText error: ${JSON.stringify(e)}`);
    }
    return {
      text: '', by: '', from: '', time: '', uri: '', quote1: '\u201C', quote2: '\u201D'
    };
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
        text += jsonObj[keys[i]] ?? '';
        if (i < keys.length - 1) {
          text += CoreUtil.TEXT_REPLACE_HOLDER;
        }
      }
      return text;
    }
    return jsonObj[textKey] ?? '';
  }

  /**
   * 转换一言数据
   */
  convertOneText(jsonObj: Record<string, string>, feedMap: FeedConfig): OneTextItem {
    const text = this.getComposeText(jsonObj, feedMap);
    const by = jsonObj[feedMap.by_key ?? 'by'] ?? '';
    const from = jsonObj[feedMap.from_key ?? 'from'] ?? '';
    const uri = jsonObj[feedMap.uri_key ?? 'uri'] ?? '';

    // 处理时间字段
    let time = '';
    try {
      const timeStr = jsonObj[feedMap.time_key ?? 'time'] ?? '';
      if (timeStr.startsWith('[')) {
        const timeArr: string[] = JSON.parse(timeStr) as string[];
        const timeOfRecord = timeArr[0] ?? '';
        const timeOfCreation = timeArr.length > 1 ? timeArr[1] : '';
        if (timeOfCreation) {
          time = `记录于：${timeOfRecord} 创作于：${timeOfCreation}`;
        } else if (timeOfRecord) {
          time = `记录于：${timeOfRecord}`;
        }
      }
    } catch (e) {
      // time 字段解析失败，忽略
    }

    return {
      text: text,
      by: by,
      from: from,
      time: time,
      uri: uri,
      quote1: '\u201C',
      quote2: '\u201D'
    };
  }

  /**
   * 初始化订阅源文件
   */
  async initFeedFile(): Promise<boolean> {
    const feedDir = `${this.context.filesDir}/Feed`;
    const feedPath = `${feedDir}/Feed.json`;
    if (!FileUtil.isFile(feedPath)) {
      return await FileUtil.copyRawFileToDir(this.context, 'Feed.json', feedDir, 'Feed.json');
    }
    return true;
  }

  /**
   * 初始化一言（下载远程数据或读取本地文件）
   */
  async initOneText(): Promise<boolean> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    if (feedMap.feed_type === 'remote') {
      if (this.ifHaveOneTextFiles()) {
        return true;
      }
      try {
        const data = await HttpUtil.downloadText(feedMap.feed_url ?? '');
        const dir = `${this.context.filesDir}/OneText`;
        FileUtil.writeTextToFile(data, dir, 'OneText-Library.json');
        return true;
      } catch (e) {
        console.error('CoreUtil', `initOneText download error: ${JSON.stringify(e)}`);
        return false;
      }
    } else if (feedMap.feed_type === 'local') {
      return FileUtil.isFile(feedMap.feed_path ?? '');
    }
    return true;
  }

  /**
   * 通过 API 获取一言（internet 类型订阅源）
   */
  async getOneTextFromApi(feedMap: FeedConfig): Promise<OneTextItem> {
    try {
      const result = await HttpUtil.get(feedMap.api_url ?? '');
      const jsonObj = JSON.parse(result) as Record<string, string>;
      return this.convertOneText(jsonObj, feedMap);
    } catch (e) {
      console.error('CoreUtil', `getOneTextFromApi error: ${JSON.stringify(e)}`);
      return {
        text: '', by: '', from: '', time: '', uri: '', quote1: '\u201C', quote2: '\u201D'
      };
    }
  }

  /**
   * 获取订阅源配置信息
   */
  async getFeedInformation(position: number): Promise<FeedConfig> {
    const feedArrayStr = this.getFeedArray();
    try {
      const arr: FeedConfig[] = JSON.parse(feedArrayStr) as FeedConfig[];
      if (position < arr.length) {
        return arr[position];
      }
    } catch (e) {
      console.error('CoreUtil', `getFeedInformation error: ${JSON.stringify(e)}`);
    }
    return {
      feed_name: 'Unknown',
      feed_type: 'remote',
      text_key: 'text'
    };
  }

  /**
   * 获取订阅源数组 JSON 字符串
   */
  private getFeedArray(): string {
    const feedPath = `${this.context.filesDir}/Feed/Feed.json`;
    if (FileUtil.isFile(feedPath)) {
      return FileUtil.readTextFromFile(feedPath);
    }
    return '[{"feed_name":"File does not exist."}]';
  }

  /**
   * 获取所有订阅源列表
   */
  getAllFeeds(): FeedConfig[] {
    try {
      const arr = JSON.parse(this.getFeedArray()) as FeedConfig[];
      return arr;
    } catch (e) {
      return [];
    }
  }

  /**
   * 添加订阅源
   */
  async addFeed(feedName: string, feedType: string, feedURL?: string, feedPath?: string): Promise<void> {
    const feeds = this.getAllFeeds();
    const newFeed: FeedConfig = {
      feed_name: feedName,
      feed_type: feedType,
      feed_url: feedURL ?? '',
      feed_path: feedPath ?? '',
      text_key: 'text',
      by_key: 'by',
      from_key: 'from',
      time_key: 'time',
      uri_key: 'uri'
    };
    feeds.push(newFeed);
    const feedDir = `${this.context.filesDir}/Feed`;
    FileUtil.deleteFile(`${feedDir}/Feed.json`);
    FileUtil.writeTextToFile(JSON.stringify(feeds), feedDir, 'Feed.json');
  }

  /**
   * 删除订阅源
   */
  async deleteFeed(position: number): Promise<void> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    if (feedCode > position) {
      await this.prefs.putNumber('feed_code', feedCode - 1);
    } else if (feedCode === position) {
      const feedInfo = await this.getFeedInformation(position);
      if (feedInfo.feed_type === 'remote') {
        FileUtil.deleteFile(`${this.context.filesDir}/OneText/OneText-Library.json`);
      }
      await this.prefs.remove('feed_code');
      await this.prefs.remove('feed_latest_refresh_time');
      await this.prefs.remove('onetext_code');
    }
    const feeds = this.getAllFeeds();
    feeds.splice(position, 1);
    const feedDir = `${this.context.filesDir}/Feed`;
    FileUtil.deleteFile(`${feedDir}/Feed.json`);
    FileUtil.writeTextToFile(JSON.stringify(feeds), feedDir, 'Feed.json');
  }

  /**
   * 运行一言更新检查
   */
  async runOneTextUpdate(): Promise<boolean> {
    const feedCode = await this.prefs.getNumber('feed_code', 0);
    const feedMap = await this.getFeedInformation(feedCode);
    if (feedMap.feed_type === 'remote') {
      const autoUpdate = await this.prefs.getBoolean('feed_auto_update', true);
      if (autoUpdate) {
        const latestRefreshTime = await this.prefs.getNumber('feed_latest_refresh_time', 0);
        const refreshTime = await this.prefs.getNumber('feed_refresh_time', 1);
        if ((this.currentTimeMillis - latestRefreshTime) > (refreshTime * 3600000)) {
          try {
            const data = await HttpUtil.downloadText(feedMap.feed_url ?? '');
            const dir = `${this.context.filesDir}/OneText`;
            FileUtil.writeTextToFile(data, dir, 'OneText-Library.json');
            await this.prefs.putNumber('feed_latest_refresh_time', this.currentTimeMillis);
            return true;
          } catch (e) {
            return false;
          }
        }
      }
    }
    return true;
  }
}
