import { describe, it, expect } from '@ohos/hypium';
import { MindNode } from '../../../main/ets/core/MindmapTree';
import { MdToMm, MdToOpml } from '../../../main/ets/core/MmOpmlOut';

function count(s: string, sub: string): number {
  let n: number = 0;
  let pos: number = s.indexOf(sub);
  while (pos >= 0) {
    n += 1;
    pos = s.indexOf(sub, pos + sub.length);
  }
  return n;
}

function tree4(): MindNode {
  const three: MindNode = new MindNode('三', [new MindNode('三一', [])]);
  return new MindNode('根', [
    new MindNode('一', []),
    new MindNode('二', []),
    three,
    new MindNode('四', [])
  ]);
}

export default function mdMmOpmlTest() {
  describe('mdMmOpmlTest', () => {
    it('mmStructure', 0, () => {
      const out: string = MdToMm.mmTree(tree4());
      expect(out.startsWith('<map version="1.0.1">\n')).assertTrue();
      expect(out.endsWith('</map>\n')).assertTrue();
    });
    it('mmNodeCount', 0, () => {
      const out: string = MdToMm.mmTree(tree4());
      expect(count(out, '<node ')).assertEqual(6);
    });
    it('mmPositionSplit', 0, () => {
      const out: string = MdToMm.mmTree(tree4());
      expect(count(out, 'POSITION="right"')).assertEqual(2);
      expect(count(out, 'POSITION="left"')).assertEqual(2);
      expect(out.indexOf('POSITION="right"') < out.indexOf('POSITION="left"')).assertTrue();
    });
    it('mmEscapesAttr', 0, () => {
      const root: MindNode = new MindNode('A<B&C"D', []);
      const out: string = MdToMm.mmTree(root);
      expect(out.indexOf('TEXT="A&lt;B&amp;C&quot;D"') >= 0).assertTrue();
    });
    it('mmLeafSelfClosing', 0, () => {
      const out: string = MdToMm.mmTree(tree4());
      expect(out.indexOf('<node TEXT="一" POSITION="right"/>') >= 0).assertTrue();
      expect(out.indexOf('<node TEXT="三一"/>') >= 0).assertTrue();
    });
    it('mmFromSrc', 0, () => {
      const out: string = MdToMm.mm('# 甲\n\n- 乙\n- 丙');
      expect(out.indexOf('<node TEXT="甲">') >= 0).assertTrue();
      expect(out.indexOf('<node TEXT="乙" POSITION="right"/>') >= 0).assertTrue();
      expect(out.indexOf('<node TEXT="丙" POSITION="left"/>') >= 0).assertTrue();
      expect(count(out, '<node ')).assertEqual(3);
    });
    it('opmlStructure', 0, () => {
      const out: string = MdToOpml.opmlTree(tree4());
      expect(out.startsWith('<?xml version="1.0" encoding="UTF-8"?>\n')).assertTrue();
      expect(out.indexOf('<opml version="2.0">') >= 0).assertTrue();
      expect(out.indexOf('<title>根</title>') >= 0).assertTrue();
      expect(out.indexOf('<body>') >= 0).assertTrue();
      expect(out.endsWith('</opml>\n')).assertTrue();
    });
    it('opmlOutlineCount', 0, () => {
      const out: string = MdToOpml.opmlTree(tree4());
      expect(count(out, '<outline ')).assertEqual(6);
      expect(count(out, '</outline>')).assertEqual(2);
    });
    it('opmlNesting', 0, () => {
      const out: string = MdToOpml.opmlTree(tree4());
      expect(out.indexOf('<outline text="三一"/>') >= 0).assertTrue();
      expect(out.indexOf('<outline text="三一"/>') > out.indexOf('<outline text="三">')).assertTrue();
      expect(out.indexOf('<outline text="三一"/>') < out.indexOf('</outline>')).assertTrue();
    });
    it('opmlFromSrc', 0, () => {
      const out: string = MdToOpml.opml('# 甲\n\n内容');
      expect(out.indexOf('<title>甲</title>') >= 0).assertTrue();
      expect(count(out, '<outline ')).assertEqual(2);
    });
  });
}
