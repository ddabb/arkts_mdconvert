import {
  MdBlock,
  MdBold,
  MdDoc,
  MdHeading,
  MdImage,
  MdInline,
  MdInlineCode,
  MdItalic,
  MdLink,
  MdList,
  MdPara,
  MdQuote,
  MdStrike,
  MdTable,
  MdText
} from './MdModel';
import { MdParser } from './MdParser';

export class MdInlineParser {
  static parseFull(src: string): MdDoc {
    const doc = MdParser.parse(src);
    MdInlineParser.applyBlocks(doc.blocks);
    return doc;
  }

  static applyBlocks(blocks: MdBlock[]): void {
    for (const block of blocks) {
      if (block instanceof MdHeading) {
        block.inline = MdInlineParser.parseInline(MdInlineParser.rawOf(block.inline));
      } else if (block instanceof MdPara) {
        block.inline = MdInlineParser.parseInline(MdInlineParser.rawOf(block.inline));
      } else if (block instanceof MdQuote) {
        MdInlineParser.applyBlocks(block.blocks);
      } else if (block instanceof MdList) {
        for (const item of block.items) {
          MdInlineParser.applyBlocks(item.blocks);
        }
      } else if (block instanceof MdTable) {
        for (const row of block.rows) {
          for (const cell of row) {
            cell.inline = MdInlineParser.parseInline(MdInlineParser.rawOf(cell.inline));
          }
        }
      }
    }
  }

  static rawOf(inlines: MdInline[]): string {
    const parts: string[] = [];
    for (const node of inlines) {
      if (node instanceof MdText) {
        parts.push(node.text);
      }
    }
    return parts.join('');
  }

  static parseInline(raw: string): MdInline[] {
    const out: MdInline[] = [];
    let buf: string = '';
    let i: number = 0;
    while (i < raw.length) {
      const c: string = raw.charAt(i);
      if (c == '\\') {
        if (i + 1 < raw.length && MdInlineParser.isPunct(raw.charAt(i + 1))) {
          buf += raw.charAt(i + 1);
          i += 2;
        } else {
          buf += c;
          i += 1;
        }
        continue;
      }
      if (c == '`') {
        const consumed: number = MdInlineParser.tryCodeSpan(raw, i, buf, out);
        if (consumed > 0) {
          buf = '';
          i += consumed;
          continue;
        }
        buf += c;
        i += 1;
        continue;
      }
      if (c == '!' && i + 1 < raw.length && raw.charAt(i + 1) == '[') {
        const consumed: number = MdInlineParser.tryImage(raw, i, buf, out);
        if (consumed > 0) {
          buf = '';
          i += consumed;
          continue;
        }
        buf += c;
        i += 1;
        continue;
      }
      if (c == '[') {
        const consumed: number = MdInlineParser.tryLink(raw, i, buf, out);
        if (consumed > 0) {
          buf = '';
          i += consumed;
          continue;
        }
        buf += c;
        i += 1;
        continue;
      }
      if (c == '*' || c == '_') {
        const consumed: number = MdInlineParser.tryEmphasis(raw, i, buf, out);
        if (consumed > 0) {
          buf = '';
          i += consumed;
          continue;
        }
        buf += c;
        i += 1;
        continue;
      }
      if (c == '~') {
        const consumed: number = MdInlineParser.tryStrike(raw, i, buf, out);
        if (consumed > 0) {
          buf = '';
          i += consumed;
          continue;
        }
        buf += c;
        i += 1;
        continue;
      }
      buf += c;
      i += 1;
    }
    if (buf.length > 0) {
      out.push(new MdText(buf));
    }
    return out;
  }

  static tryCodeSpan(raw: string, i: number, buf: string, out: MdInline[]): number {
    let n: number = 0;
    while (i + n < raw.length && raw.charAt(i + n) == '`') {
      n += 1;
    }
    let j: number = i + n;
    while (j < raw.length) {
      if (raw.charAt(j) == '`') {
        let m: number = 0;
        while (j + m < raw.length && raw.charAt(j + m) == '`') {
          m += 1;
        }
        if (m == n) {
          let content: string = raw.substring(i + n, j);
          content = content.split('\n').join(' ');
          if (content.length >= 2 && content.charAt(0) == ' ' && content.charAt(content.length - 1) == ' ') {
            let allSpace: boolean = true;
            for (let k: number = 0; k < content.length; k += 1) {
              if (content.charAt(k) != ' ') {
                allSpace = false;
                break;
              }
            }
            if (!allSpace) {
              content = content.substring(1, content.length - 1);
            }
          }
          if (buf.length > 0) {
            out.push(new MdText(buf));
          }
          out.push(new MdInlineCode(content));
          return j + m - i;
        }
        j += m;
        continue;
      }
      j += 1;
    }
    return 0;
  }

  static tryImage(raw: string, i: number, buf: string, out: MdInline[]): number {
    const close: number = MdInlineParser.findCloseBracket(raw, i + 1);
    if (close < 0) {
      return 0;
    }
    if (close + 1 >= raw.length || raw.charAt(close + 1) != '(') {
      return 0;
    }
    const urlEnd: number = MdInlineParser.scanBalancedParen(raw, close + 1);
    if (urlEnd < 0) {
      return 0;
    }
    const alt: string = raw.substring(i + 2, close);
    const url: string = raw.substring(close + 2, urlEnd - 1);
    if (buf.length > 0) {
      out.push(new MdText(buf));
    }
    out.push(new MdImage(alt, url));
    return urlEnd - i;
  }

  static tryLink(raw: string, i: number, buf: string, out: MdInline[]): number {
    const close: number = MdInlineParser.findCloseBracket(raw, i);
    if (close < 0) {
      return 0;
    }
    if (close + 1 >= raw.length || raw.charAt(close + 1) != '(') {
      return 0;
    }
    const urlEnd: number = MdInlineParser.scanBalancedParen(raw, close + 1);
    if (urlEnd < 0) {
      return 0;
    }
    const url: string = raw.substring(close + 2, urlEnd - 1);
    const inner: MdInline[] = MdInlineParser.parseInline(raw.substring(i + 1, close));
    if (buf.length > 0) {
      out.push(new MdText(buf));
    }
    out.push(new MdLink(url, inner));
    return urlEnd - i;
  }

  static tryEmphasis(raw: string, i: number, buf: string, out: MdInline[]): number {
    const c: string = raw.charAt(i);
    const underscore: boolean = c == '_';
    if (underscore && i > 0 && MdInlineParser.isAlnum(raw.charAt(i - 1))) {
      return 0;
    }
    let n: number = 0;
    while (i + n < raw.length && raw.charAt(i + n) == c) {
      n += 1;
    }
    if (n >= 3) {
      const close: number = MdInlineParser.findEmphasisClose(raw, i + n, c, 3, underscore);
      if (close > i + 3 && !MdInlineParser.isBlankRun(raw, i + 3, close)) {
        const inner: MdInline[] = MdInlineParser.parseInline(raw.substring(i + 3, close));
        if (buf.length > 0) {
          out.push(new MdText(buf));
        }
        out.push(new MdBold([new MdItalic(inner)]));
        return close + 3 - i;
      }
    }
    if (n >= 2) {
      const close: number = MdInlineParser.findEmphasisClose(raw, i + n, c, 2, underscore);
      const start: number = n >= 3 ? i + 3 : i + 2;
      if (close > start && !MdInlineParser.isBlankRun(raw, start, close)) {
        const inner: MdInline[] = MdInlineParser.parseInline(raw.substring(start, close));
        if (buf.length > 0) {
          out.push(new MdText(buf));
        }
        out.push(new MdBold(inner));
        return close + 2 - i;
      }
    }
    if (n == 1) {
      const close: number = MdInlineParser.findEmphasisClose(raw, i + n, c, 1, underscore);
      const start: number = i + 1;
      if (close > start && !MdInlineParser.isBlankRun(raw, start, close)) {
        const inner: MdInline[] = MdInlineParser.parseInline(raw.substring(start, close));
        if (buf.length > 0) {
          out.push(new MdText(buf));
        }
        out.push(new MdItalic(inner));
        return close + 1 - i;
      }
    }
    return 0;
  }

  static findEmphasisClose(raw: string, from: number, c: string, minRun: number, underscore: boolean): number {
    let j: number = from;
    while (j < raw.length) {
      const cur: string = raw.charAt(j);
      if (cur == '\\') {
        j += 2;
        continue;
      }
      if (cur == c) {
        let m: number = 0;
        while (j + m < raw.length && raw.charAt(j + m) == c) {
          m += 1;
        }
        if (m >= minRun) {
          if (underscore && j + m < raw.length && MdInlineParser.isAlnum(raw.charAt(j + m))) {
            j += m;
            continue;
          }
          return j;
        }
        j += m;
        continue;
      }
      j += 1;
    }
    return -1;
  }

  static isBlankRun(raw: string, from: number, to: number): boolean {
    for (let k: number = from; k < to; k += 1) {
      if (raw.charAt(k) != ' ' && raw.charAt(k) != '\n' && raw.charAt(k) != '\t') {
        return false;
      }
    }
    return true;
  }

  static tryStrike(raw: string, i: number, buf: string, out: MdInline[]): number {
    if (i + 1 >= raw.length || raw.charAt(i + 1) != '~') {
      return 0;
    }
    let j: number = i + 2;
    while (j < raw.length) {
      const cur: string = raw.charAt(j);
      if (cur == '\\') {
        j += 2;
        continue;
      }
      if (cur == '~' && j + 1 < raw.length && raw.charAt(j + 1) == '~' && j - (i + 2) > 0 &&
        !MdInlineParser.isBlankRun(raw, i + 2, j)) {
        const inner: MdInline[] = MdInlineParser.parseInline(raw.substring(i + 2, j));
        if (buf.length > 0) {
          out.push(new MdText(buf));
        }
        out.push(new MdStrike(inner));
        return j + 2 - i;
      }
      j += 1;
    }
    return 0;
  }

  static findCloseBracket(raw: string, open: number): number {
    let depth: number = 1;
    let j: number = open + 1;
    while (j < raw.length) {
      const c: string = raw.charAt(j);
      if (c == '\\') {
        j += 2;
        continue;
      }
      if (c == '[') {
        depth += 1;
      } else if (c == ']') {
        depth -= 1;
        if (depth == 0) {
          return j;
        }
      }
      j += 1;
    }
    return -1;
  }

  static scanBalancedParen(raw: string, open: number): number {
    let depth: number = 1;
    let j: number = open + 1;
    while (j < raw.length) {
      const c: string = raw.charAt(j);
      if (c == '\\') {
        j += 2;
        continue;
      }
      if (c == '(') {
        depth += 1;
      } else if (c == ')') {
        depth -= 1;
        if (depth == 0) {
          return j + 1;
        }
      }
      j += 1;
    }
    return -1;
  }

  static isPunct(c: string): boolean {
    const code: number = c.charCodeAt(0);
    return (code >= 33 && code <= 47) || (code >= 58 && code <= 64) ||
      (code >= 91 && code <= 96) || (code >= 123 && code <= 126);
  }

  static isAlnum(c: string): boolean {
    const code: number = c.charCodeAt(0);
    return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
}
