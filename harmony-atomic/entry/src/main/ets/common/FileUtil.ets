import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

/**
 * 文件操作工具类
 * 元服务版：基于应用沙箱的轻量级文件操作
 */
export class FileUtil {
  /**
   * 从文件读取文本
   */
  static readTextFromFile(path: string): string {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(new Uint8Array(buf));
    } catch (e) {
      console.error('FileUtil', `Failed to read file: ${path}, error: ${JSON.stringify(e)}`);
      return '';
    }
  }

  /**
   * 写入文本到文件
   */
  static writeTextToFile(content: string, dirPath: string, fileName: string): boolean {
    try {
      if (!fileIo.accessSync(dirPath)) {
        fileIo.mkdirSync(dirPath, true);
      }
      const filePath = `${dirPath}/${fileName}`;
      const file = fileIo.openSync(filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      const encoder = new util.TextEncoder();
      const encoded = encoder.encodeInto(content);
      fileIo.writeSync(file.fd, encoded.buffer);
      fileIo.closeSync(file);
      return true;
    } catch (e) {
      console.error('FileUtil', `Failed to write file: ${dirPath}/${fileName}, error: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /**
   * 检查文件是否存在
   */
  static isFile(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (e) {
      return false;
    }
  }

  /**
   * 删除文件
   */
  static deleteFile(path: string): boolean {
    try {
      fileIo.unlinkSync(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * 获取应用沙箱文件目录
   */
  static getFilesDir(context: common.UIAbilityContext): string {
    return context.filesDir;
  }

  /**
   * 从 rawfile 复制资源到文件目录
   */
  static async copyRawFileToDir(context: common.UIAbilityContext, rawFileName: string,
    destDir: string, destFileName: string): Promise<boolean> {
    try {
      const resourceManager = context.resourceManager;
      const data = await resourceManager.getRawFileContent(rawFileName);
      if (!fileIo.accessSync(destDir)) {
        fileIo.mkdirSync(destDir, true);
      }
      const destPath = `${destDir}/${destFileName}`;
      const file = fileIo.openSync(destPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data.buffer);
      fileIo.closeSync(file);
      return true;
    } catch (e) {
      console.error('FileUtil', `Failed to copy rawfile: ${rawFileName}, error: ${JSON.stringify(e)}`);
      return false;
    }
  }
}
