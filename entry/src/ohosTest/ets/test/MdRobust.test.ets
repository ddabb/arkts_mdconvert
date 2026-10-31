import { describe, it, expect } from '@ohos/hypium';
import {
  MdBlock,
  MdBlockKind,
  MdInline,
  MdList,
  MdPara,
  MdText,
  collectMdText
} from '../../../main/ets/core/MdModel';
import { MdParser } from '../../../main/ets/core/MdParser';
import { MdInlineParser } from '../../../main/ets/core/MdInlineParser';
import { MdToJson } from '../../../main/ets/core/MdJsonOut';
import { MdToYaml } from '../../../main/ets/core/MdYamlOut';
import { MdToDocx } from '../../../main/ets/core/DocxOut';
import { MdToMm, MdToOpml } from '../../../main/ets/core/MmOpmlOut';

function blocksOf(src: string): MdBlock[] {
  return MdInlineParser.parseFull(src).blocks;
}

function asPara(b: MdBlock): MdPara {
  if (b instanceof MdPara) {
    return b;
  }
  throw new Error('expected MdPara but kind=' + b.kind);
}

function asList(b: MdBlock): MdList {
  if (b instanceof MdList) {
    return b;
  }
  throw new Error('expected MdList but kind=' + b.kind);
}

function inlineTextOf(inl: MdInline[]): string {
  let s = '';
  for (const node of inl) {
    if (node instanceof MdText) {
      s += node.text;
    }
  }
  return s;
}

function alnumOf(s: string): string {
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const code = s.charCodeAt(i);
    const ok = (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
      (code >= 0x4E00 && code <= 0x9FFF);
    if (ok) {
      out += s.charAt(i);
    }
  }
  return out;
}

function isSubseq(needle: string, hay: string): boolean {
  let k = 0;
  for (let i = 0; i < hay.length && k < needle.length; i++) {
    if (hay.charAt(i) == needle.charAt(k)) {
      k++;
    }
  }
  return k == needle.length;
}

function assertLossless(src: string): void {
  const doc = MdInlineParser.parseFull(src);
  const collected = collectMdText(doc);
  expect(isSubseq(alnumOf(src), alnumOf(collected))).assertTrue();
}

function stripTaskMarks(src: string): string {
  let stripped = src.split('[ ] ').join('').split('[x] ').join('').split('[X] ').join('');
  stripped = stripped.split('[ ]').join('').split('[x]').join('').split('[X]').join('');
  stripped = stripped.split('<br/>').join('').split('<br />').join('').split('<br>').join('');
  return stripped;
}

export default function mdRobustTest() {
  describe('mdRobustTest', () => {
    it('deepNest4Levels', 0, () => {
      const src = '- l1\n  - l2\n    - l3\n      - l4';
      const bs = blocksOf(src);
      const l1 = asList(bs[0]);
      expect(inlineTextOf(asPara(l1.items[0].blocks[0]).inline)).assertEqual('l1');
      const l2 = asList(l1.items[0].blocks[1]);
      expect(inlineTextOf(asPara(l2.items[0].blocks[0]).inline)).assertEqual('l2');
      const l3 = asList(l2.items[0].blocks[1]);
      expect(inlineTextOf(asPara(l3.items[0].blocks[0]).inline)).assertEqual('l3');
      const l4 = asList(l3.items[0].blocks[1]);
      expect(inlineTextOf(asPara(l4.items[0].blocks[0]).inline)).assertEqual('l4');
      assertLossless(src);
    });

    it('deepNest5Mixed', 0, () => {
      const src = '1. a\n   1. b\n      1. c\n         1. d\n            1. e';
      assertLossless(src);
      const bs = blocksOf(src);
      expect(bs.length).assertEqual(1);
    });

    it('codeBlockMdNotParsed', 0, () => {
      const src = '```\n# not heading\n- not list\n**not bold**\n| a | b |\n```';
      assertLossless(src);
      const doc = MdInlineParser.parseFull(src);
      const collected = collectMdText(doc);
      expect(collected.indexOf('# not heading') >= 0).assertTrue();
      expect(collected.indexOf('**not bold**') >= 0).assertTrue();
    });

    it('inlineEscapeSweep', 0, () => {
      const src = '\\*star\\* \\_under\\_ \\~tilde\\~ \\`tick\\` \\[bracket\\]';
      const doc = MdInlineParser.parseFull(src);
      const collected = collectMdText(doc);
      expect(collected.indexOf('*star*') >= 0).assertTrue();
      expect(collected.indexOf('_under_') >= 0).assertTrue();
      expect(collected.indexOf('~tilde~') >= 0).assertTrue();
      expect(collected.indexOf('`tick`') >= 0).assertTrue();
      expect(collected.indexOf('[bracket]') >= 0).assertTrue();
    });

    it('htmlBlockPreserved', 0, () => {
      const src = '<div class="note">\n  <p>内嵌段落</p>\n</div>';
      assertLossless(src);
      const bs = blocksOf(src);
      expect(bs.length).assertEqual(1);
      const text = inlineTextOf(asPara(bs[0]).inline);
      expect(text.indexOf('<div class="note">') >= 0).assertTrue();
      expect(text.indexOf('内嵌段落') >= 0).assertTrue();
    });

    it('htmlInlineTagsPreserved', 0, () => {
      const src = 'text with <b>bold tag</b> and <span class="x">span</span> here';
      assertLossless(src);
      const doc = MdInlineParser.parseFull(src);
      const collected = collectMdText(doc);
      expect(collected.indexOf('<b>bold tag</b>') >= 0).assertTrue();
      expect(collected.indexOf('<span class="x">span</span>') >= 0).assertTrue();
    });

    it('footnoteRefDegrade', 0, () => {
      const src = '正文带脚注[^1]引用。';
      assertLossless(src);
      const bs = blocksOf(src);
      const text = inlineTextOf(asPara(bs[0]).inline);
      expect(text.indexOf('[^1]') >= 0).assertTrue();
    });

    it('footnoteDefDegrade', 0, () => {
      const src = '[^1]: 这里是脚注内容。';
      assertLossless(src);
      const bs = blocksOf(src);
      const text = inlineTextOf(asPara(bs[0]).inline);
      expect(text.indexOf('这里是脚注内容') >= 0).assertTrue();
    });

    it('definitionListDegrade', 0, () => {
      const src = '术语\n: 术语的定义说明';
      assertLossless(src);
      const doc = MdInlineParser.parseFull(src);
      const collected = collectMdText(doc);
      expect(collected.indexOf('术语的定义说明') >= 0).assertTrue();
    });

    it('thematicBreakNoBlankLines', 0, () => {
      const src = '段落一\n---\n段落二';
      assertLossless(src);
      const bs = blocksOf(src);
      expect(bs.length).assertEqual(3);
      expect(inlineTextOf(asPara(bs[0]).inline)).assertEqual('段落一');
      expect(bs[1].kind).assertEqual(MdBlockKind.ThematicBreak);
      expect(inlineTextOf(asPara(bs[2]).inline)).assertEqual('段落二');
    });

    it('unclosedInlineMarks', 0, () => {
      const src = '*unclosed bold [unclosed link `unclosed code ~~unclosed strike ![unclosed img';
      assertLossless(src);
      const doc = MdInlineParser.parseFull(src);
      const collected = collectMdText(doc);
      expect(collected.indexOf('*unclosed bold') >= 0).assertTrue();
      expect(collected.indexOf('[unclosed link') >= 0).assertTrue();
      expect(collected.indexOf('`unclosed code') >= 0).assertTrue();
      expect(collected.indexOf('~~unclosed strike') >= 0).assertTrue();
      expect(collected.indexOf('![unclosed img') >= 0).assertTrue();
    });

    it('unclosedBlockConstructs', 0, () => {
      const fenceSrc = '```\ncontent without close';
      assertLossless(fenceSrc);
      const quoteSrc = '> quoted\n> > deeper';
      assertLossless(quoteSrc);
    });

    it('tableNoHeaderDegrade', 0, () => {
      const src = '| a | b |\n| 1 | 2 |';
      assertLossless(src);
      const bs = blocksOf(src);
      expect(bs.length).assertEqual(1);
      const text = inlineTextOf(asPara(bs[0]).inline);
      expect(text.indexOf('| a | b |') >= 0).assertTrue();
    });

    it('mixedEdgeDocLossless', 0, () => {
      const src = [
        '# 边界文档',
        '',
        '段落有 *未闭合 和 [未闭合链接 与 `未闭合代码。',
        '',
        '脚注引用[^a]与定义：',
        '',
        '[^a]: 脚注定义内容。',
        '',
        '- 任务 [ ] 嵌套\n- [x] 已完成',
        '',
        '<div>HTML 块</div>',
        '',
        '```',
        '*代码里的标记保留*',
        '```',
        '',
        '| 表 | 格 |\n| --- | --- |\n| 单元<br>换行 | 值 |',
        '',
        '---',
        '',
        '尾段 **加粗** 完整。'
      ].join('\n');
      assertLossless(stripTaskMarks(src));
      expect(MdToJson.flat(src).length > 0).assertTrue();
      expect(MdToYaml.flat(src).length > 0).assertTrue();
      expect(MdToDocx.generate(src).length > 0).assertTrue();
      expect(MdToMm.mm(src).length > 0).assertTrue();
      expect(MdToOpml.opml(src).length > 0).assertTrue();
    });

    it('jsonTaskAndBreakFields', 0, () => {
      const src = '- [ ] 待办甲\n- [x] 完成乙\n\n| 列 |\n| --- |\n| 甲<br>乙 |';
      const json = MdToJson.flat(src);
      expect(json.indexOf('"checked"') >= 0).assertTrue();
      expect(json.indexOf('"break"') >= 0).assertTrue();
      expect(json.indexOf('"待办甲"') >= 0).assertTrue();
      expect(json.indexOf('"完成乙"') >= 0).assertTrue();
    });

    it('yamlTaskFollowsJson', 0, () => {
      const src = '- [x] 已完成项';
      const yaml = MdToYaml.flat(src);
      expect(yaml.indexOf('checked: true') >= 0).assertTrue();
      const yaml2 = MdToYaml.flat('- [ ] 未完成项');
      expect(yaml2.indexOf('checked: false') >= 0).assertTrue();
    });

    it('yamlPlainItemNoChecked', 0, () => {
      const yaml = MdToYaml.flat('- 普通项');
      expect(yaml.indexOf('checked')).assertEqual(-1);
    });

    it('docxTaskAndBreakGenerate', 0, () => {
      const src = '- [ ] 待办\n- [x] 完成\n\n| 表头 |\n| --- |\n| 甲<br>乙 |';
      const bytes = MdToDocx.generate(src);
      expect(bytes.length > 0).assertTrue();
      const plain = MdToDocx.generate('- 普通项');
      expect(plain.length > 0).assertTrue();
    });
  });
}
