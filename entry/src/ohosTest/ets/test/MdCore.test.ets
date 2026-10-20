import { describe, it, expect } from '@ohos/hypium';
import {
  MdAlign,
  MdBlock,
  MdCode,
  MdHeading,
  MdInline,
  MdList,
  MdPara,
  MdQuote,
  MdTable,
  MdText,
  MdThematicBreak,
  collectMdText
} from '../../../main/ets/core/MdModel';
import { MdParser } from '../../../main/ets/core/MdParser';

function blocksOf(src: string): MdBlock[] {
  return MdParser.parse(src).blocks;
}

function single(src: string): MdBlock {
  const list = blocksOf(src);
  expect(list.length).assertEqual(1);
  return list[0];
}

function asPara(b: MdBlock): MdPara {
  if (b instanceof MdPara) {
    return b;
  }
  throw new Error('expected MdPara but kind=' + b.kind);
}

function asHeading(b: MdBlock): MdHeading {
  if (b instanceof MdHeading) {
    return b;
  }
  throw new Error('expected MdHeading but kind=' + b.kind);
}

function asCode(b: MdBlock): MdCode {
  if (b instanceof MdCode) {
    return b;
  }
  throw new Error('expected MdCode but kind=' + b.kind);
}

function asQuote(b: MdBlock): MdQuote {
  if (b instanceof MdQuote) {
    return b;
  }
  throw new Error('expected MdQuote but kind=' + b.kind);
}

function asList(b: MdBlock): MdList {
  if (b instanceof MdList) {
    return b;
  }
  throw new Error('expected MdList but kind=' + b.kind);
}

function asTable(b: MdBlock): MdTable {
  if (b instanceof MdTable) {
    return b;
  }
  throw new Error('expected MdTable but kind=' + b.kind);
}

function asBreak(b: MdBlock): MdThematicBreak {
  if (b instanceof MdThematicBreak) {
    return b;
  }
  throw new Error('expected MdThematicBreak but kind=' + b.kind);
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

function paraTextOf(src: string): string {
  return inlineTextOf(asPara(single(src)).inline);
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
  const doc = MdParser.parse(src);
  const collected = collectMdText(doc);
  expect(isSubseq(alnumOf(src), alnumOf(collected))).assertTrue();
}

export default function mdCoreTest(): void {
  describe('mdCoreTest', () => {
    it('emptyDoc', 0, () => {
      expect(blocksOf('').length).assertEqual(0);
    });

    it('whitespaceOnly', 0, () => {
      expect(blocksOf('\n\n   \n').length).assertEqual(0);
    });

    it('singlePara', 0, () => {
      expect(paraTextOf('hello world')).assertEqual('hello world');
    });

    it('paraSoftBreak', 0, () => {
      expect(paraTextOf('line one\nline two')).assertEqual('line one\nline two');
    });

    it('twoParas', 0, () => {
      const bs = blocksOf('first para\n\nsecond para');
      expect(bs.length).assertEqual(2);
      expect(inlineTextOf(asPara(bs[0]).inline)).assertEqual('first para');
      expect(inlineTextOf(asPara(bs[1]).inline)).assertEqual('second para');
    });

    it('multiBlankCollapse', 0, () => {
      expect(blocksOf('a\n\n\n\n\nb').length).assertEqual(2);
    });

    it('crlfInput', 0, () => {
      const bs = blocksOf('alpha\r\n\r\nbeta');
      expect(bs.length).assertEqual(2);
      expect(inlineTextOf(asPara(bs[0]).inline)).assertEqual('alpha');
      expect(inlineTextOf(asPara(bs[1]).inline)).assertEqual('beta');
    });

    it('h1Basic', 0, () => {
      const h = asHeading(single('# Title'));
      expect(h.level).assertEqual(1);
      expect(inlineTextOf(h.inline)).assertEqual('Title');
    });

    it('h2toh6', 0, () => {
      const bs = blocksOf('## H2\n\n### H3\n\n#### H4\n\n##### H5\n\n###### H6');
      expect(bs.length).assertEqual(5);
      const levels: string[] = [];
      for (const b of bs) {
        levels.push(`${asHeading(b).level}`);
      }
      expect(levels.join(',')).assertEqual('2,3,4,5,6');
    });

    it('headingTrailingHashes', 0, () => {
      const h = asHeading(single('# Title ##'));
      expect(h.level).assertEqual(1);
      expect(inlineTextOf(h.inline)).assertEqual('Title');
    });

    it('headingInnerHash', 0, () => {
      expect(inlineTextOf(asHeading(single('# C# tips')).inline)).assertEqual('C# tips');
    });

    it('headingNoSpaceDegrade', 0, () => {
      expect(paraTextOf('#nospace')).assertEqual('#nospace');
    });

    it('sevenHashesDegrade', 0, () => {
      expect(paraTextOf('####### too many')).assertEqual('####### too many');
    });

    it('emptyHeading', 0, () => {
      const h = asHeading(single('## ##'));
      expect(h.level).assertEqual(2);
      expect(h.inline.length).assertEqual(0);
    });

    it('unorderedDash', 0, () => {
      const l = asList(single('- one\n- two\n- three'));
      expect(l.ordered).assertFalse();
      expect(l.tight).assertTrue();
      expect(l.items.length).assertEqual(3);
      expect(inlineTextOf(asPara(l.items[0].blocks[0]).inline)).assertEqual('one');
      expect(inlineTextOf(asPara(l.items[2].blocks[0]).inline)).assertEqual('three');
    });

    it('unorderedStarPlus', 0, () => {
      const l = asList(single('* aa\n+ bb'));
      expect(l.ordered).assertFalse();
      expect(l.items.length).assertEqual(2);
      expect(inlineTextOf(asPara(l.items[0].blocks[0]).inline)).assertEqual('aa');
      expect(inlineTextOf(asPara(l.items[1].blocks[0]).inline)).assertEqual('bb');
    });

    it('orderedDot', 0, () => {
      const l = asList(single('1. one\n2. two'));
      expect(l.ordered).assertTrue();
      expect(l.start).assertEqual(1);
      expect(l.items.length).assertEqual(2);
      expect(l.items[0].num).assertEqual(1);
      expect(l.items[1].num).assertEqual(2);
      expect(inlineTextOf(asPara(l.items[1].blocks[0]).inline)).assertEqual('two');
    });

    it('orderedParen', 0, () => {
      const l = asList(single('1) one\n2) two'));
      expect(l.ordered).assertTrue();
      expect(l.items.length).assertEqual(2);
      expect(inlineTextOf(asPara(l.items[1].blocks[0]).inline)).assertEqual('two');
    });

    it('orderedStart3', 0, () => {
      const l = asList(single('3. three\n4. four'));
      expect(l.start).assertEqual(3);
      expect(l.items[0].num).assertEqual(3);
      expect(l.items[1].num).assertEqual(4);
    });

    it('orderedKeepsNums', 0, () => {
      const src = '5. five\n9. nine';
      const l = asList(single(src));
      expect(l.start).assertEqual(5);
      expect(l.items[0].num).assertEqual(5);
      expect(l.items[1].num).assertEqual(9);
      assertLossless(src);
    });

    it('nestedList', 0, () => {
      const src = '- a\n  - b\n- c';
      const l = asList(single(src));
      expect(l.items.length).assertEqual(2);
      const inner = l.items[0].blocks;
      expect(inner.length).assertEqual(2);
      expect(inlineTextOf(asPara(inner[0]).inline)).assertEqual('a');
      const nl = asList(inner[1]);
      expect(nl.items.length).assertEqual(1);
      expect(inlineTextOf(asPara(nl.items[0].blocks[0]).inline)).assertEqual('b');
      expect(inlineTextOf(asPara(l.items[1].blocks[0]).inline)).assertEqual('c');
      assertLossless(src);
    });

    it('deepNest3', 0, () => {
      const src = '- a\n  - b\n    - c';
      const l = asList(single(src));
      const l2 = asList(l.items[0].blocks[1]);
      const l3 = asList(l2.items[0].blocks[1]);
      expect(inlineTextOf(asPara(l3.items[0].blocks[0]).inline)).assertEqual('c');
      assertLossless(src);
    });

    it('orderedInUnordered', 0, () => {
      const src = '- a\n  1. b\n  2. c';
      const l = asList(single(src));
      const inner = l.items[0].blocks;
      expect(inner.length).assertEqual(2);
      const nl = asList(inner[1]);
      expect(nl.ordered).assertTrue();
      expect(nl.items.length).assertEqual(2);
      expect(inlineTextOf(asPara(nl.items[0].blocks[0]).inline)).assertEqual('b');
      assertLossless(src);
    });

    it('looseList', 0, () => {
      const l = asList(single('- a\n\n- b'));
      expect(l.tight).assertFalse();
      expect(l.items.length).assertEqual(2);
    });

    it('itemContinuation', 0, () => {
      const l = asList(single('- a\n  more text'));
      expect(inlineTextOf(asPara(l.items[0].blocks[0]).inline)).assertEqual('a\nmore text');
    });

    it('itemLazyContinuation', 0, () => {
      const l = asList(single('- a\nlazy'));
      expect(inlineTextOf(asPara(l.items[0].blocks[0]).inline)).assertEqual('a\nlazy');
    });

    it('listWithCode', 0, () => {
      const src = '- a\n\n  ```\n  code line\n  ```';
      const l = asList(single(src));
      expect(l.tight).assertFalse();
      const inner = l.items[0].blocks;
      expect(inner.length).assertEqual(2);
      expect(inlineTextOf(asPara(inner[0]).inline)).assertEqual('a');
      const c = asCode(inner[1]);
      expect(c.text).assertEqual('code line');
      assertLossless(src);
    });

    it('codeBasic', 0, () => {
      const c = asCode(single('```\nsimple\n```'));
      expect(c.lang).assertEqual('');
      expect(c.text).assertEqual('simple');
    });

    it('codeLang', 0, () => {
      const c = asCode(single('```rust\nfn main() {}\n```'));
      expect(c.lang).assertEqual('rust');
      expect(c.text).assertEqual('fn main() {}');
    });

    it('codeUnclosed', 0, () => {
      const c = asCode(single('```\nkeep me'));
      expect(c.text).assertEqual('keep me');
    });

    it('codeKeepsBlankLines', 0, () => {
      expect(asCode(single('```\na\n\nb\n```')).text).assertEqual('a\n\nb');
    });

    it('codeIndentPreserved', 0, () => {
      expect(asCode(single('```\n  indented\n```')).text).assertEqual('  indented');
    });

    it('tildeFence', 0, () => {
      const c = asCode(single('~~~js\nlet x = 1\n~~~'));
      expect(c.lang).assertEqual('js');
      expect(c.text).assertEqual('let x = 1');
    });

    it('fenceFourBackticks', 0, () => {
      const c = asCode(single('````\n```\ninner\n```\n````'));
      expect(c.text).assertEqual('```\ninner\n```');
    });

    it('quoteBasic', 0, () => {
      const q = asQuote(single('> quoted text\n> more'));
      expect(q.blocks.length).assertEqual(1);
      expect(inlineTextOf(asPara(q.blocks[0]).inline)).assertEqual('quoted text\nmore');
    });

    it('quoteNested', 0, () => {
      const q = asQuote(single('> outer\n> > inner'));
      expect(q.blocks.length).assertEqual(2);
      const inner = asQuote(q.blocks[1]);
      expect(inlineTextOf(asPara(inner.blocks[0]).inline)).assertEqual('inner');
    });

    it('quoteWithHeading', 0, () => {
      const q = asQuote(single('> # Title\n> paragraph'));
      expect(q.blocks.length).assertEqual(2);
      expect(asHeading(q.blocks[0]).level).assertEqual(1);
      expect(inlineTextOf(asPara(q.blocks[1]).inline)).assertEqual('paragraph');
    });

    it('quoteWithList', 0, () => {
      const q = asQuote(single('> - a\n> - b'));
      const l = asList(q.blocks[0]);
      expect(l.items.length).assertEqual(2);
      expect(inlineTextOf(asPara(l.items[1].blocks[0]).inline)).assertEqual('b');
    });

    it('quoteMultiBlock', 0, () => {
      const q = asQuote(single('> first\n>\n> second'));
      expect(q.blocks.length).assertEqual(2);
      expect(inlineTextOf(asPara(q.blocks[0]).inline)).assertEqual('first');
      expect(inlineTextOf(asPara(q.blocks[1]).inline)).assertEqual('second');
    });

    it('tableBasic', 0, () => {
      const t = asTable(single('| a | b |\n| --- | --- |\n| 1 | 2 |'));
      expect(t.aligns.length).assertEqual(2);
      expect(t.aligns[0]).assertEqual(MdAlign.None);
      expect(t.rows.length).assertEqual(2);
      expect(inlineTextOf(t.rows[0][0].inline)).assertEqual('a');
      expect(inlineTextOf(t.rows[0][1].inline)).assertEqual('b');
      expect(inlineTextOf(t.rows[1][0].inline)).assertEqual('1');
      expect(inlineTextOf(t.rows[1][1].inline)).assertEqual('2');
    });

    it('tableAligns', 0, () => {
      const t = asTable(single('| l | c | r | n |\n| :--- | :---: | ---: | --- |\n| 1 | 2 | 3 | 4 |'));
      expect(t.aligns.length).assertEqual(4);
      expect(t.aligns[0]).assertEqual(MdAlign.Left);
      expect(t.aligns[1]).assertEqual(MdAlign.Center);
      expect(t.aligns[2]).assertEqual(MdAlign.Right);
      expect(t.aligns[3]).assertEqual(MdAlign.None);
    });

    it('tableRagged', 0, () => {
      const src = '| a | b |\n| --- | --- |\n| 1 | 2 | 3 |';
      const t = asTable(single(src));
      expect(t.rows.length).assertEqual(2);
      expect(t.rows[1].length).assertEqual(3);
      expect(inlineTextOf(t.rows[1][2].inline)).assertEqual('3');
      assertLossless(src);
    });

    it('tableEscapedPipe', 0, () => {
      const src = '| a\\|b | c |\n| --- | --- |\n| 1 | 2 |';
      const t = asTable(single(src));
      expect(inlineTextOf(t.rows[0][0].inline)).assertEqual('a|b');
      assertLossless(src);
    });

    it('tableNoDelimDegrade', 0, () => {
      const bs = blocksOf('| a | b |\n| 1 | 2 |');
      expect(bs.length).assertEqual(1);
      expect(inlineTextOf(asPara(bs[0]).inline)).assertEqual('| a | b |\n| 1 | 2 |');
    });

    it('hrDash', 0, () => {
      asBreak(single('---'));
    });

    it('hrVariants', 0, () => {
      const bs = blocksOf('***\n\n___\n\n- - -');
      expect(bs.length).assertEqual(3);
      asBreak(bs[0]);
      asBreak(bs[1]);
      asBreak(bs[2]);
    });

    it('notHrDegrade', 0, () => {
      expect(paraTextOf('--')).assertEqual('--');
    });

    it('htmlDegrade', 0, () => {
      expect(paraTextOf('<div class="x">raw</div>')).assertEqual('<div class="x">raw</div>');
    });

    it('setextDegrade', 0, () => {
      expect(paraTextOf('Title\n===')).assertEqual('Title\n===');
    });

    it('escapedStarDegrade', 0, () => {
      expect(paraTextOf('\\*not emphasized\\*')).assertEqual('\\*not emphasized\\*');
    });

    it('cjkContent', 0, () => {
      const src = '# 中文标题\n\n正文段落，包含中文。\n\n- 项目一\n- 项目二';
      const bs = blocksOf(src);
      expect(bs.length).assertEqual(3);
      expect(inlineTextOf(asHeading(bs[0]).inline)).assertEqual('中文标题');
      expect(inlineTextOf(asPara(bs[1]).inline)).assertEqual('正文段落，包含中文。');
      const l = asList(bs[2]);
      expect(l.items.length).assertEqual(2);
      expect(inlineTextOf(asPara(l.items[0].blocks[0]).inline)).assertEqual('项目一');
      assertLossless(src);
    });

    it('comboDoc', 0, () => {
      const lines: string[] = [
        '# 项目说明',
        '',
        '这是一个 **示例** 项目。',
        '',
        '## 功能',
        '',
        '- 解析 Markdown',
        '- 导出 JSON',
        '  - 嵌套项',
        '- 导出 YAML',
        '',
        '1. 第一步',
        '2. 第二步',
        '',
        '```json',
        '{"a": 1}',
        '```',
        '',
        '> 引用一行',
        '> 引用两行',
        '',
        '| 名称 | 值 |',
        '| --- | --- |',
        '| foo | bar |',
        '',
        '---',
        '',
        '尾部段落。'
      ];
      const src = lines.join('\n');
      const bs = blocksOf(src);
      expect(bs.length).assertEqual(10);
      expect(asHeading(bs[0]).level).assertEqual(1);
      asPara(bs[1]);
      expect(asHeading(bs[2]).level).assertEqual(2);
      const ul = asList(bs[3]);
      expect(ul.ordered).assertFalse();
      expect(ul.items.length).assertEqual(3);
      const ol = asList(bs[4]);
      expect(ol.ordered).assertTrue();
      expect(ol.start).assertEqual(1);
      const code = asCode(bs[5]);
      expect(code.lang).assertEqual('json');
      const q = asQuote(bs[6]);
      expect(q.blocks.length).assertEqual(1);
      const tb = asTable(bs[7]);
      expect(tb.rows.length).assertEqual(2);
      asBreak(bs[8]);
      asPara(bs[9]);
      assertLossless(src);
    });

    it('losslessSweep', 0, () => {
      const sources: string[] = [
        '# T\n\ntext',
        '- a\n  - b\n- c',
        '1. x\n2. y',
        '3. three\n4. four',
        '```\ncode\n```',
        '```js\nlet a = 1\n```',
        '> q\n> > qq',
        '| a | b |\n| --- | --- |\n| 1 | 2 |',
        '| a\\|b | c |\n| --- | --- |\n| x | y |',
        '---\n***\n___',
        '<div>x</div>\n\n<span>y</span>',
        '# 中文\n\n段落中文',
        '- item\n\n  ```\n  c\n  ```',
        '5. five\n9. nine',
        '#nospace\n####### deep\n--\n=='
      ];
      for (const s of sources) {
        assertLossless(s);
      }
    });
  });
}
