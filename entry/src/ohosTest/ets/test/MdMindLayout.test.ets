import { describe, it, expect } from '@ohos/hypium';
import { MindNode } from '../../../main/ets/core/MindmapTree';
import {
  MindLayout,
  MindLayoutItem,
  MindRect,
  MindmapLayout,
  MindMetrics,
  MindMetricsFixed
} from '../../../main/ets/core/MindmapLayout';

class Lcg {
  state: number = 1;
  constructor(seed: number) {
    this.state = seed;
  }

  next(): number {
    this.state = (this.state * 48271) % 2147483647;
    return this.state;
  }

  below(n: number): number {
    return this.next() % n;
  }
}

function randTree(seed: number): MindNode {
  const rng: Lcg = new Lcg(seed);
  return randNode(rng, 0);
}

function randNode(rng: Lcg, depth: number): MindNode {
  const len: number = 1 + rng.below(8);
  let text: string = '';
  for (let i: number = 0; i < len; i += 1) {
    text += String.fromCharCode(65 + rng.below(26));
  }
  const kids: MindNode[] = [];
  if (depth < 4) {
    const n: number = rng.below(3);
    for (let i: number = 0; i < n; i += 1) {
      kids.push(randNode(rng, depth + 1));
    }
  }
  return new MindNode(text, kids);
}

function wideTree(): MindNode {
  const leaves: MindNode[] = [];
  for (let i: number = 0; i < 400; i += 1) {
    leaves.push(new MindNode(`叶${i}`, []));
  }
  const mid: MindNode[] = [];
  for (let i: number = 0; i < 100; i += 1) {
    mid.push(new MindNode(`枝${i}`, [leaves[i * 4], leaves[i * 4 + 1], leaves[i * 4 + 2], leaves[i * 4 + 3]]));
  }
  const subs: MindNode[] = [];
  for (let i: number = 0; i < 25; i += 1) {
    subs.push(new MindNode(`节${i}`, [mid[i * 4], mid[i * 4 + 1], mid[i * 4 + 2], mid[i * 4 + 3]]));
  }
  const top: MindNode[] = [];
  for (let i: number = 0; i < 5; i += 1) {
    top.push(new MindNode(`组${i}`, [subs[i * 5], subs[i * 5 + 1], subs[i * 5 + 2], subs[i * 5 + 3], subs[i * 5 + 4]]));
  }
  return new MindNode('根', top);
}

function overlaps(a: MindLayoutItem, b: MindLayoutItem): boolean {
  const ra: MindRect = a.rect;
  const rb: MindRect = b.rect;
  return ra.x < rb.x + rb.w && rb.x < ra.x + ra.w && ra.y < rb.y + rb.h && rb.y < ra.y + ra.h;
}

function countOverlaps(items: MindLayoutItem[]): number {
  let n: number = 0;
  for (let i: number = 0; i < items.length; i += 1) {
    for (let j: number = i + 1; j < items.length; j += 1) {
      if (overlaps(items[i], items[j])) {
        n += 1;
      }
    }
  }
  return n;
}

function cy(item: MindLayoutItem): number {
  return item.rect.y + MindmapLayout.NODE_H / 2;
}

function checkTree(items: MindLayoutItem[], width: number, height: number): void {
  for (const a of items) {
    expect(a.rect.x >= 0).assertTrue();
    expect(a.rect.y >= 0).assertTrue();
    expect(a.rect.x + a.rect.w <= width).assertTrue();
    expect(a.rect.y + a.rect.h <= height).assertTrue();
  }
  expect(countOverlaps(items)).assertEqual(0);
  for (const a of items) {
    if (a.depth >= 1 && a.children.length >= 2) {
      const first: number = cy(a.children[0]);
      const last: number = cy(a.children[a.children.length - 1]);
      expect(Math.abs(cy(a) - (first + last) / 2) < 0.001).assertTrue();
    }
  }
}

export default function mdMindLayoutTest() {
  describe('mdMindLayoutTest', () => {
    it('goldenLayoutCoords', 0, () => {
      const three: MindNode = new MindNode('Three', [new MindNode('ThreeOne', [])]);
      const root: MindNode = new MindNode('Root', [
        new MindNode('One', []),
        new MindNode('Two', []),
        three,
        new MindNode('Four', [])
      ]);
      const metrics: MindMetrics = new MindMetricsFixed(20, 10);
      const layout: MindLayout = MindmapLayout.layout(root, metrics);
      expect(layout.items.length).assertEqual(6);
      expect(layout.width).assertEqual(632);
      expect(layout.height).assertEqual(132);
      const expected: string[] = ['Root', 'One', 'Two', 'Three', 'ThreeOne', 'Four'];
      const xs: number[] = [370, 526, 526, 204, 24, 204];
      const ys: number[] = [48, 24, 72, 24, 24, 72];
      const ws: number[] = [92, 82, 82, 102, 132, 92];
      for (let i: number = 0; i < 6; i += 1) {
        const item: MindLayoutItem = layout.items[i];
        expect(item.node.text).assertEqual(expected[i]);
        expect(item.rect.x).assertEqual(xs[i]);
        expect(item.rect.y).assertEqual(ys[i]);
        expect(item.rect.w).assertEqual(ws[i]);
        expect(item.rect.h).assertEqual(36);
      }
      checkTree(layout.items, layout.width, layout.height);
    });
    it('rootOnly', 0, () => {
      const layout: MindLayout = MindmapLayout.layout(new MindNode('R', []), new MindMetricsFixed(20, 10));
      expect(layout.items.length).assertEqual(1);
      expect(layout.items[0].rect.x).assertEqual(24);
      expect(layout.items[0].rect.y).assertEqual(24);
      expect(layout.items[0].rect.w).assertEqual(62);
      expect(layout.items[0].rect.h).assertEqual(36);
      expect(layout.width).assertEqual(110);
      expect(layout.height).assertEqual(84);
    });
    it('singleChildOnRight', 0, () => {
      const root: MindNode = new MindNode('R', [new MindNode('C', [])]);
      const layout: MindLayout = MindmapLayout.layout(root, new MindMetricsFixed(20, 10));
      expect(layout.items[1].side).assertEqual(1);
      expect(layout.items[1].rect.x).assertEqual(150);
      expect(layout.items[1].rect.y).assertEqual(layout.items[0].rect.y);
    });
    it('sideSplitThree', 0, () => {
      const root: MindNode = new MindNode('R', [
        new MindNode('A', []),
        new MindNode('B', []),
        new MindNode('C', [])
      ]);
      const layout: MindLayout = MindmapLayout.layout(root, new MindMetricsFixed(20, 10));
      expect(layout.items[1].side).assertEqual(1);
      expect(layout.items[2].side).assertEqual(1);
      expect(layout.items[3].side).assertEqual(-1);
    });
    it('deepChainMonotonicX', 0, () => {
      const node: MindNode = new MindNode('L5', []);
      let cur: MindNode = node;
      for (let i: number = 4; i >= 0; i -= 1) {
        cur = new MindNode(`L${i}`, [cur]);
      }
      const layout: MindLayout = MindmapLayout.layout(cur, new MindMetricsFixed(20, 10));
      expect(layout.items.length).assertEqual(6);
      for (let i: number = 1; i < 6; i += 1) {
        expect(layout.items[i].rect.x >= layout.items[i - 1].rect.x + layout.items[i - 1].rect.w).assertTrue();
        expect(layout.items[i].rect.y).assertEqual(layout.items[i - 1].rect.y);
      }
    });
    it('minWidthEnforced', 0, () => {
      const layout: MindLayout = MindmapLayout.layout(new MindNode('', []), new MindMetricsFixed(0, 0));
      expect(layout.items[0].rect.w).assertEqual(40);
    });
    it('randomTreesDisjoint200', 0, () => {
      for (let seed: number = 1; seed <= 200; seed += 1) {
        const layout: MindLayout = MindmapLayout.layout(randTree(seed), new MindMetricsFixed(20, 10));
        checkTree(layout.items, layout.width, layout.height);
      }
      expect(true).assertTrue();
    });
    it('perf531Nodes', 0, () => {
      const tree: MindNode = wideTree();
      const start: number = Date.now();
      const layout: MindLayout = MindmapLayout.layout(tree, new MindMetricsFixed(20, 10));
      const elapsed: number = Date.now() - start;
      expect(layout.items.length).assertEqual(531);
      expect(elapsed < 1000).assertTrue();
      checkTree(layout.items, layout.width, layout.height);
    });
  });
}
