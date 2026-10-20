import { describe, it, expect } from '@ohos/hypium';
import {
  MdBold,
  MdBlock,
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
  MdText,
  collectInlineText
} from '../../../main/ets/core/MdModel';
import { MdInlineParser } from '../../../main/ets/core/MdInlineParser';

function inl(src: string): MdInline[] {
  return MdInlineParser.parseInline(src);
}

function one(src: string): MdInline {
  const arr: MdInline[] = inl(src);
  expect(arr.length).assertEqual(1);
  return arr[0];
}

function asText(n: MdInline): MdText {
  if (n instanceof MdText) {
    return n;
  }
  throw new Error('expected MdText but kind=' + n.kind);
}

function asBold(n: MdInline): MdBold {
  if (n instanceof MdBold) {
    return n;
  }
  throw new Error('expected MdBold but kind=' + n.kind);
}

function asItalic(n: MdInline): MdItalic {
  if (n instanceof MdItalic) {
    return n;
  }
  throw new Error('expected MdItalic but kind=' + n.kind);
}

function asStrike(n: MdInline): MdStrike {
  if (n instanceof MdStrike) {
    return n;
  }
  throw new Error('expected MdStrike but kind=' + n.kind);
}

function asInlineCode(n: MdInline): MdInlineCode {
  if (n instanceof MdInlineCode) {
    return n;
  }
  throw new Error('expected MdInlineCode but kind=' + n.kind);
}

function asLink(n: MdInline): MdLink {
  if (n instanceof MdLink) {
    return n;
  }
  throw new Error('expected MdLink but kind=' + n.kind);
}

function asImage(n: MdInline): MdImage {
  if (n instanceof MdImage) {
    return n;
  }
  throw new Error('expected MdImage but kind=' + n.kind);
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

function asList(b: MdBlock): MdList {
  if (b instanceof MdList) {
    return b;
  }
  throw new Error('expected MdList but kind=' + b.kind);
}

function asQuote(b: MdBlock): MdQuote {
  if (b instanceof MdQuote) {
    return b;
  }
  throw new Error('expected MdQuote but kind=' + b.kind);
}

function asTable(b: MdBlock): MdTable {
  if (b instanceof MdTable) {
    return b;
  }
  throw new Error('expected MdTable but kind=' + b.kind);
}

function alnumOf(s: string): string {
  let out: string = '';
  for (let i: number = 0; i < s.length; i += 1) {
    const code: number = s.charCodeAt(i);
    const isAlnum: boolean = (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    const isCjk: boolean = code >= 0x4E00 && code <= 0x9FFF;
    if (isAlnum || isCjk) {
      out += s.charAt(i);
    }
  }
  return out;
}

function isSubsequence(needle: string, hay: string): boolean {
  let pos: number = 0;
  for (let i: number = 0; i < hay.length && pos < needle.length; i += 1) {
    if (hay.charAt(i) == needle.charAt(pos)) {
      pos += 1;
    }
  }
  return pos == needle.length;
}

function assertInlineLossless(src: string): void {
  const nodes: MdInline[] = MdInlineParser.parseInline(src);
  const parts: string[] = [];
  collectInlineText(nodes, parts);
  const collected: string = parts.join('');
  expect(isSubsequence(alnumOf(src), alnumOf(collected))).assertTrue();
}

export default function mdInlineTest() {
  describe('mdInlineTest', () => {
    it('plainText', 0, () => {
      expect(asText(one('hello')).text).assertEqual('hello');
    });
    it('bold', 0, () => {
      const b: MdBold = asBold(one('**bold**'));
      expect(b.inline.length).assertEqual(1);
      expect(asText(b.inline[0]).text).assertEqual('bold');
    });
    it('italicStar', 0, () => {
      const t: MdItalic = asItalic(one('*it*'));
      expect(asText(t.inline[0]).text).assertEqual('it');
    });
    it('italicUnderscore', 0, () => {
      const t: MdItalic = asItalic(one('_em_'));
      expect(asText(t.inline[0]).text).assertEqual('em');
    });
    it('boldItalicTriple', 0, () => {
      const b: MdBold = asBold(one('***bi***'));
      const inner: MdItalic = asItalic(b.inline[0]);
      expect(asText(inner.inline[0]).text).assertEqual('bi');
    });
    it('strike', 0, () => {
      const s: MdStrike = asStrike(one('~~gone~~'));
      expect(asText(s.inline[0]).text).assertEqual('gone');
    });
    it('codeSpan', 0, () => {
      expect(asInlineCode(one('`code`')).text).assertEqual('code');
    });
    it('codeSpanDoubleTick', 0, () => {
      expect(asInlineCode(one('``a ` b``')).text).assertEqual('a ` b');
    });
    it('codeSpanStripSpaces', 0, () => {
      expect(asInlineCode(one('` x `')).text).assertEqual('x');
    });
    it('codeSpanNoClose', 0, () => {
      expect(asText(one('`oops')).text).assertEqual('`oops');
    });
    it('codeSpanKeepsBackslash', 0, () => {
      expect(asInlineCode(one('`a\\*b`')).text).assertEqual('a\\*b');
    });
    it('link', 0, () => {
      const l: MdLink = asLink(one('[text](https://a.b)'));
      expect(l.url).assertEqual('https://a.b');
      expect(asText(l.inline[0]).text).assertEqual('text');
    });
    it('linkNestedBold', 0, () => {
      const l: MdLink = asLink(one('[**b**](u)'));
      expect(asText(asBold(l.inline[0]).inline[0]).text).assertEqual('b');
    });
    it('linkBalancedParenUrl', 0, () => {
      const l: MdLink = asLink(one('[t](https://a.b/(x))'));
      expect(l.url).assertEqual('https://a.b/(x)');
    });
    it('image', 0, () => {
      const img: MdImage = asImage(one('![alt](img.png)'));
      expect(img.alt).assertEqual('alt');
      expect(img.url).assertEqual('img.png');
    });
    it('imageEmptyAlt', 0, () => {
      const img: MdImage = asImage(one('![](u.png)'));
      expect(img.alt).assertEqual('');
      expect(img.url).assertEqual('u.png');
    });
    it('imageInsideLink', 0, () => {
      const l: MdLink = asLink(one('[![a](i.png)](https://l)'));
      const img: MdImage = asImage(l.inline[0]);
      expect(img.alt).assertEqual('a');
      expect(img.url).assertEqual('i.png');
      expect(l.url).assertEqual('https://l');
    });
    it('escapeStar', 0, () => {
      expect(asText(one('\\*x\\*')).text).assertEqual('*x*');
    });
    it('escapeBracketWholeLink', 0, () => {
      expect(asText(one('\\[x\\](y)')).text).assertEqual('[x](y)');
    });
    it('escapedBackslash', 0, () => {
      expect(asText(one('a\\\\b')).text).assertEqual('a\\b');
    });
    it('unclosedBold', 0, () => {
      expect(asText(one('**bold')).text).assertEqual('**bold');
    });
    it('unclosedItalic', 0, () => {
      expect(asText(one('*it')).text).assertEqual('*it');
    });
    it('unclosedLink', 0, () => {
      expect(asText(one('[text')).text).assertEqual('[text');
    });
    it('unclosedParenLink', 0, () => {
      expect(asText(one('[t](u')).text).assertEqual('[t](u');
    });
    it('unclosedImage', 0, () => {
      const arr: MdInline[] = inl('![alt');
      expect(arr.length).assertEqual(1);
      expect(asText(arr[0]).text).assertEqual('![alt');
    });
    it('snakeCaseNotItalic', 0, () => {
      expect(asText(one('snake_case_word')).text).assertEqual('snake_case_word');
    });
    it('blankBoldNotParsed', 0, () => {
      expect(asText(one('**  **')).text).assertEqual('**  **');
    });
    it('mixedSequence', 0, () => {
      const arr: MdInline[] = inl('a **b** c');
      expect(arr.length).assertEqual(3);
      expect(asText(arr[0]).text).assertEqual('a ');
      expect(asText(asBold(arr[1]).inline[0]).text).assertEqual('b');
      expect(asText(arr[2]).text).assertEqual(' c');
    });
    it('boldContainingItalic', 0, () => {
      const b: MdBold = asBold(one('**b *i* d**'));
      expect(b.inline.length).assertEqual(3);
      expect(asText(b.inline[0]).text).assertEqual('b ');
      expect(asText(asItalic(b.inline[1]).inline[0]).text).assertEqual('i');
      expect(asText(b.inline[2]).text).assertEqual(' d');
    });
    it('strikeInsideBold', 0, () => {
      const b: MdBold = asBold(one('**~~s~~**'));
      expect(asText(asStrike(b.inline[0]).inline[0]).text).assertEqual('s');
    });
    it('codeInsideBold', 0, () => {
      const b: MdBold = asBold(one('**`c`**'));
      expect(asInlineCode(b.inline[0]).text).assertEqual('c');
    });
    it('textMergesAcrossEscape', 0, () => {
      expect(asText(one('a\\*b')).text).assertEqual('a*b');
    });
    it('parseFullHeadingBold', 0, () => {
      const blocks: MdBlock[] = MdInlineParser.parseFull('# T **b**').blocks;
      const h: MdHeading = asHeading(blocks[0]);
      expect(h.level).assertEqual(1);
      expect(h.inline.length).assertEqual(2);
      expect(asText(h.inline[0]).text).assertEqual('T ');
      expect(asText(asBold(h.inline[1]).inline[0]).text).assertEqual('b');
    });
    it('parseFullParaLink', 0, () => {
      const blocks: MdBlock[] = MdInlineParser.parseFull('see [docs](https://d)').blocks;
      const p: MdPara = asPara(blocks[0]);
      expect(asText(p.inline[0]).text).assertEqual('see ');
      expect(asLink(p.inline[1]).url).assertEqual('https://d');
    });
    it('parseFullTableCellBold', 0, () => {
      const blocks: MdBlock[] = MdInlineParser.parseFull('| h1 | h2 |\n| --- | --- |\n| c | **b** |').blocks;
      const t: MdTable = asTable(blocks[0]);
      expect(t.rows.length).assertEqual(2);
      expect(asText(t.rows[0][0].inline[0]).text).assertEqual('h1');
      expect(asText(asBold(t.rows[1][1].inline[0]).inline[0]).text).assertEqual('b');
    });
    it('parseFullListBold', 0, () => {
      const blocks: MdBlock[] = MdInlineParser.parseFull('- item **b**').blocks;
      const list: MdList = asList(blocks[0]);
      const p: MdPara = asPara(list.items[0].blocks[0]);
      expect(p.inline.length).assertEqual(2);
      expect(asText(p.inline[0]).text).assertEqual('item ');
      expect(asText(asBold(p.inline[1]).inline[0]).text).assertEqual('b');
    });
    it('parseFullQuoteItalic', 0, () => {
      const blocks: MdBlock[] = MdInlineParser.parseFull('> q *i*').blocks;
      const q: MdQuote = asQuote(blocks[0]);
      const p: MdPara = asPara(q.blocks[0]);
      expect(asText(asItalic(p.inline[1]).inline[0]).text).assertEqual('i');
    });
    it('inlineLosslessSweep', 0, () => {
      assertInlineLossless('**bold** _em_ ~~s~~ `c` [t](u) ![a](i)');
      assertInlineLossless('***a\\*b*** [x](y(z)) \\`not code`');
      assertInlineLossless('snake_case **a *b* c** ![alt](img.png)');
      assertInlineLossless('~~**x**~~ [![a](i)](l) `code`');
      assertInlineLossless('中文**加粗**与[链接](https://例.中国)混合');
    });
  });
}
