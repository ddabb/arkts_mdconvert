import {
  MdAlign,
  MdBlock,
  MdBold,
  MdCode,
  MdDoc,
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
  MdTableCell,
  MdText,
  MdThematicBreak
} from './MdModel';
import { MdInlineParser } from './MdInlineParser';
import { ZipWriter } from './ZipWriter';

export class MdToDocx {
  private static readonly XML_DECL: string = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  private static readonly W_NS: string = ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
  private static readonly R_NS: string = ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
  private static readonly REL_NS: string = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  private static readonly PKG_REL_NS: string = 'http://schemas.openxmlformats.org/package/2006/relationships';
  private static readonly CONTENT_TYPES: string = '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>' +
    '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>' +
    '</Types>';
  private static readonly ROOT_RELS: string = '<Relationships xmlns="' + MdToDocx.PKG_REL_NS + '">' +
    '<Relationship Id="rId1" Type="' + MdToDocx.REL_NS + '/officeDocument" Target="word/document.xml"/></Relationships>';
  private static readonly SECT_PR: string = '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>' +
    '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="851" w:footer="992" w:gutter="0"/>' +
    '<w:cols w:space="425"/><w:docGrid w:type="lines" w:linePitch="312"/></w:sectPr>';

  private nums: string[] = [];
  private nextNumId: number = 2;
  private hyperlinks: string[] = [];
  private urlToRid: Map<string, number> = new Map();
  private nextRid: number = 3;

  static generate(src: string): Uint8Array {
    return MdToDocx.generateDoc(MdInlineParser.parseFull(src));
  }

  static generateDoc(doc: MdDoc): Uint8Array {
    const gen: MdToDocx = new MdToDocx();
    const body: string = gen.blocks(doc.blocks, 0, false);
    const documentXml: string = MdToDocx.XML_DECL + '<w:document' + MdToDocx.W_NS + MdToDocx.R_NS + '><w:body>' +
      body + MdToDocx.SECT_PR + '</w:body></w:document>';
    const relsXml: string = '<Relationships xmlns="' + MdToDocx.PKG_REL_NS + '">' +
      '<Relationship Id="rId1" Type="' + MdToDocx.REL_NS + '/styles" Target="styles.xml"/>' +
      '<Relationship Id="rId2" Type="' + MdToDocx.REL_NS + '/numbering" Target="numbering.xml"/>' +
      gen.hyperlinks.join('') + '</Relationships>';
    const numberingXml: string = MdToDocx.XML_DECL + '<w:numbering' + MdToDocx.W_NS + '>' +
      MdToDocx.bulletAbstract() + MdToDocx.decimalAbstract() +
      '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>' + gen.nums.join('') + '</w:numbering>';
    const zip: ZipWriter = new ZipWriter();
    zip.add('[Content_Types].xml', MdToDocx.CONTENT_TYPES);
    zip.add('_rels/.rels', MdToDocx.ROOT_RELS);
    zip.add('word/document.xml', documentXml);
    zip.add('word/styles.xml', MdToDocx.stylesXml());
    zip.add('word/numbering.xml', numberingXml);
    zip.add('word/_rels/document.xml.rels', relsXml);
    return zip.bytes();
  }

  private blocks(list: MdBlock[], indLeft: number, inQuote: boolean): string {
    const sb: string[] = [];
    for (const b of list) {
      sb.push(this.block(b, indLeft, inQuote));
    }
    return sb.join('');
  }

  private block(b: MdBlock, indLeft: number, inQuote: boolean): string {
    if (b instanceof MdHeading) {
      return this.para(this.inline(b.inline, ''), 'Heading' + b.level, '', 0);
    }
    if (b instanceof MdPara) {
      return this.para(this.inline(b.inline, ''), inQuote ? 'MdcQuote' : '', '', indLeft);
    }
    if (b instanceof MdCode) {
      return this.codeBlock(b, indLeft);
    }
    if (b instanceof MdQuote) {
      return this.blocks(b.blocks, indLeft + 360, true);
    }
    if (b instanceof MdThematicBreak) {
      return this.para('', '', '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="BFBFBF"/></w:pBdr>', 0);
    }
    if (b instanceof MdList) {
      return this.list(b, 0, indLeft);
    }
    if (b instanceof MdTable) {
      return this.table(b, indLeft);
    }
    return '';
  }

  private para(runs: string, pStyle: string, extraPr: string, indLeft: number): string {
    let pPr: string = '';
    if (pStyle.length > 0) {
      pPr += '<w:pStyle w:val="' + pStyle + '"/>';
    }
    pPr += extraPr;
    if (indLeft > 0) {
      pPr += '<w:ind w:left="' + indLeft + '"/>';
    }
    const pr: string = pPr.length > 0 ? '<w:pPr>' + pPr + '</w:pPr>' : '';
    return '<w:p>' + pr + runs + '</w:p>';
  }

  private codeBlock(b: MdCode, indLeft: number): string {
    const lines: string[] = b.text.length == 0 ? [''] : b.text.split('\n');
    const sb: string[] = [];
    for (const line of lines) {
      sb.push(this.para(this.run('', line), 'MdcCode', '', indLeft + 240));
    }
    return sb.join('');
  }

  private list(l: MdList, depth: number, baseInd: number): string {
    let numId: number = 1;
    if (l.ordered) {
      numId = this.nextNumId;
      this.nextNumId += 1;
      this.nums.push('<w:num w:numId="' + numId + '"><w:abstractNumId w:val="1"/><w:lvlOverride w:ilvl="' + depth +
        '"><w:startOverride w:val="' + l.start + '"/></w:lvlOverride></w:num>');
    }
    const numPr: string = '<w:numPr><w:ilvl w:val="' + depth + '"/><w:numId w:val="' + numId + '"/></w:numPr>';
    const tightPr: string = l.tight ? '<w:spacing w:after="0"/>' : '';
    const contInd: number = baseInd + 720 * (depth + 1);
    const sb: string[] = [];
    for (const item of l.items) {
      let emitted: boolean = false;
      for (const b of item.blocks) {
        if (!emitted && b instanceof MdPara) {
          sb.push(this.para(this.inline(b.inline, ''), 'ListParagraph', numPr + tightPr, 0));
          emitted = true;
          continue;
        }
        if (!emitted) {
          sb.push(this.para('', 'ListParagraph', numPr + tightPr, 0));
          emitted = true;
        }
        if (b instanceof MdList) {
          sb.push(this.list(b, depth + 1, baseInd));
        } else {
          sb.push(this.block(b, contInd, false));
        }
      }
      if (!emitted) {
        sb.push(this.para('', 'ListParagraph', numPr + tightPr, 0));
      }
    }
    return sb.join('');
  }

  private table(t: MdTable, indLeft: number): string {
    const cols: number = t.aligns.length;
    if (cols == 0) {
      return '';
    }
    const colW: number = Math.floor(9026 / cols);
    const sb: string[] = [];
    sb.push('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/>' +
      '<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>');
    sb.push('<w:tblGrid>');
    for (let c: number = 0; c < cols; c += 1) {
      sb.push('<w:gridCol w:w="' + colW + '"/>');
    }
    sb.push('</w:tblGrid>');
    for (let r: number = 0; r < t.rows.length; r += 1) {
      const header: boolean = r == 0;
      sb.push('<w:tr>');
      if (header) {
        sb.push('<w:trPr><w:tblHeader/></w:trPr>');
      }
      const row: MdTableCell[] = t.rows[r];
      for (let c: number = 0; c < cols; c += 1) {
        const cell: MdTableCell = c < row.length ? row[c] : new MdTableCell([]);
        const shd: string = header ? '<w:shd w:val="clear" w:color="auto" w:fill="EDF2F8"/>' : '';
        sb.push('<w:tc><w:tcPr><w:tcW w:w="' + colW + '" w:type="dxa"/>' + shd +
          '<w:vAlign w:val="center"/></w:tcPr>');
        const jc: string = MdToDocx.alignJc(t.aligns[c]);
        const runs: string = header ? this.inline(cell.inline, '<w:b/>') : this.inline(cell.inline, '');
        sb.push('<w:p><w:pPr><w:spacing w:after="0"/>' + jc + '</w:pPr>' + runs + '</w:p>');
        sb.push('</w:tc>');
      }
      sb.push('</w:tr>');
    }
    sb.push('</w:tbl>');
    sb.push(this.para('', '', '', 0));
    return sb.join('');
  }

  private inline(nodes: MdInline[], rPr: string): string {
    const sb: string[] = [];
    for (const node of nodes) {
      sb.push(this.inlineOne(node, rPr));
    }
    return sb.join('');
  }

  private inlineOne(node: MdInline, rPr: string): string {
    if (node instanceof MdText) {
      return this.run(rPr, node.text);
    }
    if (node instanceof MdInlineCode) {
      return this.run(rPr +
        '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/><w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>',
        node.text);
    }
    if (node instanceof MdBold) {
      return this.inline(node.inline, rPr + '<w:b/><w:bCs/>');
    }
    if (node instanceof MdItalic) {
      return this.inline(node.inline, rPr + '<w:i/><w:iCs/>');
    }
    if (node instanceof MdStrike) {
      return this.inline(node.inline, rPr + '<w:strike/>');
    }
    if (node instanceof MdLink) {
      const rid: number = this.ridFor(node.url);
      return '<w:hyperlink r:id="rId' + rid + '">' +
        this.inline(node.inline, rPr + '<w:color w:val="0563C1"/><w:u w:val="single"/>') + '</w:hyperlink>';
    }
    if (node instanceof MdImage) {
      return this.run(rPr, '[' + node.alt + '](' + node.url + ')');
    }
    return '';
  }

  private run(rPr: string, text: string): string {
    const flat: string = text.split('\n').join(' ');
    if (flat.length == 0) {
      return '';
    }
    const pr: string = rPr.length > 0 ? '<w:rPr>' + rPr + '</w:rPr>' : '';
    return '<w:r>' + pr + '<w:t xml:space="preserve">' + MdToDocx.esc(flat) + '</w:t></w:r>';
  }

  private ridFor(url: string): number {
    const hit: number | undefined = this.urlToRid.get(url);
    if (hit !== undefined) {
      return hit;
    }
    const rid: number = this.nextRid;
    this.nextRid += 1;
    this.urlToRid.set(url, rid);
    this.hyperlinks.push('<Relationship Id="rId' + rid + '" Type="' + MdToDocx.REL_NS + '/hyperlink" Target="' +
      MdToDocx.escAttr(url) + '" TargetMode="External"/>');
    return rid;
  }

  static esc(s: string): string {
    let out: string = '';
    for (let i: number = 0; i < s.length; i += 1) {
      const c: string = s.charAt(i);
      const code: number = s.charCodeAt(i);
      if (c == '<') {
        out += '&lt;';
      } else if (c == '&') {
        out += '&amp;';
      } else if (c == '>') {
        out += '&gt;';
      } else if (code < 32 && code != 9 && code != 10 && code != 13) {
        out += '�';
      } else {
        out += c;
      }
    }
    return out;
  }

  static escAttr(s: string): string {
    let out: string = '';
    for (let i: number = 0; i < s.length; i += 1) {
      const c: string = s.charAt(i);
      const code: number = s.charCodeAt(i);
      if (c == '<') {
        out += '&lt;';
      } else if (c == '&') {
        out += '&amp;';
      } else if (c == '>') {
        out += '&gt;';
      } else if (c == '"') {
        out += '&quot;';
      } else if (code == 10) {
        out += '&#10;';
      } else if (code == 13) {
        out += '&#13;';
      } else if (code == 9) {
        out += '&#9;';
      } else if (code < 32) {
        out += '�';
      } else {
        out += c;
      }
    }
    return out;
  }

  static alignJc(a: MdAlign): string {
    if (a == MdAlign.Left) {
      return '<w:jc w:val="left"/>';
    }
    if (a == MdAlign.Center) {
      return '<w:jc w:val="center"/>';
    }
    if (a == MdAlign.Right) {
      return '<w:jc w:val="right"/>';
    }
    return '';
  }

  private static bulletAbstract(): string {
    const chars: string[] = ['\u2022', '\u25E6', '\u25AA', '\u2022', '\u25E6', '\u25AA'];
    const sb: string[] = [];
    sb.push('<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>');
    for (let i: number = 0; i < 6; i += 1) {
      sb.push('<w:lvl w:ilvl="' + i + '"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="' +
        chars[i] + '"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="' + (720 * (i + 1)) +
        '" w:hanging="360"/></w:pPr></w:lvl>');
    }
    sb.push('</w:abstractNum>');
    return sb.join('');
  }

  private static decimalAbstract(): string {
    const fmts: string[] = ['decimal', 'lowerLetter', 'lowerRoman', 'decimal', 'lowerLetter', 'lowerRoman'];
    const sb: string[] = [];
    sb.push('<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>');
    for (let i: number = 0; i < 6; i += 1) {
      sb.push('<w:lvl w:ilvl="' + i + '"><w:start w:val="1"/><w:numFmt w:val="' + fmts[i] + '"/><w:lvlText w:val="%' +
        (i + 1) + '."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="' + (720 * (i + 1)) +
        '" w:hanging="360"/></w:pPr></w:lvl>');
    }
    sb.push('</w:abstractNum>');
    return sb.join('');
  }

  private static headingStyle(level: number): string {
    const sizes: number[] = [36, 30, 26, 24, 22, 22];
    const colors: string[] = ['2E74B5', '2E74B5', '2E74B5', '2E74B5', '595959', '595959'];
    return '<w:style w:type="paragraph" w:styleId="Heading' + level + '"><w:name w:val="heading ' + level +
      '"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>' +
      '<w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="240" w:after="60"/><w:outlineLvl w:val="' +
      (level - 1) + '"/></w:pPr><w:rPr><w:b/><w:bCs/><w:color w:val="' + colors[level - 1] +
      '"/><w:sz w:val="' + sizes[level - 1] + '"/><w:szCs w:val="' + sizes[level - 1] + '"/></w:rPr></w:style>';
  }

  private static stylesXml(): string {
    const sb: string[] = [];
    sb.push(MdToDocx.XML_DECL);
    sb.push('<w:styles' + MdToDocx.W_NS + '>');
    sb.push('<w:docDefaults><w:rPrDefault><w:rPr>' +
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="DengXian" w:cs="Calibri"/>' +
      '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US" w:eastAsia="zh-CN"/></w:rPr></w:rPrDefault>' +
      '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>');
    sb.push('<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>');
    for (let i: number = 1; i <= 6; i += 1) {
      sb.push(MdToDocx.headingStyle(i));
    }
    sb.push('<w:style w:type="paragraph" w:styleId="MdcCode"><w:name w:val="Mdc Code"/><w:basedOn w:val="Normal"/>' +
      '<w:pPr><w:shd w:val="clear" w:color="auto" w:fill="F5F5F5"/><w:spacing w:after="0" w:line="276" w:lineRule="auto"/>' +
      '<w:ind w:left="240"/></w:pPr><w:rPr>' +
      '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:eastAsia="NSimSun" w:cs="Consolas"/>' +
      '<w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>');
    sb.push('<w:style w:type="paragraph" w:styleId="MdcQuote"><w:name w:val="Mdc Quote"/><w:basedOn w:val="Normal"/>' +
      '<w:qFormat/><w:pPr><w:spacing w:after="60"/></w:pPr><w:rPr><w:i/><w:iCs/><w:color w:val="595959"/></w:rPr></w:style>');
    sb.push('<w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/>' +
      '<w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:contextualSpacing/></w:pPr></w:style>');
    sb.push('<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders>' +
      '<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>' +
      '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>' +
      '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>' +
      '</w:tblBorders></w:tblPr></w:style>');
    sb.push('</w:styles>');
    return sb.join('');
  }
}
