import { describe, it, expect } from '@ohos/hypium';
import { MdToDocx } from '../../../main/ets/core/DocxOut';
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
  });
}
