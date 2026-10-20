import {
  MdAlign,
  MdBlock,
  MdCode,
  MdDoc,
  MdHeading,
  MdInline,
  MdList,
  MdListItem,
  MdPara,
  MdQuote,
  MdTable,
  MdTableCell,
  MdText,
  MdThematicBreak
} from './MdModel';

class ParseHit {
  readonly block: MdBlock;
  readonly next: number;
  constructor(block: MdBlock, next: number) {
    this.block = block;
    this.next = next;
  }
}

class MarkerInfo {
  readonly isOrdered: boolean;
  readonly num: number;
  readonly indent: number;
  readonly contentCol: number;
  readonly contentText: string;
  constructor(isOrdered: boolean, num: number, indent: number, contentCol: number, contentText: string) {
    this.isOrdered = isOrdered;
    this.num = num;
    this.indent = indent;
    this.contentCol = contentCol;
    this.contentText = contentText;
  }
}

export class MdParser {
  static parse(src: string): MdDoc {
    const normalized = src.split('\r\n').join('\n').split('\r').join('\n');
    const lines = normalized.split('\n');
    return new MdDoc(MdParser.parseBlocks(lines));
  }

  static parseBlocks(lines: string[]): MdBlock[] {
    const result: MdBlock[] = [];
    let i = 0;
    while (i < lines.length) {
      const t = MdParser.expandTabs(lines[i]);
      if (MdParser.isBlank(t)) {
        i++;
        continue;
      }
      let hit: ParseHit | undefined = MdParser.tryFence(lines, i);
      if (hit === undefined) {
        hit = MdParser.tryHeading(lines, i);
      }
      if (hit === undefined) {
        hit = MdParser.tryThematicBreak(lines, i);
      }
      if (hit === undefined) {
        hit = MdParser.tryQuote(lines, i);
      }
      if (hit === undefined) {
        hit = MdParser.tryTable(lines, i);
      }
      if (hit === undefined) {
        hit = MdParser.tryList(lines, i);
      }
      if (hit === undefined) {
        hit = MdParser.tryPara(lines, i);
      }
      if (hit !== undefined) {
        result.push(hit.block);
        i = hit.next;
      } else {
        result.push(new MdPara([new MdText(lines[i])]));
        i++;
      }
    }
    return result;
  }

  static expandTabs(line: string): string {
    let p = 0;
    while (p < line.length && line.charAt(p) == '\t') {
      p++;
    }
    if (p == 0) {
      return line;
    }
    let s = '';
    for (let k = 0; k < p; k++) {
      s += '    ';
    }
    return s + line.substring(p);
  }

  static isBlank(line: string): boolean {
    return line.trim().length == 0;
  }

  static leadingSpaces(line: string): number {
    let p = 0;
    while (p < line.length && line.charAt(p) == ' ') {
      p++;
    }
    return p;
  }

  static fenceCount(t: string): number {
    if (t.length < 3) {
      return 0;
    }
    const fc = t.charAt(0);
    if (fc != '`' && fc != '~') {
      return 0;
    }
    let n = 0;
    while (n < t.length && t.charAt(n) == fc) {
      n++;
    }
    if (n < 3) {
      return 0;
    }
    const info = t.substring(n).trim();
    if (fc == '`' && info.indexOf('`') >= 0) {
      return 0;
    }
    return n;
  }

  static tryFence(lines: string[], i: number): ParseHit | undefined {
    const t = MdParser.expandTabs(lines[i]).trim();
    const fc = t.charAt(0);
    const n = MdParser.fenceCount(t);
    if (n == 0) {
      return undefined;
    }
    const info = t.substring(n).trim();
    const body: string[] = [];
    let j = i + 1;
    while (j < lines.length) {
      const tj = MdParser.expandTabs(lines[j]).trim();
      let m = 0;
      while (m < tj.length && tj.charAt(m) == fc) {
        m++;
      }
      if (m >= n && tj.substring(m).trim().length == 0) {
        return new ParseHit(new MdCode(info, body.join('\n')), j + 1);
      }
      body.push(lines[j]);
      j++;
    }
    return new ParseHit(new MdCode(info, body.join('\n')), lines.length);
  }

  static atxLevel(line: string): number {
    const p = MdParser.leadingSpaces(line);
    let n = 0;
    while (p + n < line.length && line.charAt(p + n) == '#') {
      n++;
    }
    if (n < 1 || n > 6) {
      return 0;
    }
    if (p + n < line.length && line.charAt(p + n) != ' ') {
      return 0;
    }
    return n;
  }

  static tryHeading(lines: string[], i: number): ParseHit | undefined {
    const line = MdParser.expandTabs(lines[i]);
    const level = MdParser.atxLevel(line);
    if (level == 0) {
      return undefined;
    }
    const p = MdParser.leadingSpaces(line);
    let after = p + level;
    if (after < line.length && line.charAt(after) == ' ') {
      after++;
    }
    let content = line.substring(after).trim();
    if (content.length > 0) {
      let e = content.length;
      while (e > 0 && content.charAt(e - 1) == ' ') {
        e--;
      }
      let h = e;
      while (h > 0 && content.charAt(h - 1) == '#') {
        h--;
      }
      if (h < e) {
        if (h == 0) {
          content = '';
        } else if (content.charAt(h - 1) == ' ') {
          content = content.substring(0, h).trim();
        }
      }
    }
    const inline: MdInline[] = [];
    if (content.length > 0) {
      inline.push(new MdText(content));
    }
    return new ParseHit(new MdHeading(level, inline), i + 1);
  }

  static isThematicBreakText(t: string): boolean {
    if (t.length < 3) {
      return false;
    }
    const c = t.charAt(0);
    if (c != '-' && c != '*' && c != '_') {
      return false;
    }
    let n = 0;
    for (let k = 0; k < t.length; k++) {
      const ch = t.charAt(k);
      if (ch == c) {
        n++;
      } else if (ch != ' ') {
        return false;
      }
    }
    return n >= 3;
  }

  static tryThematicBreak(lines: string[], i: number): ParseHit | undefined {
    const t = MdParser.expandTabs(lines[i]).trim();
    if (!MdParser.isThematicBreakText(t)) {
      return undefined;
    }
    return new ParseHit(new MdThematicBreak(), i + 1);
  }

  static stripQuote(line: string): string {
    let p = 0;
    while (p < line.length && line.charAt(p) == ' ') {
      p++;
    }
    if (p >= line.length || line.charAt(p) != '>') {
      return line;
    }
    p++;
    if (p < line.length && line.charAt(p) == ' ') {
      p++;
    }
    return line.substring(p);
  }

  static tryQuote(lines: string[], i: number): ParseHit | undefined {
    const t0 = MdParser.expandTabs(lines[i]).trim();
    if (t0.length == 0 || t0.charAt(0) != '>') {
      return undefined;
    }
    const inner: string[] = [];
    let j = i;
    while (j < lines.length) {
      const t = MdParser.expandTabs(lines[j]);
      const trimmed = t.trim();
      if (trimmed.length > 0 && trimmed.charAt(0) == '>') {
        inner.push(MdParser.stripQuote(t));
        j++;
        continue;
      }
      if (MdParser.isBlank(t)) {
        let k = j + 1;
        while (k < lines.length && MdParser.isBlank(MdParser.expandTabs(lines[k]))) {
          k++;
        }
        if (k < lines.length && MdParser.expandTabs(lines[k]).trim().charAt(0) == '>') {
          inner.push('');
          j++;
          continue;
        }
      }
      break;
    }
    return new ParseHit(new MdQuote(MdParser.parseBlocks(inner)), j);
  }

  static splitRow(line: string): string[] {
    let s = line.trim();
    if (s.length > 0 && s.charAt(0) == '|') {
      s = s.substring(1);
    }
    if (s.length > 0 && s.charAt(s.length - 1) == '|') {
      s = s.substring(0, s.length - 1);
    }
    const cells: string[] = [];
    let buf = '';
    let k = 0;
    while (k < s.length) {
      const c = s.charAt(k);
      if (c == '\\' && k + 1 < s.length && s.charAt(k + 1) == '|') {
        buf += '|';
        k += 2;
        continue;
      }
      if (c == '|') {
        cells.push(buf.trim());
        buf = '';
        k++;
        continue;
      }
      buf += c;
      k++;
    }
    cells.push(buf.trim());
    return cells;
  }

  static parseAlignCell(s: string): MdAlign | undefined {
    const t = s.trim();
    if (t.length == 0) {
      return undefined;
    }
    let p = 0;
    let left = false;
    let right = false;
    if (t.charAt(p) == ':') {
      left = true;
      p++;
    }
    let dashes = 0;
    while (p < t.length && t.charAt(p) == '-') {
      dashes++;
      p++;
    }
    if (dashes == 0) {
      return undefined;
    }
    if (p < t.length && t.charAt(p) == ':') {
      right = true;
      p++;
    }
    if (p != t.length) {
      return undefined;
    }
    if (left && right) {
      return MdAlign.Center;
    }
    if (left) {
      return MdAlign.Left;
    }
    if (right) {
      return MdAlign.Right;
    }
    return MdAlign.None;
  }

  static parseAligns(line: string): MdAlign[] | undefined {
    const cells = MdParser.splitRow(line);
    if (cells.length == 0) {
      return undefined;
    }
    const aligns: MdAlign[] = [];
    for (const cell of cells) {
      const a = MdParser.parseAlignCell(cell);
      if (a === undefined) {
        return undefined;
      }
      aligns.push(a);
    }
    return aligns;
  }

  static cellsToRow(cells: string[]): MdTableCell[] {
    const row: MdTableCell[] = [];
    for (const cell of cells) {
      const inline: MdInline[] = [];
      if (cell.length > 0) {
        inline.push(new MdText(cell));
      }
      row.push(new MdTableCell(inline));
    }
    return row;
  }

  static tryTable(lines: string[], i: number): ParseHit | undefined {
    const line = MdParser.expandTabs(lines[i]);
    if (line.indexOf('|') < 0) {
      return undefined;
    }
    if (i + 1 >= lines.length) {
      return undefined;
    }
    const aligns = MdParser.parseAligns(MdParser.expandTabs(lines[i + 1]));
    if (aligns === undefined) {
      return undefined;
    }
    const headerCells = MdParser.splitRow(line);
    if (headerCells.length != aligns.length) {
      return undefined;
    }
    const rows: MdTableCell[][] = [];
    rows.push(MdParser.cellsToRow(headerCells));
    let j = i + 2;
    while (j < lines.length) {
      const t = MdParser.expandTabs(lines[j]);
      if (MdParser.isBlank(t)) {
        break;
      }
      if (t.indexOf('|') < 0) {
        break;
      }
      rows.push(MdParser.cellsToRow(MdParser.splitRow(t)));
      j++;
    }
    return new ParseHit(new MdTable(aligns, rows), j);
  }

  static markerInfo(line: string): MarkerInfo | undefined {
    const p = MdParser.leadingSpaces(line);
    if (p >= line.length) {
      return undefined;
    }
    const code = line.charCodeAt(p);
    if (code == 45 || code == 42 || code == 43) {
      let q = p + 1;
      if (q < line.length && line.charAt(q) != ' ') {
        return undefined;
      }
      while (q < line.length && line.charAt(q) == ' ') {
        q++;
      }
      return new MarkerInfo(false, 0, p, q, line.substring(q));
    }
    if (code >= 49 && code <= 57) {
      let q = p;
      while (q < line.length && line.charCodeAt(q) >= 48 && line.charCodeAt(q) <= 57) {
        q++;
      }
      if (q - p > 9) {
        return undefined;
      }
      if (q >= line.length) {
        return undefined;
      }
      const d = line.charAt(q);
      if (d != '.' && d != ')') {
        return undefined;
      }
      q++;
      if (q < line.length && line.charAt(q) != ' ') {
        return undefined;
      }
      while (q < line.length && line.charAt(q) == ' ') {
        q++;
      }
      let num = 0;
      for (let k = p; k < q; k++) {
        const ch = line.charAt(k);
        if (ch >= '0' && ch <= '9') {
          num = num * 10 + (ch.charCodeAt(0) - 48);
        }
      }
      return new MarkerInfo(true, num, p, q, line.substring(q));
    }
    return undefined;
  }

  static startsBlockLine(lines: string[], j: number): boolean {
    const t = MdParser.expandTabs(lines[j]);
    if (MdParser.isBlank(t)) {
      return true;
    }
    const trimmed = t.trim();
    const c = trimmed.charAt(0);
    if (c == '`' || c == '~') {
      if (MdParser.fenceCount(trimmed) > 0) {
        return true;
      }
    }
    if (c == '#' && MdParser.atxLevel(t) > 0) {
      return true;
    }
    if (c == '-' || c == '*' || c == '_') {
      if (MdParser.isThematicBreakText(trimmed)) {
        return true;
      }
    }
    if (c == '>') {
      return true;
    }
    if (MdParser.markerInfo(t) !== undefined) {
      return true;
    }
    if (t.indexOf('|') >= 0 && j + 1 < lines.length) {
      const aligns = MdParser.parseAligns(MdParser.expandTabs(lines[j + 1]));
      if (aligns !== undefined) {
        return true;
      }
    }
    return false;
  }

  static tryList(lines: string[], i: number): ParseHit | undefined {
    const first = MdParser.markerInfo(MdParser.expandTabs(lines[i]));
    if (first === undefined) {
      return undefined;
    }
    const base = first.indent;
    let curCol = first.contentCol;
    let loose = false;
    let j = i;
    while (j < lines.length) {
      const t = MdParser.expandTabs(lines[j]);
      if (MdParser.isBlank(t)) {
        let k = j + 1;
        while (k < lines.length && MdParser.isBlank(MdParser.expandTabs(lines[k]))) {
          k++;
        }
        if (k >= lines.length) {
          break;
        }
        const kt = MdParser.expandTabs(lines[k]);
        const km = MdParser.markerInfo(kt);
        if (km !== undefined && km.indent >= base) {
          loose = true;
          j = k;
          continue;
        }
        if (MdParser.leadingSpaces(kt) >= curCol) {
          loose = true;
          j = k;
          continue;
        }
        break;
      }
      const m = MdParser.markerInfo(t);
      if (m !== undefined) {
        if (m.indent == base) {
          if (m.isOrdered != first.isOrdered) {
            break;
          }
          curCol = m.contentCol;
          j++;
        } else if (m.indent > base) {
          j++;
        } else {
          break;
        }
      } else {
        if (MdParser.leadingSpaces(t) > base) {
          j++;
        } else if (MdParser.startsBlockLine(lines, j)) {
          break;
        } else {
          j++;
        }
      }
    }
    const end = j;
    const items: MdListItem[] = [];
    let p = i;
    while (p < end) {
      const pm = MdParser.markerInfo(MdParser.expandTabs(lines[p]));
      if (pm === undefined || pm.indent != base) {
        p++;
        continue;
      }
      const contentCol = pm.contentCol;
      const itemLines: string[] = [];
      itemLines.push(pm.contentText);
      let q = p + 1;
      while (q < end) {
        const qm = MdParser.markerInfo(MdParser.expandTabs(lines[q]));
        if (qm !== undefined && qm.indent == base) {
          break;
        }
        const qt = MdParser.expandTabs(lines[q]);
        const ind = MdParser.leadingSpaces(qt);
        if (MdParser.isBlank(qt)) {
          itemLines.push('');
        } else if (ind >= contentCol) {
          itemLines.push(qt.substring(contentCol));
        } else {
          itemLines.push(qt);
        }
        q++;
      }
      items.push(new MdListItem(MdParser.parseBlocks(itemLines), pm.num));
      p = q;
    }
    return new ParseHit(new MdList(first.isOrdered, first.num, !loose, items), end);
  }

  static tryPara(lines: string[], i: number): ParseHit | undefined {
    let j = i + 1;
    while (j < lines.length && !MdParser.startsBlockLine(lines, j)) {
      j++;
    }
    const parts: string[] = [];
    for (let k = i; k < j; k++) {
      parts.push(lines[k]);
    }
    return new ParseHit(new MdPara([new MdText(parts.join('\n'))]), j);
  }
}
