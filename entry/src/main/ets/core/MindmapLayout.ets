import { MindNode } from './MindmapTree';

export abstract class MindMetrics {
  abstract textWidth(text: string): number;
}

export class MindMetricsFixed extends MindMetrics {
  readonly base: number;
  readonly charW: number;
  constructor(base: number, charW: number) {
    super();
    this.base = base;
    this.charW = charW;
  }

  textWidth(text: string): number {
    return this.base + this.charW * text.length;
  }
}

export class MindRect {
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;
}

export class MindLayoutItem {
  readonly node: MindNode;
  readonly depth: number;
  readonly side: number;
  readonly parent: MindLayoutItem | undefined;
  readonly children: MindLayoutItem[];
  readonly rect: MindRect;
  subH: number = 0;
  constructor(node: MindNode, depth: number, side: number, parent: MindLayoutItem | undefined) {
    this.node = node;
    this.depth = depth;
    this.side = side;
    this.parent = parent;
    this.children = [];
    this.rect = new MindRect();
  }
}

export class MindLayout {
  readonly items: MindLayoutItem[];
  readonly width: number;
  readonly height: number;
  constructor(items: MindLayoutItem[], width: number, height: number) {
    this.items = items;
    this.width = width;
    this.height = height;
  }
}

export class MindmapLayout {
  static readonly NODE_H: number = 36;
  static readonly PAD_X: number = 16;
  static readonly MIN_W: number = 40;
  static readonly GAP_Y: number = 12;
  static readonly GAP_X: number = 48;
  static readonly ROOT_GAP: number = 64;
  static readonly MARGIN: number = 24;

  static layout(root: MindNode, metrics: MindMetrics): MindLayout {
    const items: MindLayoutItem[] = [];
    const maxWr: number[] = [];
    const maxWl: number[] = [];
    const rootItem: MindLayoutItem = new MindLayoutItem(root, 0, 1, undefined);
    rootItem.rect.w = MindmapLayout.nodeW(root, metrics);
    rootItem.rect.h = MindmapLayout.NODE_H;
    items.push(rootItem);
    const rightCount: number = Math.ceil(root.children.length / 2);
    for (let i: number = 0; i < root.children.length; i += 1) {
      const side: number = i < rightCount ? 1 : -1;
      const maxW: number[] = side == 1 ? maxWr : maxWl;
      MindmapLayout.buildDesc(rootItem, root.children[i], 1, side, metrics, items, maxW);
    }
    MindmapLayout.measureSubH(rootItem);
    const colXr: number[] = [];
    for (let d: number = 0; d < maxWr.length; d += 1) {
      if (d == 0) {
        colXr.push(rootItem.rect.w + MindmapLayout.ROOT_GAP);
      } else {
        colXr.push(colXr[d - 1] + maxWr[d - 1] + MindmapLayout.GAP_X);
      }
    }
    const colXl: number[] = [];
    for (let d: number = 0; d < maxWl.length; d += 1) {
      if (d == 0) {
        colXl.push(-MindmapLayout.ROOT_GAP - maxWl[0]);
      } else {
        colXl.push(colXl[d - 1] - MindmapLayout.GAP_X - maxWl[d]);
      }
    }
    for (const item of items) {
      if (item.depth == 0) {
        item.rect.x = 0;
      } else if (item.side == 1) {
        item.rect.x = colXr[item.depth - 1];
      } else {
        item.rect.x = colXl[item.depth - 1];
      }
    }
    const rightH: number = MindmapLayout.placeSide(rootItem, 1);
    const leftH: number = MindmapLayout.placeSide(rootItem, -1);
    const contentH: number = Math.max(Math.max(rightH, leftH), MindmapLayout.NODE_H);
    rootItem.rect.y = contentH / 2 - MindmapLayout.NODE_H / 2;
    return MindmapLayout.translate(items);
  }

  static buildDesc(parent: MindLayoutItem, node: MindNode, depth: number, side: number,
    metrics: MindMetrics, items: MindLayoutItem[], maxW: number[]): void {
    const item: MindLayoutItem = new MindLayoutItem(node, depth, side, parent);
    const w: number = MindmapLayout.nodeW(node, metrics);
    item.rect.w = w;
    item.rect.h = MindmapLayout.NODE_H;
    parent.children.push(item);
    items.push(item);
    MindmapLayout.widen(maxW, depth - 1, w);
    for (const child of node.children) {
      MindmapLayout.buildDesc(item, child, depth + 1, side, metrics, items, maxW);
    }
  }

  static measureSubH(item: MindLayoutItem): number {
    if (item.children.length == 0) {
      item.subH = MindmapLayout.NODE_H;
      return item.subH;
    }
    let total: number = 0;
    for (const child of item.children) {
      total += MindmapLayout.measureSubH(child);
    }
    total += MindmapLayout.GAP_Y * (item.children.length - 1);
    item.subH = Math.max(MindmapLayout.NODE_H, total);
    return item.subH;
  }

  static placeSide(rootItem: MindLayoutItem, side: number): number {
    let cursor: number = 0;
    let count: number = 0;
    for (const child of rootItem.children) {
      if (child.side != side) {
        continue;
      }
      MindmapLayout.placeNode(child, cursor);
      cursor += child.subH + MindmapLayout.GAP_Y;
      count += 1;
    }
    if (count == 0) {
      return 0;
    }
    return cursor - MindmapLayout.GAP_Y;
  }

  static placeNode(item: MindLayoutItem, top: number): void {
    if (item.children.length == 0) {
      item.rect.y = top;
      return;
    }
    let cursor: number = top;
    for (const child of item.children) {
      MindmapLayout.placeNode(child, cursor);
      cursor += child.subH + MindmapLayout.GAP_Y;
    }
    const firstCy: number = item.children[0].rect.y + MindmapLayout.NODE_H / 2;
    const lastCy: number = item.children[item.children.length - 1].rect.y + MindmapLayout.NODE_H / 2;
    item.rect.y = (firstCy + lastCy) / 2 - MindmapLayout.NODE_H / 2;
  }

  static translate(items: MindLayoutItem[]): MindLayout {
    let minX: number = items[0].rect.x;
    let minY: number = items[0].rect.y;
    let maxX: number = items[0].rect.x + items[0].rect.w;
    let maxY: number = items[0].rect.y + items[0].rect.h;
    for (const item of items) {
      const r: MindRect = item.rect;
      if (r.x < minX) {
        minX = r.x;
      }
      if (r.y < minY) {
        minY = r.y;
      }
      if (r.x + r.w > maxX) {
        maxX = r.x + r.w;
      }
      if (r.y + r.h > maxY) {
        maxY = r.y + r.h;
      }
    }
    const dx: number = MindmapLayout.MARGIN - minX;
    const dy: number = MindmapLayout.MARGIN - minY;
    for (const item of items) {
      item.rect.x += dx;
      item.rect.y += dy;
    }
    const width: number = maxX - minX + 2 * MindmapLayout.MARGIN;
    const height: number = maxY - minY + 2 * MindmapLayout.MARGIN;
    return new MindLayout(items, width, height);
  }

  static nodeW(node: MindNode, metrics: MindMetrics): number {
    return Math.max(MindmapLayout.MIN_W, metrics.textWidth(node.text) + 2 * MindmapLayout.PAD_X);
  }

  static widen(arr: number[], idx: number, w: number): void {
    while (arr.length <= idx) {
      arr.push(0);
    }
    if (w > arr[idx]) {
      arr[idx] = w;
    }
  }
}
