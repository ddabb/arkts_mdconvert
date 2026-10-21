import {
  MdBold,
  MdBlock,
  MdCode,
  MdDoc,
  MdHeading,
  MdImage,
  MdInline,
  MdInlineCode,
  MdItalic,
  MdLink,
  MdList,
  MdListItem,
  MdPara,
  MdQuote,
  MdStrike,
  MdTable,
  MdTableCell,
  MdText
} from './MdModel';
import { MdInlineParser } from './MdInlineParser';
import { MdSection, MdToJson } from './MdJsonOut';

export class MindNode {
  readonly text: string;
  readonly children: MindNode[];
  constructor(text: string, children: MindNode[]) {
    this.text = text;
    this.children = children;
  }
}

export class MindTreeBuilder {
  static readonly ROOT_FALLBACK: string = '文档大纲';

  static buildSrc(src: string, maxChildren: number): MindNode {
    return MindTreeBuilder.build(MdInlineParser.parseFull(src), maxChildren);
  }

  static build(doc: MdDoc, maxChildren: number): MindNode {
    const pre: MdBlock[] = [];
    const sections: MdSection[] = MdToJson.splitSections(doc.blocks, pre);
    if (pre.length == 0 && sections.length == 1 && sections[0].heading.level == 1) {
      const rootSec: MdSection = sections[0];
      const kids: MindNode[] = [];
      MindTreeBuilder.appendBlocks(rootSec.blocks, kids, maxChildren);
      for (const child of rootSec.children) {
        kids.push(MindTreeBuilder.sectionNode(child, maxChildren));
      }
      return new MindNode(MindTreeBuilder.headingText(rootSec.heading), MindTreeBuilder.cap(kids, maxChildren));
    }
    const rest: MindNode[] = [];
    MindTreeBuilder.appendBlocks(pre, rest, maxChildren);
    for (const sec of sections) {
      rest.push(MindTreeBuilder.sectionNode(sec, maxChildren));
    }
    return new MindNode(MindTreeBuilder.ROOT_FALLBACK, MindTreeBuilder.cap(rest, maxChildren));
  }

  static sectionNode(sec: MdSection, maxChildren: number): MindNode {
    const kids: MindNode[] = [];
    MindTreeBuilder.appendBlocks(sec.blocks, kids, maxChildren);
    for (const child of sec.children) {
      kids.push(MindTreeBuilder.sectionNode(child, maxChildren));
    }
    return new MindNode(MindTreeBuilder.headingText(sec.heading), MindTreeBuilder.cap(kids, maxChildren));
  }

  static appendBlocks(blocks: MdBlock[], out: MindNode[], maxChildren: number): void {
    for (const block of blocks) {
      MindTreeBuilder.appendBlock(block, out, maxChildren);
    }
  }

  static appendBlock(block: MdBlock, out: MindNode[], maxChildren: number): void {
    if (block instanceof MdHeading) {
      out.push(new MindNode(MindTreeBuilder.headingText(block), []));
      return;
    }
    if (block instanceof MdPara) {
      const first: string = MindTreeBuilder.firstLine(MindTreeBuilder.mindText(block.inline));
      if (first.length > 0) {
        out.push(new MindNode(first, []));
      }
      return;
    }
    if (block instanceof MdCode) {
      out.push(MindTreeBuilder.codeNode(block));
      return;
    }
    if (block instanceof MdQuote) {
      MindTreeBuilder.appendBlocks(block.blocks, out, maxChildren);
      return;
    }
    if (block instanceof MdList) {
      for (const item of block.items) {
        const node: MindNode | undefined = MindTreeBuilder.itemNode(item, maxChildren);
        if (node !== undefined) {
          out.push(node);
        }
      }
      return;
    }
    if (block instanceof MdTable) {
      out.push(MindTreeBuilder.tableNode(block, maxChildren));
      return;
    }
  }

  static itemNode(item: MdListItem, maxChildren: number): MindNode | undefined {
    const kids: MindNode[] = [];
    let label: string = '';
    let usedPara: boolean = false;
    for (const block of item.blocks) {
      if (!usedPara && block instanceof MdPara) {
        usedPara = true;
        label = MindTreeBuilder.firstLine(MindTreeBuilder.mindText(block.inline));
        continue;
      }
      MindTreeBuilder.appendBlock(block, kids, maxChildren);
    }
    if (label.length == 0) {
      if (kids.length == 0) {
        return undefined;
      }
      return new MindNode('条目', MindTreeBuilder.cap(kids, maxChildren));
    }
    return new MindNode(label, MindTreeBuilder.cap(kids, maxChildren));
  }

  static codeNode(block: MdCode): MindNode {
    const first: string = MindTreeBuilder.firstLine(block.text);
    if (first.length == 0) {
      return new MindNode(block.lang.length > 0 ? `[${block.lang}]` : '代码块', []);
    }
    const label: string = block.lang.length > 0 ? `[${block.lang}] ` : '';
    return new MindNode(label + first, []);
  }

  static tableNode(block: MdTable, maxChildren: number): MindNode {
    if (block.rows.length == 0) {
      return new MindNode('表格', []);
    }
    const kids: MindNode[] = [];
    for (let i: number = 1; i < block.rows.length; i += 1) {
      kids.push(new MindNode(MindTreeBuilder.rowText(block.rows[i]), []));
    }
    const header: string = MindTreeBuilder.rowText(block.rows[0]);
    const label: string = header.length > 0 ? `表格：${header}` : '表格';
    return new MindNode(label, MindTreeBuilder.cap(kids, maxChildren));
  }

  static rowText(row: MdTableCell[]): string {
    const parts: string[] = [];
    for (const cell of row) {
      const t: string = MindTreeBuilder.mindText(cell.inline).trim();
      parts.push(t.length > 0 ? t : ' ');
    }
    return parts.join(' | ');
  }

  static mindText(inlines: MdInline[]): string {
    const parts: string[] = [];
    MindTreeBuilder.collectMind(inlines, parts);
    return parts.join('');
  }

  static collectMind(inlines: MdInline[], parts: string[]): void {
    for (const node of inlines) {
      if (node instanceof MdText) {
        parts.push(node.text);
      } else if (node instanceof MdInlineCode) {
        parts.push(node.text);
      } else if (node instanceof MdBold) {
        MindTreeBuilder.collectMind(node.inline, parts);
      } else if (node instanceof MdItalic) {
        MindTreeBuilder.collectMind(node.inline, parts);
      } else if (node instanceof MdStrike) {
        MindTreeBuilder.collectMind(node.inline, parts);
      } else if (node instanceof MdLink) {
        MindTreeBuilder.collectMind(node.inline, parts);
      } else if (node instanceof MdImage) {
        parts.push(node.alt);
      }
    }
  }

  static headingText(heading: MdHeading): string {
    const t: string = MindTreeBuilder.mindText(heading.inline).trim();
    return t.length > 0 ? t : '标题';
  }

  static firstLine(s: string): string {
    const nl: number = s.indexOf('\n');
    const line: string = nl < 0 ? s : s.substring(0, nl);
    return line.trim();
  }

  static cap(nodes: MindNode[], maxChildren: number): MindNode[] {
    if (maxChildren <= 0 || nodes.length <= maxChildren) {
      return nodes;
    }
    const kept: MindNode[] = [];
    const keep: number = maxChildren - 1;
    for (let i: number = 0; i < keep; i += 1) {
      kept.push(nodes[i]);
    }
    kept.push(new MindNode(`…还有 ${nodes.length - keep} 项`, []));
    return kept;
  }
}
