/**
 * OneText 数据模型 - 一言条目
 */
export interface OneTextItem {
  text: string;
  by: string;
  from: string;
  time: string;
  uri: string;
  quote1: string;
  quote2: string;
}

/**
 * Feed 订阅源数据模型
 */
export interface FeedConfig {
  feed_name: string;
  feed_type: string; // 'remote' | 'local' | 'internet'
  feed_url?: string;
  feed_path?: string;
  api_method?: string;
  api_url?: string;
  text_key: string;
  by_key?: string;
  uri_key?: string;
  time_key?: string;
  from_key?: string;
  object_key?: string;
  sponsor_url?: string;
}

/**
 * Feed 列表显示项
 */
export interface FeedItem {
  name: string;
  selected: boolean;
  index: number;
}
