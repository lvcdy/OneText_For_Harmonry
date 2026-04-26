import { OneTextItem } from '../model/DataModels';

export class OneTextMetaUtil {
  static normalize(text: string): string {
    return text.trim().replace(/^[-—–\s]+/, '').trim();
  }

  static shouldShowSource(by: string, from: string): boolean {
    const source = OneTextMetaUtil.normalize(from);
    if (source === '') {
      return false;
    }
    return source !== OneTextMetaUtil.normalize(by);
  }

  static getAuthor(by: string): string {
    return OneTextMetaUtil.normalize(by);
  }

  static getSource(by: string, from: string): string {
    return OneTextMetaUtil.shouldShowSource(by, from) ? OneTextMetaUtil.normalize(from) : '';
  }

  static buildMetaText(by: string, from: string, time: string): string {
    const parts: string[] = [];
    if (by !== '') {
      parts.push(`-- ${by}`);
    }
    if (OneTextMetaUtil.shouldShowSource(by, from)) {
      parts.push(from);
    }
    if (time !== '') {
      parts.push(time);
    }
    return parts.join(' · ');
  }

  static buildShareText(oneText: OneTextItem, textHolder: string, textReplacement: string): string {
    const lines: string[] = [oneText.text.replace(textHolder, textReplacement)];
    if (oneText.by !== '') {
      lines.push(`-- ${oneText.by}`);
    }
    if (OneTextMetaUtil.shouldShowSource(oneText.by, oneText.from)) {
      lines.push(oneText.from);
    }
    if (oneText.time !== '') {
      lines.push(oneText.time);
    }
    return lines.filter((line: string) => line.trim() !== '').join('\n');
  }
}
