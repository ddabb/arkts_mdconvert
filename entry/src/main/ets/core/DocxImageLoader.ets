import { FileUtil } from './FileIoUtil';
import { MdToDocx } from './DocxOut';

export class DocxImageLoader {
  private static readonly MAX_BYTES: number = 8388608;

  static load(src: string, baseDir: string): Map<string, Uint8Array> {
    const out: Map<string, Uint8Array> = new Map<string, Uint8Array>();
    let urls: string[] = [];
    try {
      urls = MdToDocx.collectImageUrls(src);
    } catch (err) {
      return out;
    }
    for (const url of urls) {
      const path: string = url.startsWith('/') ? url :
        (baseDir.length > 0 ? baseDir + '/' + url : url);
      try {
        const bytes: Uint8Array = FileUtil.readBytes(path);
        if (bytes.length > 0 && bytes.length <= DocxImageLoader.MAX_BYTES) {
          out.set(url, bytes);
        }
      } catch (err) {
      }
    }
    return out;
  }
}
