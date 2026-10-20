import {
  MdAlign,
  MdBlock,
  MdBold,
  MdCode,
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
  MdText,
  MdThematicBreak
} from './MdModel';
import { MdInlineParser } from './MdInlineParser';

export class JVal {}

export class JPair {
  readonly key: string;
  readonly val: JVal;
  constructor(key: string, val: JVal) {
    this.key = key;
    this.val = val;
  }
}

export class JObj extends JVal {
  readonly pairs: JPair[];
  constructor() {
    super();
    this.pairs = [];
  }
  put(key: string, val: JVal): JObj {
    this.pairs.push(new JPair(key, val));
    return this;
  }
}

export class JArr extends JVal {
  readonly items: JVal[];
  constructor() {
    super();
    this.items = [];
  }
  add(v: JVal): JArr {
    this.items.push(v);
    return this;
  }
}

export class JStr extends JVal {
  readonly s: string;
  constructor(s: string) {
    super();
    this.s = s;
  }
}

export class JNum extends JVal {
  readonly n: number;
  constructor(n: number) {
    super();
    this.n = n;
  }
}

export class JBool extends JVal {
  readonly b: boolean;
  constructor(b: boolean) {
    super();
    this.b = b;
  }
}

export class JWriter {
  static write(v: JVal): string {
    const sb: string[] = [];
    JWriter.writeVal(v, 0, sb);
    sb.push('\n');
    return sb.join('');
  }

  static pad(indent: number): string {
    let out: string = '';
    for (let i: number = 0; i < indent; i += 1) {
      out += '  ';
    }
    return out;
  }

  static writeVal(v: JVal, indent: number, sb: string[]): void {
    if (v instanceof JObj) {
      JWriter.writeObj(v, indent, sb);
    } else if (v instanceof JArr) {
      JWriter.writeArr(v, indent, sb);
    } else if (v instanceof JStr) {
      sb.push(JWriter.quote(v.s));
    } else if (v instanceof JNum) {
      sb.push(v.n.toString());
    } else if (v instanceof JBool) {
      sb.push(v.b ? 'true' : 'false');
    }
  }

  static writeObj(o: JObj, indent: number, sb: string[]): void {
    if (o.pairs.length == 0) {
      sb.push('{}');
      return;
    }
    sb.push('{\n');
    for (let i: number = 0; i < o.pairs.length; i += 1) {
      const p: JPair = o.pairs[i];
      sb.push(JWriter.pad(indent + 1));
      sb.push(JWriter.quote(p.key));
      sb.push(': ');
      JWriter.writeVal(p.val, indent + 1, sb);
      if (i < o.pairs.length - 1) {
        sb.push(',');
      }
      sb.push('\n');
    }
    sb.push(JWriter.pad(indent));
    sb.push('}');
  }

  static writeArr(a: JArr, indent: number, sb: string[]): void {
    if (a.items.length == 0) {
      sb.push('[]');
      return;
    }
    sb.push('[\n');
    for (let i: number = 0; i < a.items.length; i += 1) {
      sb.push(JWriter.pad(indent + 1));
      JWriter.writeVal(a.items[i], indent + 1, sb);
      if (i < a.items.length - 1) {
        sb.push(',');
      }
      sb.push('\n');
    }
    sb.push(JWriter.pad(indent));
    sb.push(']');
  }

  static quote(s: string): string {
    let out: string = '"';
    for (let i: number = 0; i < s.length; i += 1) {
      const c: string = s.charAt(i);
      const code: number = c.charCodeAt(0);
      if (c == '"') {
        out += '\\"';
      } else if (c == '\\') {
        out += '\\\\';
      } else if (code == 10) {
        out += '\\n';
      } else if (code == 13) {
        out += '\\r';
      } else if (code == 9) {
        out += '\\t';
      } else if (code == 8) {
        out += '\\b';
      } else if (code == 12) {
        out += '\\f';
      } else if (code < 32) {
        out += '\\u00';
        const hex: string = code.toString(16);
        out += hex.length < 2 ? '0' + hex : hex;
      } else {
        out += c;
      }
    }
    return out + '"';
  }
}

export class MdSection {
  readonly heading: MdHeading;
  readonly blocks: MdBlock[];
  readonly children: MdSection[];
  constructor(heading: MdHeading) {
    this.heading = heading;
    this.blocks = [];
    this.children = [];
  }
}

export class MdToJson {
  static flat(src: string): string {
    return JWriter.write(MdToJson.flatDoc(MdInlineParser.parseFull(src)));
  }

  static tree(src: string): string {
    return JWriter.write(MdToJson.treeDoc(MdInlineParser.parseFull(src)));
  }

  static flatDoc(doc: MdDoc): JVal {
    return new JObj().put('blocks', MdToJson.blocksToJ(doc.blocks));
  }

  static treeDoc(doc: MdDoc): JVal {
    const pre: MdBlock[] = [];
    const sections: MdSection[] = MdToJson.splitSections(doc.blocks, pre);
    const root: JObj = new JObj();
    root.put('blocks', MdToJson.blocksToJ(pre));
    const arr: JArr = new JArr();
    for (const sec of sections) {
      arr.add(MdToJson.sectionToJ(sec));
    }
    root.put('sections', arr);
    return root;
  }

  static splitSections(blocks: MdBlock[], pre: MdBlock[]): MdSection[] {
    const roots: MdSection[] = [];
    const stack: MdSection[] = [];
    for (const block of blocks) {
      if (block instanceof MdHeading) {
        while (stack.length > 0 && stack[stack.length - 1].heading.level >= block.level) {
          stack.pop();
        }
        const sec: MdSection = new MdSection(block);
        if (stack.length == 0) {
          roots.push(sec);
        } else {
          stack[stack.length - 1].children.push(sec);
        }
        stack.push(sec);
      } else if (stack.length == 0) {
        pre.push(block);
      } else {
        stack[stack.length - 1].blocks.push(block);
      }
    }
    return roots;
  }

  static sectionToJ(sec: MdSection): JVal {
    const o: JObj = new JObj();
    o.put('heading', MdToJson.inlinesToJ(sec.heading.inline));
    o.put('level', new JNum(sec.heading.level));
    o.put('blocks', MdToJson.blocksToJ(sec.blocks));
    const children: JArr = new JArr();
    for (const child of sec.children) {
      children.add(MdToJson.sectionToJ(child));
    }
    o.put('children', children);
    return o;
  }

  static blocksToJ(blocks: MdBlock[]): JArr {
    const arr: JArr = new JArr();
    for (const block of blocks) {
      arr.add(MdToJson.blockToJ(block));
    }
    return arr;
  }

  static blockToJ(block: MdBlock): JVal {
    if (block instanceof MdHeading) {
      const o: JObj = new JObj();
      o.put('type', new JStr('heading'));
      o.put('level', new JNum(block.level));
      o.put('inline', MdToJson.inlinesToJ(block.inline));
      return o;
    }
    if (block instanceof MdPara) {
      const o: JObj = new JObj();
      o.put('type', new JStr('para'));
      o.put('inline', MdToJson.inlinesToJ(block.inline));
      return o;
    }
    if (block instanceof MdCode) {
      const o: JObj = new JObj();
      o.put('type', new JStr('code'));
      o.put('lang', new JStr(block.lang));
      o.put('text', new JStr(block.text));
      return o;
    }
    if (block instanceof MdQuote) {
      const o: JObj = new JObj();
      o.put('type', new JStr('quote'));
      o.put('blocks', MdToJson.blocksToJ(block.blocks));
      return o;
    }
    if (block instanceof MdThematicBreak) {
      return new JObj().put('type', new JStr('hr'));
    }
    if (block instanceof MdList) {
      const o: JObj = new JObj();
      o.put('type', new JStr('list'));
      o.put('ordered', new JBool(block.ordered));
      o.put('start', new JNum(block.start));
      o.put('tight', new JBool(block.tight));
      const items: JArr = new JArr();
      for (const item of block.items) {
        const io: JObj = new JObj();
        io.put('num', new JNum(item.num));
        io.put('blocks', MdToJson.blocksToJ(item.blocks));
        items.add(io);
      }
      o.put('items', items);
      return o;
    }
    if (block instanceof MdTable) {
      const o: JObj = new JObj();
      o.put('type', new JStr('table'));
      const aligns: JArr = new JArr();
      for (const a of block.aligns) {
        aligns.add(new JStr(MdToJson.alignToStr(a)));
      }
      o.put('aligns', aligns);
      const rows: JArr = new JArr();
      for (const row of block.rows) {
        const rj: JArr = new JArr();
        for (const cell of row) {
          rj.add(new JObj().put('inline', MdToJson.inlinesToJ(cell.inline)));
        }
        rows.add(rj);
      }
      o.put('rows', rows);
      return o;
    }
    return new JObj();
  }

  static alignToStr(a: MdAlign): string {
    if (a == MdAlign.Left) {
      return 'left';
    }
    if (a == MdAlign.Center) {
      return 'center';
    }
    if (a == MdAlign.Right) {
      return 'right';
    }
    return 'none';
  }

  static inlinesToJ(inlines: MdInline[]): JArr {
    const arr: JArr = new JArr();
    for (const node of inlines) {
      arr.add(MdToJson.inlineToJ(node));
    }
    return arr;
  }

  static inlineToJ(node: MdInline): JVal {
    if (node instanceof MdText) {
      return new JObj().put('type', new JStr('text')).put('text', new JStr(node.text));
    }
    if (node instanceof MdBold) {
      return new JObj().put('type', new JStr('bold')).put('inline', MdToJson.inlinesToJ(node.inline));
    }
    if (node instanceof MdItalic) {
      return new JObj().put('type', new JStr('italic')).put('inline', MdToJson.inlinesToJ(node.inline));
    }
    if (node instanceof MdStrike) {
      return new JObj().put('type', new JStr('strike')).put('inline', MdToJson.inlinesToJ(node.inline));
    }
    if (node instanceof MdInlineCode) {
      return new JObj().put('type', new JStr('code')).put('text', new JStr(node.text));
    }
    if (node instanceof MdLink) {
      return new JObj().put('type', new JStr('link')).put('url', new JStr(node.url))
        .put('inline', MdToJson.inlinesToJ(node.inline));
    }
    if (node instanceof MdImage) {
      return new JObj().put('type', new JStr('image')).put('alt', new JStr(node.alt))
        .put('url', new JStr(node.url));
    }
    return new JObj();
  }
}
