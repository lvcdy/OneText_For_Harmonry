export class UrlRefreshUtil {
  static withRefreshParam(uri: string, paramName: string = '_ot_refresh'): string {
    const trimmedUri = uri.trim();
    if (trimmedUri === '') {
      return '';
    }

    const hashIndex = trimmedUri.indexOf('#');
    const baseUri = hashIndex >= 0 ? trimmedUri.substring(0, hashIndex) : trimmedUri;
    const hash = hashIndex >= 0 ? trimmedUri.substring(hashIndex) : '';
    const separator = baseUri.endsWith('?') || baseUri.endsWith('&') ? '' : (baseUri.includes('?') ? '&' : '?');
    const refreshToken = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    return `${baseUri}${separator}${paramName}=${refreshToken}${hash}`;
  }
}
