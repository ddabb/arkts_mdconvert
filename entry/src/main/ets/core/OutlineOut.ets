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
  MdPara,
  MdQuote,
  MdStrike,
  MdTable,
  MdText
} from './MdModel';

export const OUTLINE_MAX: number = 300;
const TEXT_MAX: number = 60;

export class OutlineItem {
  depth: number = 0;
  text: string = '';
  strong: boolean = false;
}

class OutlineCtx {
  items: OutlineItem[] = [];
  sectionDepth: number = 0;
}

function inlineText(inlines: MdInline[], parts: string[]): void {
  for (const node of inlines) {
    if (node instanceof MdText) {
      parts.push(node.text);
    } else if (node instanceof MdInlineCode) {
      parts.push(node.text);
    } else if (node instanceof MdBold) {
      inlineText(node.inline, parts);
    } else if (node instanceof MdItalic) {
      inlineText(node.inline, parts);
    } else if (node instanceof MdStrike) {
      inlineText(node.inline, parts);
    } else if (node instanceof MdLink) {
      inlineText(node.inline, parts);
    } else if (node instanceof MdImage) {
      parts.push(node.alt);
    }
  }
}

function compact(raw: string): string {
  let out: string = '';
  let lastSpace: boolean = false;
  for (const line of raw.split('\n')) {
    const trimmed: string = line.trim();
    if (trimmed.length == 0) {
      if (!lastSpace && out.length > 0) {
        out += ' ';
        lastSpace = true;
      }
      continue;
    }
    lastSpace = false;
    if (out.length > 0) {
      out += ' ';
    }
    out += trimmed;
  }
  return out.length > TEXT_MAX ? out.substring(0, TEXT_MAX) + '…' : out;
}

function blockText(block: MdBlock): string {
  const parts: string[] = [];
  if (block instanceof MdHeading) {
    inlineText(block.inline, parts);
  } else if (block instanceof MdPara) {
    inlineText(block.inline, parts);
  }
  return compact(parts.join(''));
}

function pushItem(ctx: OutlineCtx, depth: number, text: string, strong: boolean): void {
  if (ctx.items.length >= OUTLINE_MAX || text.length == 0) {
    return;
  }
  const item: OutlineItem = new OutlineItem();
  item.depth = depth;
  item.text = text;
  item.strong = strong;
  ctx.items.push(item);
}

function walkBlocks(blocks: MdBlock[], base: number, ctx: OutlineCtx): void {
  for (const block of blocks) {
    if (ctx.items.length >= OUTLINE_MAX) {
      return;
    }
    if (block instanceof MdHeading) {
      const headingDepth: number = base + block.level - 1;
      pushItem(ctx, headingDepth, blockText(block), true);
      ctx.sectionDepth = headingDepth + 1;
    } else if (block instanceof MdPara) {
      pushItem(ctx, ctx.sectionDepth, blockText(block), false);
    } else if (block instanceof MdCode) {
      const firstLine: string = block.text.split('\n')[0].trim();
      const label: string = block.lang.length > 0 ? `[${block.lang}] ${firstLine}` : firstLine;
      pushItem(ctx, ctx.sectionDepth, compact(label), false);
    } else if (block instanceof MdQuote) {
      walkBlocks(block.blocks, ctx.sectionDepth, ctx);
    } else if (block instanceof MdList) {
      walkList(block, ctx.sectionDepth, ctx);
    } else if (block instanceof MdTable) {
      if (block.rows.length > 0) {
        const header: string[] = [];
        for (const cell of block.rows[0]) {
          const parts: string[] = [];
          inlineText(cell.inline, parts);
          header.push(parts.join('').trim());
        }
        pushItem(ctx, ctx.sectionDepth,
          `表格 ${block.rows.length}×${block.aligns.length}：${header.join(' · ')}`, false);
      }
    }
  }
}

function walkList(list: MdList, depth: number, ctx: OutlineCtx): void {
  for (const item of list.items) {
    let first: boolean = true;
    for (const block of item.blocks) {
      if (block instanceof MdList) {
        walkList(block, depth + 1, ctx);
      } else if (block instanceof MdPara && first) {
        const prefix: string = list.ordered ? `${item.num}. ` : '• ';
        pushItem(ctx, depth, prefix + blockText(block), false);
      } else if (block instanceof MdHeading) {
        const headingDepth: number = depth + block.level - 1;
        pushItem(ctx, headingDepth, blockText(block), true);
        ctx.sectionDepth = headingDepth + 1;
      } else if (block instanceof MdCode) {
        pushItem(ctx, depth, `[code] ${block.text.split('\n')[0].trim()}`, false);
      }
      first = false;
    }
  }
}

export function buildOutline(doc: MdDoc): OutlineItem[] {
  const ctx: OutlineCtx = new OutlineCtx();
  walkBlocks(doc.blocks, 0, ctx);
  return ctx.items;
}
