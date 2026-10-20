import { describe, it, expect } from '@ohos/hypium';
import { MdToYaml } from '../../../main/ets/core/MdYamlOut';

function yFlat(src: string): string {
  return MdToYaml.flat(src);
}

function yTree(src: string): string {
  return MdToYaml.tree(src);
}

function has(s: string, sub: string): void {
  expect(s.indexOf(sub) >= 0).assertTrue();
}

export default function mdYamlTest() {
  describe('mdYamlTest', () => {
    it('emptyDoc', 0, () => {
      expect(yFlat('')).assertEqual('blocks: []\n');
    });
    it('paraPlainScalar', 0, () => {
      const out: string = yFlat('hi');
      has(out, 'blocks:');
      has(out, '- type: para');
      has(out, 'text: hi');
    });
    it('headingLevel', 0, () => {
      const out: string = yFlat('## T');
      has(out, 'type: heading');
      has(out, 'level: 2');
    });
    it('codeBlockPlainSingleLine', 0, () => {
      const out: string = yFlat('```ts\nconsole.log("x")\n```');
      has(out, 'type: code');
      has(out, 'lang: ts');
      has(out, 'text: console.log("x")');
    });
    it('codeBlockLiteralMultiLine', 0, () => {
      const out: string = yFlat('```ts\nlet a = 1;\nlet b = 2;\n```');
      has(out, 'type: code');
      has(out, 'lang: ts');
      has(out, 'text: |-');
      has(out, 'let a = 1;');
      has(out, 'let b = 2;');
    });
    it('quotedColonScalar', 0, () => {
      has(yFlat('has: colon'), 'text: "has: colon"');
    });
    it('quotedNumericScalar', 0, () => {
      has(yFlat('123'), 'text: "123"');
    });
    it('quotedBoolScalar', 0, () => {
      has(yFlat('true'), 'text: "true"');
    });
    it('listUnordered', 0, () => {
      const out: string = yFlat('- x');
      has(out, 'type: list');
      has(out, 'ordered: false');
    });
    it('listOrderedNums', 0, () => {
      const out: string = yFlat('1. a\n2. b');
      has(out, 'ordered: true');
      has(out, 'start: 1');
      has(out, 'num: 1');
      has(out, 'num: 2');
    });
    it('tableAligns', 0, () => {
      const out: string = yFlat('| a | b |\n|:--|--:|\n| c | d |');
      has(out, 'type: table');
      has(out, '- left');
      has(out, '- right');
    });
    it('quoteBlocks', 0, () => {
      const out: string = yFlat('> q');
      has(out, 'type: quote');
      has(out, 'blocks:');
    });
    it('hrType', 0, () => {
      has(yFlat('---'), 'type: hr');
    });
    it('linkInline', 0, () => {
      const out: string = yFlat('[t](u)');
      has(out, 'type: link');
      has(out, 'url: u');
      has(out, 'text: t');
    });
    it('imageInline', 0, () => {
      const out: string = yFlat('![a](i)');
      has(out, 'type: image');
      has(out, 'alt: a');
      has(out, 'url: i');
    });
    it('cjkPlainScalar', 0, () => {
      has(yFlat('中文内容'), 'text: 中文内容');
    });
    it('treeSections', 0, () => {
      const out: string = yTree('# A\npara');
      has(out, 'sections:');
      has(out, 'level: 1');
      has(out, 'type: para');
      has(out, 'children: []');
    });
    it('treeNesting', 0, () => {
      const out: string = yTree('# A\n## B');
      const iChild: number = out.indexOf('children:');
      const iH2: number = out.indexOf('level: 2');
      expect(iChild >= 0).assertTrue();
      expect(iH2 > iChild).assertTrue();
    });
    it('yamlStringWithHashQuoted', 0, () => {
      has(yFlat('a # b'), 'text: "a # b"');
    });
  });
}
