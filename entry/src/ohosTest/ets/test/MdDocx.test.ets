import { describe, it, expect } from '@ohos/hypium';
import { MdToDocx, DocxOptions } from '../../../main/ets/core/DocxOut';
import { crc32, utf8Encode } from '../../../main/ets/core/ZipWriter';

class ZipInfo {
  name: string = '';
  data: Uint8Array = new Uint8Array(0);
  crc: number = 0;
  csize: number = 0;
  lho: number = 0;
}

function decodeUtf8(b: Uint8Array): string {
  let out: string = '';
  let i: number = 0;
  while (i < b.length) {
    const c: number = b[i];
    if (c < 0x80) {
      out += String.fromCharCode(c);
      i += 1;
    } else if ((c & 0xE0) == 0xC0) {
      out += String.fromCharCode(((c & 0x1F) << 6) | (b[i + 1] & 0x3F));
      i += 2;
    } else if ((c & 0xF0) == 0xE0) {
      out += String.fromCharCode(((c & 0x0F) << 12) | ((b[i + 1] & 0x3F) << 6) | (b[i + 2] & 0x3F));
      i += 3;
    } else {
      const code: number = ((c & 0x07) << 18) | ((b[i + 1] & 0x3F) << 12) | ((b[i + 2] & 0x3F) << 6) | (b[i + 3] & 0x3F);
      const v: number = code - 0x10000;
      out += String.fromCharCode(0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF));
      i += 4;
    }
  }
  return out;
}

function readZip(bytes: Uint8Array): ZipInfo[] {
  const dv: DataView = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const eocd: number = bytes.length - 22;
  const count: number = dv.getUint16(eocd + 10, true);
  const cd: number = dv.getUint32(eocd + 16, true);
  const out: ZipInfo[] = [];
  let pos: number = cd;
  for (let i: number = 0; i < count; i += 1) {
    const nameLen: number = dv.getUint16(pos + 28, true);
    const extraLen: number = dv.getUint16(pos + 30, true);
    const commentLen: number = dv.getUint16(pos + 32, true);
    const info: ZipInfo = new ZipInfo();
    info.crc = dv.getUint32(pos + 16, true);
    info.csize = dv.getUint32(pos + 20, true);
    info.lho = dv.getUint32(pos + 42, true);
    info.name = decodeUtf8(bytes.subarray(pos + 46, pos + 46 + nameLen));
    const lNameLen: number = dv.getUint16(info.lho + 26, true);
    const lExtraLen: number = dv.getUint16(info.lho + 28, true);
    const start: number = info.lho + 30 + lNameLen + lExtraLen;
    info.data = bytes.subarray(start, start + info.csize);
    out.push(info);
    pos += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

function findEntry(infos: ZipInfo[], name: string): ZipInfo {
  for (const e of infos) {
    if (e.name == name) {
      return e;
    }
  }
  expect(false).assertTrue();
  return new ZipInfo();
}

function textOf(infos: ZipInfo[], name: string): string {
  return decodeUtf8(findEntry(infos, name).data);
}

function namesOf(infos: ZipInfo[]): string[] {
  const out: string[] = [];
  for (const e of infos) {
    out.push(e.name);
  }
  return out;
}

function countOf(s: string, sub: string): number {
  let n: number = 0;
  let pos: number = s.indexOf(sub);
  while (pos >= 0) {
    n += 1;
    pos = s.indexOf(sub, pos + sub.length);
  }
  return n;
}

function has(s: string, sub: string): void {
  expect(s.indexOf(sub) >= 0).assertTrue();
}

function pngBytes(w: number, h: number): Uint8Array {
  const b: Uint8Array = new Uint8Array(33);
  const sig: number[] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (let i: number = 0; i < 8; i += 1) {
    b[i] = sig[i];
  }
  const dv: DataView = new DataView(b.buffer);
  dv.setUint32(8, 13);
  b[12] = 0x49;
  b[13] = 0x48;
  b[14] = 0x44;
  b[15] = 0x52;
  dv.setUint32(16, w);
  dv.setUint32(20, h);
  b[24] = 8;
  b[25] = 6;
  b[26] = 0;
  b[27] = 0;
  b[28] = 0;
  return b;
}

function jpegBytes(w: number, h: number): Uint8Array {
  const b: Uint8Array = new Uint8Array(20);
  b[0] = 0xFF;
  b[1] = 0xD8;
  b[2] = 0xFF;
  b[3] = 0xC0;
  const dv: DataView = new DataView(b.buffer);
  dv.setUint16(4, 17);
  b[6] = 8;
  dv.setUint16(7, h);
  dv.setUint16(9, w);
  b[11] = 3;
  b[12] = 1;
  b[13] = 0x11;
  b[14] = 0;
  b[15] = 1;
  b[16] = 0x11;
  b[17] = 0;
  b[18] = 1;
  b[19] = 0x11;
  return b;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length != b.length) {
    return false;
  }
  for (let i: number = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

function defaultOpts(): DocxOptions {
  return new DocxOptions();
}

const SAMPLE: string = [
  '# 标题一',
  '',
  '段落 **粗** *斜* ~~删~~ `码` [链](https://a.example.com/x) ![图](img.png) A & B',
  '',
  '> 引用文',
  '',
  '- 项目一',
  '  - 嵌套项',
  '',
  '1. 有序A',
  '2. 有序B',
  '',
  '隔断段',
  '',
  '3. 三号',
  '',
  '```ts',
  'let a = 1 < 2;',
  '```',
  '',
  '| A | B |',
  '| :-- | --: |',
  '| 甲 | 乙 |',
  '',
  '---',
  ''
].join('\n');

export default function mdDocxTest() {
  describe('mdDocxTest', () => {
    it('crc32KnownVector', 0, () => {
      expect(crc32(utf8Encode('123456789'))).assertEqual(0xCBF43926);
    });
    it('crc32Empty', 0, () => {
      expect(crc32(new Uint8Array(0))).assertEqual(0);
    });
    it('utf8AsciiRoundtrip', 0, () => {
      const s: string = 'hello <>& world';
      expect(decodeUtf8(utf8Encode(s))).assertEqual(s);
    });
    it('utf8CjkRoundtrip', 0, () => {
      const bytes: Uint8Array = utf8Encode('中文测试');
      expect(bytes.length).assertEqual(12);
      expect(decodeUtf8(bytes)).assertEqual('中文测试');
    });
    it('utf8SurrogatePair', 0, () => {
      const bytes: Uint8Array = utf8Encode('a\u{1F600}b');
      expect(bytes.length).assertEqual(6);
      expect(decodeUtf8(bytes)).assertEqual('a\u{1F600}b');
    });
    it('utf8LoneSurrogateReplaced', 0, () => {
      const bytes: Uint8Array = utf8Encode('\uD800');
      expect(bytes.length).assertEqual(3);
      expect(bytes[0]).assertEqual(0xEF);
      expect(bytes[1]).assertEqual(0xBF);
      expect(bytes[2]).assertEqual(0xBD);
    });
    it('eocdStructure', 0, () => {
      const bytes: Uint8Array = MdToDocx.generate(SAMPLE);
      const dv: DataView = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      const eocd: number = bytes.length - 22;
      expect(dv.getUint32(eocd, true)).assertEqual(0x06054b50);
      expect(dv.getUint16(eocd + 4, true)).assertEqual(0);
      expect(dv.getUint16(eocd + 6, true)).assertEqual(0);
      expect(dv.getUint16(eocd + 8, true)).assertEqual(6);
      expect(dv.getUint16(eocd + 10, true)).assertEqual(6);
      const cdSize: number = dv.getUint32(eocd + 12, true);
      const cdOff: number = dv.getUint32(eocd + 16, true);
      expect(eocd - cdOff).assertEqual(cdSize);
      expect(dv.getUint16(eocd + 20, true)).assertEqual(0);
    });
    it('centralDirectoryNames', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const names: string[] = namesOf(infos);
      expect(names.length).assertEqual(6);
      expect(names.indexOf('[Content_Types].xml')).assertEqual(0);
      expect(names.indexOf('_rels/.rels')).assertEqual(1);
      expect(names.indexOf('word/document.xml')).assertEqual(2);
      expect(names.indexOf('word/styles.xml')).assertEqual(3);
      expect(names.indexOf('word/numbering.xml')).assertEqual(4);
      expect(names.indexOf('word/_rels/document.xml.rels')).assertEqual(5);
    });
    it('localHeaderStoreMode', 0, () => {
      const bytes: Uint8Array = MdToDocx.generate(SAMPLE);
      const infos: ZipInfo[] = readZip(bytes);
      const dv: DataView = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      for (const e of infos) {
        expect(dv.getUint32(e.lho, true)).assertEqual(0x04034b50);
        expect(dv.getUint16(e.lho + 4, true)).assertEqual(20);
        expect(dv.getUint16(e.lho + 6, true)).assertEqual(0x0800);
        expect(dv.getUint16(e.lho + 8, true)).assertEqual(0);
        expect(dv.getUint32(e.lho + 14, true)).assertEqual(e.crc);
        expect(dv.getUint32(e.lho + 18, true)).assertEqual(e.csize);
        expect(dv.getUint32(e.lho + 22, true)).assertEqual(e.csize);
      }
    });
    it('crcMatchesData', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      for (const e of infos) {
        expect(e.crc).assertEqual(crc32(e.data));
        expect(e.data.length).assertEqual(e.csize);
      }
    });
    it('contentTypesXml', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const ct: string = textOf(infos, '[Content_Types].xml');
      has(ct, 'Extension="rels"');
      has(ct, 'Extension="xml"');
      has(ct, 'PartName="/word/document.xml"');
      has(ct, 'PartName="/word/styles.xml"');
      has(ct, 'PartName="/word/numbering.xml"');
    });
    it('rootRelsXml', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const rels: string = textOf(infos, '_rels/.rels');
      has(rels, 'Id="rId1"');
      has(rels, 'Target="word/document.xml"');
      has(rels, 'officeDocument"');
    });
    it('docRelsHyperlinkExternal', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const rels: string = textOf(infos, 'word/_rels/document.xml.rels');
      has(rels, 'Id="rId1"');
      has(rels, 'Target="styles.xml"');
      has(rels, 'Id="rId2"');
      has(rels, 'Target="numbering.xml"');
      has(rels, 'Id="rId3"');
      has(rels, 'Target="https://a.example.com/x"');
      has(rels, 'TargetMode="External"');
    });
    it('docRelsDedup', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate('[a](https://d.example.com/) 与 [b](https://d.example.com/)'));
      const rels: string = textOf(infos, 'word/_rels/document.xml.rels');
      expect(countOf(rels, 'Target="https://d.example.com/"')).assertEqual(1);
      expect(countOf(rels, 'Id="rId3"')).assertEqual(1);
    });
    it('stylesContain', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const styles: string = textOf(infos, 'word/styles.xml');
      has(styles, 'w:styleId="Normal"');
      has(styles, 'w:styleId="Heading1"');
      has(styles, 'w:styleId="Heading6"');
      has(styles, 'w:styleId="MdcCode"');
      has(styles, 'w:styleId="MdcQuote"');
      has(styles, 'w:styleId="ListParagraph"');
      has(styles, 'w:styleId="TableGrid"');
      has(styles, '<w:outlineLvl w:val="0"/>');
    });
    it('numberingBulletAbstract', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const num: string = textOf(infos, 'word/numbering.xml');
      has(num, '<w:abstractNum w:abstractNumId="0"');
      has(num, '<w:numFmt w:val="bullet"/>');
      has(num, '\u2022');
      has(num, '\u25E6');
      has(num, '\u25AA');
      has(num, '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>');
    });
    it('numberingOrderedOverrides', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const num: string = textOf(infos, 'word/numbering.xml');
      has(num, '<w:abstractNum w:abstractNumId="1"');
      has(num, '<w:numFmt w:val="decimal"/>');
      has(num, '<w:lvlText w:val="%1."/>');
      expect(countOf(num, '<w:abstractNumId w:val="1"/>')).assertEqual(2);
      has(num, '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="3"/>');
    });
    it('headingStyleMapping', 0, () => {
      const src: string = '# H1\n\n## H2\n\n### H3\n\n#### H4\n\n##### H5\n\n###### H6';
      const infos: ZipInfo[] = readZip(MdToDocx.generate(src));
      const doc: string = textOf(infos, 'word/document.xml');
      expect(countOf(doc, '<w:pStyle w:val="Heading1"/>')).assertEqual(1);
      expect(countOf(doc, '<w:pStyle w:val="Heading2"/>')).assertEqual(1);
      expect(countOf(doc, '<w:pStyle w:val="Heading3"/>')).assertEqual(1);
      expect(countOf(doc, '<w:pStyle w:val="Heading4"/>')).assertEqual(1);
      expect(countOf(doc, '<w:pStyle w:val="Heading5"/>')).assertEqual(1);
      expect(countOf(doc, '<w:pStyle w:val="Heading6"/>')).assertEqual(1);
    });
    it('runPropsInline', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:b/>');
      has(doc, '<w:i/>');
      has(doc, '<w:strike/>');
      has(doc, 'w:ascii="Consolas"');
      has(doc, '>粗</w:t>');
      has(doc, '>码</w:t>');
    });
    it('hyperlinkInDocument', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:hyperlink r:id="rId3">');
      has(doc, 'w:val="0563C1"');
      has(doc, '>链</w:t>');
    });
    it('imagePlaceholderText', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '>[图](img.png)</w:t>');
    });
    it('tableStructure', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:tblStyle w:val="TableGrid"/>');
      expect(countOf(doc, '<w:gridCol')).assertEqual(2);
      has(doc, '<w:tblHeader/>');
      has(doc, 'w:fill="EDF2F8"');
      has(doc, '<w:jc w:val="left"/>');
      has(doc, '<w:jc w:val="right"/>');
      has(doc, '>甲</w:t>');
      expect(countOf(doc, '</w:tbl>')).assertEqual(1);
      has(doc, '</w:tbl><w:p></w:p>');
    });
    it('codeBlockParagraphs', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      expect(countOf(doc, '<w:pStyle w:val="MdcCode"/>')).assertEqual(1);
      has(doc, 'xml:space="preserve"');
      has(doc, '>let a = 1 &lt; 2;</w:t>');
    });
    it('hrBorder', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:pBdr><w:bottom w:val="single"');
    });
    it('quoteStyleInd', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:pStyle w:val="MdcQuote"/>');
      has(doc, '<w:ind w:left="360"/>');
      has(doc, '>引用文</w:t>');
    });
    it('xmlEscapeInText', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, 'A &amp; B');
    });
    it('sectPrA4', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:pgSz w:w="11906" w:h="16838"/>');
      has(doc, '<w:docGrid');
    });
    it('tightListSpacing', 0, () => {
      const tight: ZipInfo[] = readZip(MdToDocx.generate('- x'));
      has(textOf(tight, 'word/document.xml'), '<w:spacing w:after="0"/>');
      const loose: ZipInfo[] = readZip(MdToDocx.generate('- x\n\n- y'));
      const doc: string = textOf(loose, 'word/document.xml');
      expect(countOf(doc, 'w:after="0"')).assertEqual(0);
      has(doc, '<w:pStyle w:val="ListParagraph"/>');
    });
    it('nestedListIlvl', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:ilvl w:val="0"/><w:numId w:val="1"/>');
      has(doc, '<w:ilvl w:val="1"/><w:numId w:val="1"/>');
      has(doc, '>嵌套项</w:t>');
    });
    it('cjkDocumentContent', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(SAMPLE));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '标题一');
      has(doc, '有序A');
      has(doc, '三号');
    });
    it('emptyDocValid', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate(''));
      expect(infos.length).assertEqual(6);
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:body><w:sectPr');
      expect(doc.indexOf('<w:p>')).assertEqual(-1);
    });
    it('multiLineParaSoftBreak', 0, () => {
      const infos: ZipInfo[] = readZip(MdToDocx.generate('第一行\n第二行'));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '>第一行 第二行</w:t>');
    });
    it('generateWithDefaultsMatchesGenerate', 0, () => {
      const a: Uint8Array = MdToDocx.generate(SAMPLE);
      const b: Uint8Array = MdToDocx.generateWith(SAMPLE, defaultOpts(), new Map<string, Uint8Array>());
      expect(bytesEqual(a, b)).assertTrue();
    });
    it('firstLineIndentCjkParas', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.firstLineIndent = true;
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('# 标\n\n中文段落一。\n\n第二段文字。', o,
        new Map<string, Uint8Array>()));
      const doc: string = textOf(infos, 'word/document.xml');
      expect(countOf(doc, 'w:firstLineChars="200"')).assertEqual(2);
      has(doc, '<w:ind w:firstLineChars="200"/>');
    });
    it('firstLineIndentExcludesQuoteListCode', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.firstLineIndent = true;
      const src: string = '# 标\n\n> 引用段\n\n- 项一\n\n```js\ncode\n```\n\n普通段';
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith(src, o, new Map<string, Uint8Array>()));
      const doc: string = textOf(infos, 'word/document.xml');
      expect(countOf(doc, 'w:firstLineChars="200"')).assertEqual(1);
      has(doc, '<w:ind w:left="360"/>');
    });
    it('firstLineIndentNoCjkDoc', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.firstLineIndent = true;
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('Plain text one.\n\nPlain text two.', o,
        new Map<string, Uint8Array>()));
      const doc: string = textOf(infos, 'word/document.xml');
      expect(countOf(doc, 'w:firstLineChars')).assertEqual(0);
    });
    it('headingNumberingNum90', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.headingNumbers = true;
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('# A\n\n## B', o, new Map<string, Uint8Array>()));
      const num: string = textOf(infos, 'word/numbering.xml');
      has(num, '<w:abstractNum w:abstractNumId="2"');
      has(num, '<w:num w:numId="90"><w:abstractNumId w:val="2"/></w:num>');
      has(num, '<w:lvlText w:val="%1."/>');
      has(num, '<w:lvlText w:val="%1.%2."/>');
      has(num, '<w:lvlText w:val="%1.%2.%3.%4.%5.%6."/>');
      const styles: string = textOf(infos, 'word/styles.xml');
      has(styles, '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="90"/></w:numPr>');
    });
    it('tocBookmarksAndAnchors', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.toc = true;
      o.tocTitle = '目录';
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('# 一级\n\n正文A\n\n## 二级\n\n正文B', o,
        new Map<string, Uint8Array>()));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:bookmarkStart w:id="1" w:name="_Toc1"/>');
      has(doc, '<w:bookmarkEnd w:id="1"/>');
      has(doc, 'w:anchor="_Toc1"');
      has(doc, 'w:anchor="_Toc2"');
      has(doc, '>目录</w:t>');
      has(doc, '<w:br w:type="page"/>');
      const idxToc: number = doc.indexOf('w:anchor="_Toc1"');
      const idxBody: number = doc.indexOf('>正文A</w:t>');
      expect(idxToc >= 0 && idxBody > idxToc).assertTrue();
    });
    it('tocEmptyDocNoBlock', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.toc = true;
      o.tocTitle = '目录';
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('只有段落', o, new Map<string, Uint8Array>()));
      const doc: string = textOf(infos, 'word/document.xml');
      expect(countOf(doc, 'w:anchor=')).assertEqual(0);
      expect(countOf(doc, '<w:br w:type="page"/>')).assertEqual(0);
      expect(doc.indexOf('>目录</w:t>')).assertEqual(-1);
    });
    it('pageHeaderFooterParts', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.pageNumbers = true;
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith(SAMPLE, o, new Map<string, Uint8Array>()));
      const names: string[] = namesOf(infos);
      expect(names.indexOf('word/header1.xml') >= 0).assertTrue();
      expect(names.indexOf('word/footer1.xml') >= 0).assertTrue();
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<w:headerReference w:type="default" r:id="rId');
      has(doc, '<w:footerReference w:type="default" r:id="rId');
      const header: string = textOf(infos, 'word/header1.xml');
      has(header, '标题一');
      const footer: string = textOf(infos, 'word/footer1.xml');
      has(footer, 'w:instr=" PAGE "');
      has(footer, '<w:fldSimple');
      const ct: string = textOf(infos, '[Content_Types].xml');
      has(ct, '/word/header1.xml');
      has(ct, '/word/footer1.xml');
      const rels: string = textOf(infos, 'word/_rels/document.xml.rels');
      has(rels, 'Target="header1.xml"');
      has(rels, 'Target="footer1.xml"');
    });
    it('embedPngImage', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.embedImages = true;
      const imgs: Map<string, Uint8Array> = new Map<string, Uint8Array>();
      const px: Uint8Array = pngBytes(2, 3);
      imgs.set('img.png', px);
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('![甲](img.png)', o, imgs));
      const names: string[] = namesOf(infos);
      expect(names.indexOf('word/media/image1.png') >= 0).assertTrue();
      expect(bytesEqual(findEntry(infos, 'word/media/image1.png').data, px)).assertTrue();
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<wp:inline');
      has(doc, '<wp:extent cx="19050" cy="28575"/>');
      has(doc, 'r:embed="rId3"');
      const rels: string = textOf(infos, 'word/_rels/document.xml.rels');
      has(rels, 'Target="media/image1.png"');
      const ct: string = textOf(infos, '[Content_Types].xml');
      has(ct, '<Default Extension="png" ContentType="image/png"/>');
    });
    it('embedJpegImage', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.embedImages = true;
      const imgs: Map<string, Uint8Array> = new Map<string, Uint8Array>();
      imgs.set('pic.jpg', jpegBytes(4, 2));
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('![乙](pic.jpg)', o, imgs));
      const names: string[] = namesOf(infos);
      expect(names.indexOf('word/media/image1.jpg') >= 0).assertTrue();
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<wp:extent cx="38100" cy="19050"/>');
      const ct: string = textOf(infos, '[Content_Types].xml');
      has(ct, '<Default Extension="jpg" ContentType="image/jpeg"/>');
    });
    it('imageTooWideScaled', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.embedImages = true;
      const imgs: Map<string, Uint8Array> = new Map<string, Uint8Array>();
      imgs.set('wide.png', pngBytes(10000, 5000));
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('![宽](wide.png)', o, imgs));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '<wp:extent cx="5730000" cy="2865000"/>');
    });
    it('httpImageNotEmbedded', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.embedImages = true;
      const imgs: Map<string, Uint8Array> = new Map<string, Uint8Array>();
      imgs.set('https://a.example.com/x.png', pngBytes(1, 1));
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('![图](https://a.example.com/x.png)', o, imgs));
      const names: string[] = namesOf(infos);
      expect(names.length).assertEqual(6);
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '>[图](https://a.example.com/x.png)</w:t>');
      const ct: string = textOf(infos, '[Content_Types].xml');
      expect(ct.indexOf('image/png')).assertEqual(-1);
    });
    it('invalidBytesFallback', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.embedImages = true;
      const imgs: Map<string, Uint8Array> = new Map<string, Uint8Array>();
      imgs.set('bad.png', utf8Encode('not an image'));
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('![坏](bad.png)', o, imgs));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '>[坏](bad.png)</w:t>');
      expect(namesOf(infos).length).assertEqual(6);
    });
    it('embedImagesOffPlaceholder', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.embedImages = false;
      const imgs: Map<string, Uint8Array> = new Map<string, Uint8Array>();
      imgs.set('img.png', pngBytes(1, 1));
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('![甲](img.png)', o, imgs));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, '>[甲](img.png)</w:t>');
      expect(namesOf(infos).length).assertEqual(6);
    });
    it('imageDuplicateUrlSingleMedia', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.embedImages = true;
      const imgs: Map<string, Uint8Array> = new Map<string, Uint8Array>();
      imgs.set('x.png', pngBytes(1, 1));
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('![a](x.png)![b](x.png)', o, imgs));
      const rels: string = textOf(infos, 'word/_rels/document.xml.rels');
      expect(countOf(rels, 'Target="media/image1.png"')).assertEqual(1);
      expect(namesOf(infos).filter((n: string) => n.startsWith('word/media/')).length).assertEqual(1);
    });
    it('collectImageUrlsFilters', 0, () => {
      const urls: string[] = MdToDocx.collectImageUrls(
        '![a](x.png)![b](x.png)![c](https://e.com/y.png)![d](/abs/z.jpg)');
      expect(urls.length).assertEqual(2);
      expect(urls[0]).assertEqual('x.png');
      expect(urls[1]).assertEqual('/abs/z.jpg');
    });
    it('imageInTableCollected', 0, () => {
      const urls: string[] = MdToDocx.collectImageUrls('| h |\n| - |\n| ![c](cell.png) |');
      expect(urls.length).assertEqual(1);
      expect(urls[0]).assertEqual('cell.png');
    });
    it('tocAndHeadingNumbersCombined', 0, () => {
      const o: DocxOptions = defaultOpts();
      o.toc = true;
      o.tocTitle = '目录';
      o.headingNumbers = true;
      const infos: ZipInfo[] = readZip(MdToDocx.generateWith('# 一\n\n文\n\n## 二', o,
        new Map<string, Uint8Array>()));
      const doc: string = textOf(infos, 'word/document.xml');
      has(doc, 'w:anchor="_Toc1"');
      has(doc, '<w:bookmarkStart w:id="2" w:name="_Toc2"/>');
      const num: string = textOf(infos, 'word/numbering.xml');
      has(num, '<w:num w:numId="90">');
      const styles: string = textOf(infos, 'word/styles.xml');
      has(styles, '<w:numId w:val="90"/>');
    });
  });
}
