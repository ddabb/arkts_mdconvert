export enum MdInlineKind {
  Text,
  Bold,
  Italic,
  Strike,
  Code,
  Link,
  Image
}

export enum MdBlockKind {
  Heading,
  Para,
  List,
  Code,
  Quote,
  Table,
  ThematicBreak
}

export enum MdAlign {
  None,
  Left,
  Center,
  Right
}

export class MdInline {
  readonly kind: MdInlineKind;
  constructor(kind: MdInlineKind) {
    this.kind = kind;
  }
}

export class MdText extends MdInline {
  readonly text: string;
  constructor(text: string) {
    super(MdInlineKind.Text);
    this.text = text;
  }
}

export class MdBold extends MdInline {
  inline: MdInline[];
  constructor(inline: MdInline[]) {
    super(MdInlineKind.Bold);
    this.inline = inline;
  }
}

export class MdItalic extends MdInline {
  inline: MdInline[];
  constructor(inline: MdInline[]) {
    super(MdInlineKind.Italic);
    this.inline = inline;
  }
}

export class MdStrike extends MdInline {
  inline: MdInline[];
  constructor(inline: MdInline[]) {
    super(MdInlineKind.Strike);
    this.inline = inline;
  }
}

export class MdInlineCode extends MdInline {
  readonly text: string;
  constructor(text: string) {
    super(MdInlineKind.Code);
    this.text = text;
  }
}

export class MdLink extends MdInline {
  readonly url: string;
  readonly inline: MdInline[];
  constructor(url: string, inline: MdInline[]) {
    super(MdInlineKind.Link);
    this.url = url;
    this.inline = inline;
  }
}

export class MdImage extends MdInline {
  readonly alt: string;
  readonly url: string;
  constructor(alt: string, url: string) {
    super(MdInlineKind.Image);
    this.alt = alt;
    this.url = url;
  }
}

export class MdBlock {
  readonly kind: MdBlockKind;
  constructor(kind: MdBlockKind) {
    this.kind = kind;
  }
}

export class MdDoc {
  readonly blocks: MdBlock[];
  constructor(blocks: MdBlock[]) {
    this.blocks = blocks;
  }
}

export class MdHeading extends MdBlock {
  readonly level: number;
  inline: MdInline[];
  constructor(level: number, inline: MdInline[]) {
    super(MdBlockKind.Heading);
    this.level = level;
    this.inline = inline;
  }
}

export class MdPara extends MdBlock {
  inline: MdInline[];
  constructor(inline: MdInline[]) {
    super(MdBlockKind.Para);
    this.inline = inline;
  }
}

export class MdCode extends MdBlock {
  readonly lang: string;
  readonly text: string;
  constructor(lang: string, text: string) {
    super(MdBlockKind.Code);
    this.lang = lang;
    this.text = text;
  }
}

export class MdQuote extends MdBlock {
  readonly blocks: MdBlock[];
  constructor(blocks: MdBlock[]) {
    super(MdBlockKind.Quote);
    this.blocks = blocks;
  }
}

export class MdThematicBreak extends MdBlock {
  constructor() {
    super(MdBlockKind.ThematicBreak);
  }
}

export class MdListItem {
  readonly blocks: MdBlock[];
  readonly num: number;
  constructor(blocks: MdBlock[], num: number) {
    this.blocks = blocks;
    this.num = num;
  }
}

export class MdList extends MdBlock {
  readonly ordered: boolean;
  readonly start: number;
  readonly tight: boolean;
  readonly items: MdListItem[];
  constructor(ordered: boolean, start: number, tight: boolean, items: MdListItem[]) {
    super(MdBlockKind.List);
    this.ordered = ordered;
    this.start = start;
    this.tight = tight;
    this.items = items;
  }
}

export class MdTableCell {
  inline: MdInline[];
  constructor(inline: MdInline[]) {
    this.inline = inline;
  }
}

export class MdTable extends MdBlock {
  readonly aligns: MdAlign[];
  readonly rows: MdTableCell[][];
  constructor(aligns: MdAlign[], rows: MdTableCell[][]) {
    super(MdBlockKind.Table);
    this.aligns = aligns;
    this.rows = rows;
  }
}

export function collectInlineText(inlines: MdInline[], parts: string[]): void {
  for (const node of inlines) {
    if (node instanceof MdText) {
      parts.push(node.text);
    } else if (node instanceof MdInlineCode) {
      parts.push(node.text);
    } else if (node instanceof MdBold) {
      collectInlineText(node.inline, parts);
    } else if (node instanceof MdItalic) {
      collectInlineText(node.inline, parts);
    } else if (node instanceof MdStrike) {
      collectInlineText(node.inline, parts);
    } else if (node instanceof MdLink) {
      collectInlineText(node.inline, parts);
      parts.push(node.url);
    } else if (node instanceof MdImage) {
      parts.push(node.alt);
      parts.push(node.url);
    }
  }
}

function collectBlocksText(blocks: MdBlock[], parts: string[]): void {
  for (const block of blocks) {
    if (block instanceof MdHeading) {
      collectInlineText(block.inline, parts);
    } else if (block instanceof MdPara) {
      collectInlineText(block.inline, parts);
    } else if (block instanceof MdCode) {
      parts.push(block.lang);
      parts.push(block.text);
    } else if (block instanceof MdQuote) {
      collectBlocksText(block.blocks, parts);
    } else if (block instanceof MdList) {
      if (block.ordered) {
        parts.push(`${block.start}`);
        for (const item of block.items) {
          parts.push(`${item.num}`);
          collectBlocksText(item.blocks, parts);
        }
      } else {
        for (const item of block.items) {
          collectBlocksText(item.blocks, parts);
        }
      }
    } else if (block instanceof MdTable) {
      for (const row of block.rows) {
        for (const cell of row) {
          collectInlineText(cell.inline, parts);
        }
      }
    }
  }
}

export function collectMdText(doc: MdDoc): string {
  const parts: string[] = [];
  collectBlocksText(doc.blocks, parts);
  return parts.join('\n');
}
