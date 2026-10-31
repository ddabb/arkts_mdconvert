import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export class FileUtil {
  static readBytes(uri: string): Uint8Array {
    const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const chunkSize: number = 65536;
      const parts: Uint8Array[] = [];
      let total: number = 0;
      let done: boolean = false;
      while (!done) {
        const buf: ArrayBuffer = new ArrayBuffer(chunkSize);
        const read: number = fileIo.readSync(file.fd, buf);
        if (read <= 0) {
          done = true;
        } else {
          parts.push(new Uint8Array(buf.slice(0, read)));
          total += read;
          if (read < chunkSize) {
            done = true;
          }
        }
      }
      const all: Uint8Array = new Uint8Array(total);
      let pos: number = 0;
      for (const part of parts) {
        all.set(part, pos);
        pos += part.length;
      }
      return all;
    } finally {
      fileIo.closeSync(file);
    }
  }

  static readText(uri: string): string {
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(FileUtil.readBytes(uri));
  }

  static writeText(uri: string, text: string): void {
    const file: fileIo.File = fileIo.openSync(uri,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, text);
    fileIo.closeSync(file);
  }

  static writeBytes(uri: string, data: Uint8Array): void {
    const file: fileIo.File = fileIo.openSync(uri,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, data.buffer);
    fileIo.closeSync(file);
  }

  static fileNameOf(uri: string): string {
    const decoded: string = decodeURIComponent(uri);
    const idx: number = decoded.lastIndexOf('/');
    return idx >= 0 ? decoded.substring(idx + 1) : decoded;
  }

  static dirOf(uri: string): string {
    const decoded: string = decodeURIComponent(uri);
    const idx: number = decoded.lastIndexOf('/');
    return idx >= 0 ? decoded.substring(0, idx) : '';
  }

  static baseName(name: string): string {
    const idx: number = name.lastIndexOf('.');
    return idx > 0 ? name.substring(0, idx) : name;
  }
}
