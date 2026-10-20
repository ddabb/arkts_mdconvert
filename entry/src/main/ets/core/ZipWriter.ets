function buildCrcTable(): number[] {
  const table: number[] = [];
  for (let n: number = 0; n < 256; n += 1) {
    let c: number = n;
    for (let k: number = 0; k < 8; k += 1) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ (c >>> 1);
      } else {
        c = c >>> 1;
      }
    }
    table.push(c);
  }
  return table;
}

const CRC_TABLE: number[] = buildCrcTable();

export function crc32(data: Uint8Array): number {
  let c: number = 0xFFFFFFFF;
  for (let i: number = 0; i < data.length; i += 1) {
    c = CRC_TABLE[(c ^ data[i]) & 0xFF] ^ (c >>> 8);
  }
  return (c ^ 0xFFFFFFFF) >>> 0;
}

export function utf8Encode(s: string): Uint8Array {
  const bytes: number[] = [];
  for (let i: number = 0; i < s.length; i += 1) {
    let code: number = s.charCodeAt(i);
    if (code >= 0xD800 && code <= 0xDBFF) {
      if (i + 1 < s.length) {
        const lo: number = s.charCodeAt(i + 1);
        if (lo >= 0xDC00 && lo <= 0xDFFF) {
          code = 0x10000 + ((code - 0xD800) << 10) + (lo - 0xDC00);
          i += 1;
        } else {
          code = 0xFFFD;
        }
      } else {
        code = 0xFFFD;
      }
    } else if (code >= 0xDC00 && code <= 0xDFFF) {
      code = 0xFFFD;
    }
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xC0 | (code >> 6));
      bytes.push(0x80 | (code & 0x3F));
    } else if (code < 0x10000) {
      bytes.push(0xE0 | (code >> 12));
      bytes.push(0x80 | ((code >> 6) & 0x3F));
      bytes.push(0x80 | (code & 0x3F));
    } else {
      bytes.push(0xF0 | (code >> 18));
      bytes.push(0x80 | ((code >> 12) & 0x3F));
      bytes.push(0x80 | ((code >> 6) & 0x3F));
      bytes.push(0x80 | (code & 0x3F));
    }
  }
  return new Uint8Array(bytes);
}

export class ZipEntry {
  readonly nameBytes: Uint8Array;
  readonly data: Uint8Array;
  readonly crc: number;
  constructor(nameBytes: Uint8Array, data: Uint8Array, crc: number) {
    this.nameBytes = nameBytes;
    this.data = data;
    this.crc = crc;
  }
}

export class ZipWriter {
  private entries: ZipEntry[] = [];

  add(name: string, content: string): void {
    this.addBytes(name, utf8Encode(content));
  }

  addBytes(name: string, data: Uint8Array): void {
    this.entries.push(new ZipEntry(utf8Encode(name), data, crc32(data)));
  }

  size(): number {
    return this.entries.length;
  }

  bytes(): Uint8Array {
    let total: number = 22;
    for (const e of this.entries) {
      total += 30 + e.nameBytes.length + e.data.length;
    }
    for (const e of this.entries) {
      total += 46 + e.nameBytes.length;
    }
    const out: Uint8Array = new Uint8Array(total);
    const dv: DataView = new DataView(out.buffer);
    const offsets: number[] = [];
    let pos: number = 0;
    for (const e of this.entries) {
      offsets.push(pos);
      dv.setUint32(pos, 0x04034b50, true);
      pos += 4;
      dv.setUint16(pos, 20, true);
      pos += 2;
      dv.setUint16(pos, 0x0800, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint16(pos, 0x0021, true);
      pos += 2;
      dv.setUint32(pos, e.crc, true);
      pos += 4;
      dv.setUint32(pos, e.data.length, true);
      pos += 4;
      dv.setUint32(pos, e.data.length, true);
      pos += 4;
      dv.setUint16(pos, e.nameBytes.length, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      out.set(e.nameBytes, pos);
      pos += e.nameBytes.length;
      out.set(e.data, pos);
      pos += e.data.length;
    }
    const cdStart: number = pos;
    for (let i: number = 0; i < this.entries.length; i += 1) {
      const e: ZipEntry = this.entries[i];
      dv.setUint32(pos, 0x02014b50, true);
      pos += 4;
      dv.setUint16(pos, 20, true);
      pos += 2;
      dv.setUint16(pos, 20, true);
      pos += 2;
      dv.setUint16(pos, 0x0800, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint16(pos, 0x0021, true);
      pos += 2;
      dv.setUint32(pos, e.crc, true);
      pos += 4;
      dv.setUint32(pos, e.data.length, true);
      pos += 4;
      dv.setUint32(pos, e.data.length, true);
      pos += 4;
      dv.setUint16(pos, e.nameBytes.length, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint16(pos, 0, true);
      pos += 2;
      dv.setUint32(pos, 0, true);
      pos += 4;
      dv.setUint32(pos, offsets[i], true);
      pos += 4;
      out.set(e.nameBytes, pos);
      pos += e.nameBytes.length;
    }
    const cdSize: number = pos - cdStart;
    dv.setUint32(pos, 0x06054b50, true);
    pos += 4;
    dv.setUint16(pos, 0, true);
    pos += 2;
    dv.setUint16(pos, 0, true);
    pos += 2;
    dv.setUint16(pos, this.entries.length, true);
    pos += 2;
    dv.setUint16(pos, this.entries.length, true);
    pos += 2;
    dv.setUint32(pos, cdSize, true);
    pos += 4;
    dv.setUint32(pos, cdStart, true);
    pos += 4;
    dv.setUint16(pos, 0, true);
    pos += 2;
    return out;
  }
}
