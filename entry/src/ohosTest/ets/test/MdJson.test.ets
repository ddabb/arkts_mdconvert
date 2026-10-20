import { describe, it, expect } from '@ohos/hypium';
import { MdToJson } from '../../../main/ets/core/MdJsonOut';

function flatOf(src: string): string {
  return MdToJson.flat(src);
}

function treeOf(src: string): string {
  return MdToJson.tree(src);
}

function has(s: string, sub: string): void {
  expect(s.indexOf(sub) >= 0).assertTrue();
}

export default function mdJsonTest() {
  describe('mdJsonTest', () => {
    it('emptyDoc', 0, () => {
      expect(flatOf('')).assertEqual('{\n  "blocks": []\n}\n');
    });
    it('paraText', 0, () => {
      const out: string = flatOf('hi');
      has(out, '"type": "para"');
      has(out, '"text": "hi"');
    });
    it('headingLevel', 0, () => {
      const out: string = flatOf('## T');
      has(out, '"type": "heading"');
      has(out, '"level": 2');
    });
    it('codeLangAndEscape', 0, () => {
      const out: string = flatOf('```js\na"b\\c\n```');
      has(out, '"type": "code"');
      has(out, '"lang": "js"');
      has(out, '"text": "a\\"b\\\\c"');
    });
    it('listOrdered', 0, () => {
      const out: string = flatOf('1. a\n2. b');
      has(out, '"type": "list"');
      has(out, '"ordered": true');
      has(out, '"start": 1');
      has(out, '"num": 1');
      has(out, '"num": 2');
    });
    it('listUnordered', 0, () => {
      const out: string = flatOf('- x');
      has(out, '"ordered": false');
      has(out, '"type": "list"');
    });
    it('tableAligns', 0, () => {
      const out: string = flatOf('| a | b |\n|:--|--:|\n| c | d |');
      has(out, '"type": "table"');
      has(out, '"left"');
      has(out, '"right"');
    });
    it('quoteBlocks', 0, () => {
      const out: string = flatOf('> q');
      has(out, '"type": "quote"');
      has(out, '"blocks": [');
    });
    it('hrType', 0, () => {
      has(flatOf('---'), '"type": "hr"');
    });
    it('boldInline', 0, () => {
      has(flatOf('**b**'), '"type": "bold"');
    });
    it('strikeInline', 0, () => {
      has(flatOf('~~s~~'), '"type": "strike"');
    });
    it('inlineCode', 0, () => {
      const out: string = flatOf('`c`');
      has(out, '"type": "code"');
      has(out, '"text": "c"');
    });
    it('linkInline', 0, () => {
      const out: string = flatOf('[t](u)');
      has(out, '"type": "link"');
      has(out, '"url": "u"');
      has(out, '"text": "t"');
    });
    it('imageInline', 0, () => {
      const out: string = flatOf('![a](i)');
      has(out, '"type": "image"');
      has(out, '"alt": "a"');
      has(out, '"url": "i"');
    });
    it('softBreakEscaped', 0, () => {
      has(flatOf('a\nb'), '"text": "a\\nb"');
    });
    it('cjkContent', 0, () => {
      has(flatOf('# 中文'), '"text": "中文"');
    });
    it('treeEmpty', 0, () => {
      expect(treeOf('')).assertEqual('{\n  "blocks": [],\n  "sections": []\n}\n');
    });
    it('treeBasicSection', 0, () => {
      const out: string = treeOf('# A\npara');
      has(out, '"sections": [');
      has(out, '"level": 1');
      has(out, '"type": "para"');
      has(out, '"children": []');
    });
    it('treeNestingOrder', 0, () => {
      const out: string = treeOf('# A\n## B\n# C');
      const i1: number = out.indexOf('"level": 1');
      const i2: number = out.indexOf('"level": 2');
      const i3: number = out.indexOf('"level": 1', i1 + 1);
      expect(i1 >= 0).assertTrue();
      expect(i2 > i1).assertTrue();
      expect(i3 > i2).assertTrue();
    });
    it('treeH2InsideH1Children', 0, () => {
      const out: string = treeOf('# A\n## B');
      const iChild: number = out.indexOf('"children": [');
      const iH2: number = out.indexOf('"level": 2');
      expect(iChild >= 0).assertTrue();
      expect(iH2 > iChild).assertTrue();
    });
    it('treePreamble', 0, () => {
      const out: string = treeOf('intro\n# A');
      const iPara: number = out.indexOf('"type": "para"');
      const iSec: number = out.indexOf('"sections": [');
      expect(iPara >= 0).assertTrue();
      expect(iSec > iPara).assertTrue();
    });
    it('treeH2BeforeH1Pops', 0, () => {
      const out: string = treeOf('## B\n# A');
      const iB: number = out.indexOf('"level": 2');
      const iA: number = out.indexOf('"level": 1');
      expect(iB >= 0).assertTrue();
      expect(iA > iB).assertTrue();
    });
  });
}
