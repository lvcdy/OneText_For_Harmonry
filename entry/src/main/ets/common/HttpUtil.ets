import { http } from '@kit.NetworkKit';

/**
 * HTTP 网络请求工具类 - 替代 Android OkHttp / GetUtil
 */
export class HttpUtil {
  /**
   * 发送 GET 请求
   * @param url 请求地址
   * @returns 响应字符串
   */
  static async get(url: string): Promise<string> {
    return await HttpUtil.request(url, 'GET');
  }

  static async request(url: string, method: string = 'GET'): Promise<string> {
    const httpRequest = http.createHttp();
    const requestMethod = method.toUpperCase() === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET;
    try {
      const response = await httpRequest.request(url, {
        method: requestMethod,
        connectTimeout: 15000,
        readTimeout: 15000,
        header: {
          'Content-Type': 'application/json'
        }
      });
      if (response.responseCode === http.ResponseCode.OK) {
        return response.result as string;
      }
      throw new Error(`HTTP Error: ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 下载文件内容并返回字符串
   * @param url 下载地址
   * @returns 文件内容字符串
   */
  static async downloadText(url: string): Promise<string> {
    return await HttpUtil.get(url);
  }
}
