import { MdInlineParser } from './MdInlineParser';
import { utf8Encode } from './ZipWriter';
import {
  MdBold,
  MdBreak,
  MdBlock,
  MdDoc,
  MdImage,
  MdInline,
  MdInlineCode,
  MdItalic,
  MdLink,
  MdQuote,
  MdStrike,
  MdTable,
  MdText
} from './MdModel';

export class MdToCsv {
  static csvText(src: string): string {
    const doc: MdDoc = MdInlineParser.parseFull(src);
    const tables: MdTable[] = [];
    MdToCsv.collectTables(doc.blocks, tables);
    const chunks: string[] = [];
    for (const table of tables) {
      chunks.push(MdToCsv.tableCsv(table));
    }
    return chunks.join('\r\n\r\n');
  }

  static csvBytes(src: string): Uint8Array {
    const body: Uint8Array = utf8Encode(MdToCsv.csvText(src));
    const out: Uint8Array = new Uint8Array(3 + body.length);
    out[0] = 0xEF;
    out[1] = 0xBB;
    out[2] = 0xBF;
    out.set(body, 3);
    return out;
  }

  static collectTables(blocks: MdBlock[], out: MdTable[]): void {
    for (const block of blocks) {
      if (block instanceof MdTable) {
        out.push(block);
      } else if (block instanceof MdQuote) {
        MdToCsv.collectTables(block.blocks, out);
      }
    }
  }

  static tableCsv(table: MdTable): string {
    const rows: string[] = [];
    for (const row of table.rows) {
      const cells: string[] = [];
      for (const cell of row) {
        cells.push(MdToCsv.cellCsv(cell.inline));
      }
      rows.push(cells.join(','));
    }
    return rows.join('\r\n');
  }

  static cellCsv(inlines: MdInline[]): string {
    const parts: string[] = [];
    MdToCsv.cellText(inlines, parts);
    const raw: string = parts.join('').trim();
    return MdToCsv.quote(raw);
  }

  static cellText(inlines: MdInline[], parts: string[]): void {
    for (const node of inlines) {
      if (node instanceof MdText) {
        parts.push(node.text);
      } else if (node instanceof MdInlineCode) {
        parts.push(node.text);
      } else if (node instanceof MdBold) {
        MdToCsv.cellText(node.inline, parts);
      } else if (node instanceof MdItalic) {
        MdToCsv.cellText(node.inline, parts);
      } else if (node instanceof MdStrike) {
        MdToCsv.cellText(node.inline, parts);
      } else if (node instanceof MdLink) {
        MdToCsv.cellText(node.inline, parts);
      } else if (node instanceof MdImage) {
        parts.push(node.alt);
      } else if (node instanceof MdBreak) {
        parts.push('\n');
      }
    }
  }

  static quote(raw: string): string {
    if (raw.indexOf(',') < 0 && raw.indexOf('"') < 0 && raw.indexOf('\n') < 0
      && raw.indexOf('\r') < 0) {
      return raw;
    }
    let out: string = '"';
    for (let i: number = 0; i < raw.length; i += 1) {
      const c: string = raw.charAt(i);
      if (c == '"') {
        out += '""';
      } else {
        out += c;
      }
    }
    out += '"';
    return out;
  }
}
