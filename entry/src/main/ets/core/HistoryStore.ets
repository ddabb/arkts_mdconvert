import { fileIo } from '@kit.CoreFileKit';

export const HISTORY_MAX: number = 20;
const SEP: string = '\u001f';
const FILE_NAME: string = 'mdc_history.txt';

export class HistoryRecord {
  id: number = 0;
  time: number = 0;
  chars: number = 0;
  fmt: string = '';
  mode: string = '';
  fileName: string = '';
  content: string = '';
}

export class HistoryStore {
  static record(fileName: string, fmt: string, mode: string, content: string,
    time: number): HistoryRecord {
    const rec: HistoryRecord = new HistoryRecord();
    rec.id = time;
    rec.time = time;
    rec.chars = content.length;
    rec.fmt = fmt;
    rec.mode = mode;
    rec.fileName = fileName;
    rec.content = content;
    return rec;
  }

  static encode(records: HistoryRecord[]): string {
    const lines: string[] = [];
    for (const rec of records) {
      lines.push([
        `${rec.id}`,
        `${rec.time}`,
        `${rec.chars}`,
        encodeURIComponent(rec.fmt),
        encodeURIComponent(rec.mode),
        encodeURIComponent(rec.fileName),
        encodeURIComponent(rec.content)
      ].join(SEP));
    }
    return lines.join('\n');
  }

  static decode(text: string): HistoryRecord[] {
    const out: HistoryRecord[] = [];
    const lines: string[] = text.split('\n');
    for (const line of lines) {
      if (line.length == 0) {
        continue;
      }
      const parts: string[] = line.split(SEP);
      if (parts.length != 7) {
        continue;
      }
      const rec: HistoryRecord = new HistoryRecord();
      rec.id = Number(parts[0]);
      rec.time = Number(parts[1]);
      rec.chars = Number(parts[2]);
      rec.fmt = decodeURIComponent(parts[3]);
      rec.mode = decodeURIComponent(parts[4]);
      rec.fileName = decodeURIComponent(parts[5]);
      rec.content = decodeURIComponent(parts[6]);
      out.push(rec);
    }
    return out;
  }

  static cap(records: HistoryRecord[], max: number): HistoryRecord[] {
    if (max < 0) {
      return [];
    }
    if (records.length <= max) {
      return records;
    }
    return records.slice(0, max);
  }

  static pathOf(dir: string): string {
    return dir + '/' + FILE_NAME;
  }

  static load(dir: string): HistoryRecord[] {
    const path: string = HistoryStore.pathOf(dir);
    if (!fileIo.accessSync(path)) {
      return [];
    }
    return HistoryStore.decode(fileIo.readTextSync(path));
  }

  static save(dir: string, records: HistoryRecord[]): void {
    const file: fileIo.File = fileIo.openSync(HistoryStore.pathOf(dir),
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, HistoryStore.encode(records));
    } finally {
      fileIo.closeSync(file);
    }
  }

  static add(dir: string, rec: HistoryRecord): void {
    const next: HistoryRecord[] = [rec];
    for (const old of HistoryStore.load(dir)) {
      if (old.id != rec.id) {
        next.push(old);
      }
    }
    HistoryStore.save(dir, HistoryStore.cap(next, HISTORY_MAX));
  }

  static clear(dir: string): void {
    const path: string = HistoryStore.pathOf(dir);
    if (fileIo.accessSync(path)) {
      fileIo.unlinkSync(path);
    }
  }
}
