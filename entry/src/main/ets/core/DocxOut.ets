import {
  MdAlign,
  MdBlock,
  MdBold,
  MdBreak,
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
  MdThematicBreak,
  collectInlineText,
  collectMdText
} from './MdModel';
import { MdInlineParser } from './MdInlineParser';
import { ZipWriter } from './ZipWriter';

export class DocxOptions {
  firstLineIndent: boolean = false;
  headingNumbers: boolean = false;
  toc: boolean = false;
  tocTitle: string = '';
  pageNumbers: boolean = false;
  embedImages: boolean = false;
}

class ImageSize {
  w: number = 0;
  h: number = 0;
}

class EmbedImage {
  bytes: Uint8Array = new Uint8Array(0);
  ext: string = '';
  w: number = 0;
  h: number = 0;
  rid: number = 0;
  mediaName: string = '';
  docId: number = 0;
}

export class MdToDocx {
  private static readonly XML_DECL: string = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  private static readonly W_NS: string = ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
  private static readonly R_NS: string = ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
  private static readonly REL_NS: string = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  private static readonly PKG_REL_NS: string = 'http://schemas.openxmlformats.org/package/2006/relationships';
  private static readonly CT_NS: string = 'http://schemas.openxmlformats.org/package/2006/content-types';
  private static readonly WP_NS: string = ' xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"';
  private static readonly A_NS: string = ' xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"';
  private static readonly PIC_NS: string = ' xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"';
  private static readonly PICTURE_URI: string = 'http://schemas.openxmlformats.org/drawingml/2006/picture';
  private static readonly EMU_PER_PX: number = 9525;
  private static readonly MAX_IMG_EMU: number = 5730000;

  private opts: DocxOptions = new DocxOptions();
  private images: Map<string, Uint8Array> = new Map();
  private imgCache: Map<string, EmbedImage> = new Map();
  private mediaRels: string[] = [];
  private mediaList: EmbedImage[] = [];
  private hasPng: boolean = false;
  private hasJpg: boolean = false;
  private hasCjk: boolean = false;
  private bookmarks: Map<MdHeading, number> = new Map();
  private tocTexts: string[] = [];
  private tocLevels: number[] = [];
  private nums: string[] = [];
  private nextNumId: number = 2;
  private hyperlinks: string[] = [];
  private urlToRid: Map<string, number> = new Map();
  private nextRid: number = 3;

  static generate(src: string): Uint8Array {
    return MdToDocx.build(MdInlineParser.parseFull(src), new DocxOptions(), new Map());
  }

  static generateWith(src: string, opts: DocxOptions, images: Map<string, Uint8Array>): Uint8Array {
    return MdToDocx.build(MdInlineParser.parseFull(src), opts, images);
  }

  static generateDoc(doc: MdDoc): Uint8Array {
    return MdToDocx.build(doc, new DocxOptions(), new Map());
  }

  static collectImageUrls(src: string): string[] {
    const urls: string[] = [];
    MdToDocx.gatherImageUrls(MdInlineParser.parseFull(src).blocks, urls);
    const seen: Set<string> = new Set();
    const out: string[] = [];
    for (const u of urls) {
      if (MdToDocx.isHttpUrl(u) || seen.has(u)) {
        continue;
      }
      seen.add(u);
      out.push(u);
    }
    return out;
  }

  private static gatherImageUrls(blocks: MdBlock[], out: string[]): void {
    for (const b of blocks) {
      if (b instanceof MdHeading) {
        MdToDocx.gatherFromInline(b.inline, out);
      } else if (b instanceof MdPara) {
        MdToDocx.gatherFromInline(b.inline, out);
      } else if (b instanceof MdQuote) {
        MdToDocx.gatherImageUrls(b.blocks, out);
      } else if (b instanceof MdList) {
        for (const item of b.items) {
          MdToDocx.gatherImageUrls(item.blocks, out);
        }
      } else if (b instanceof MdTable) {
        for (const row of b.rows) {
          for (const cell of row) {
            MdToDocx.gatherFromInline(cell.inline, out);
          }
        }
      }
    }
  }

  private static gatherFromInline(nodes: MdInline[], out: string[]): void {
    for (const n of nodes) {
      if (n instanceof MdImage) {
        out.push(n.url);
      } else if (n instanceof MdBold) {
        MdToDocx.gatherFromInline(n.inline, out);
      } else if (n instanceof MdItalic) {
        MdToDocx.gatherFromInline(n.inline, out);
      } else if (n instanceof MdStrike) {
        MdToDocx.gatherFromInline(n.inline, out);
      } else if (n instanceof MdLink) {
        MdToDocx.gatherFromInline(n.inline, out);
      }
    }
  }

  private static build(doc: MdDoc, opts: DocxOptions, images: Map<string, Uint8Array>): Uint8Array {
    const gen: MdToDocx = new MdToDocx();
    gen.opts = opts;
    gen.images = images;
    if (opts.firstLineIndent) {
      gen.hasCjk = MdToDocx.containsCjk(collectMdText(doc));
    }
    if (opts.toc) {
      gen.collectToc(doc);
    }
    let body: string = gen.blocks(doc.blocks, 0, false);
    if (opts.toc && gen.tocTexts.length > 0) {
      body = gen.tocBlock() + body;
    }
    let headerRid: number = 0;
    let footerRid: number = 0;
    let headerXml: string = '';
    let footerXml: string = '';
    if (opts.pageNumbers) {
      headerRid = gen.nextRid;
      gen.nextRid += 1;
      footerRid = gen.nextRid;
      gen.nextRid += 1;
      headerXml = MdToDocx.headerXml(MdToDocx.firstHeadingText(doc));
      footerXml = MdToDocx.footerXml();
    }
    const documentXml: string = MdToDocx.XML_DECL + '<w:document' + MdToDocx.W_NS + MdToDocx.R_NS + '><w:body>' +
      body + MdToDocx.sectPr(headerRid, footerRid) + '</w:body></w:document>';
    const relsSb: string[] = ['<Relationships xmlns="' + MdToDocx.PKG_REL_NS + '">' +
      '<Relationship Id="rId1" Type="' + MdToDocx.REL_NS + '/styles" Target="styles.xml"/>' +
      '<Relationship Id="rId2" Type="' + MdToDocx.REL_NS + '/numbering" Target="numbering.xml"/>'];
    relsSb.push(...gen.hyperlinks);
    relsSb.push(...gen.mediaRels);
    if (headerRid > 0) {
      relsSb.push('<Relationship Id="rId' + headerRid + '" Type="' + MdToDocx.REL_NS + '/header" Target="header1.xml"/>');
    }
    if (footerRid > 0) {
      relsSb.push('<Relationship Id="rId' + footerRid + '" Type="' + MdToDocx.REL_NS + '/footer" Target="footer1.xml"/>');
    }
    relsSb.push('</Relationships>');
    const numSb: string[] = [MdToDocx.XML_DECL, '<w:numbering' + MdToDocx.W_NS + '>'];
    numSb.push(MdToDocx.bulletAbstract());
    numSb.push(MdToDocx.decimalAbstract());
    if (opts.headingNumbers) {
      numSb.push(MdToDocx.headingAbstract());
    }
    numSb.push('<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>');
    numSb.push(...gen.nums);
    numSb.push('</w:numbering>');
    const zip: ZipWriter = new ZipWriter();
    zip.add('[Content_Types].xml', MdToDocx.contentTypes(gen.hasPng, gen.hasJpg, headerRid > 0));
    zip.add('_rels/.rels', '<Relationships xmlns="' + MdToDocx.PKG_REL_NS + '">' +
      '<Relationship Id="rId1" Type="' + MdToDocx.REL_NS + '/officeDocument" Target="word/document.xml"/></Relationships>');
    zip.add('word/document.xml', documentXml);
    zip.add('word/styles.xml', MdToDocx.stylesXml(opts.headingNumbers));
    zip.add('word/numbering.xml', numSb.join(''));
    zip.add('word/_rels/document.xml.rels', relsSb.join(''));
    if (headerRid > 0) {
      zip.add('word/header1.xml', headerXml);
    }
    if (footerRid > 0) {
      zip.add('word/footer1.xml', footerXml);
    }
    for (const img of gen.mediaList) {
      zip.addBytes('word/media/' + img.mediaName, img.bytes);
    }
    return zip.bytes();
  }

  private static contentTypes(hasPng: boolean, hasJpg: boolean, hasHeaderFooter: boolean): string {
    const sb: string[] = ['<Types xmlns="' + MdToDocx.CT_NS + '">' +
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
      '<Default Extension="xml" ContentType="application/xml"/>'];
    if (hasPng) {
      sb.push('<Default Extension="png" ContentType="image/png"/>');
    }
    if (hasJpg) {
      sb.push('<Default Extension="jpg" ContentType="image/jpeg"/>');
    }
    sb.push('<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>');
    sb.push('<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>');
    sb.push('<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>');
    if (hasHeaderFooter) {
      sb.push('<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>');
      sb.push('<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>');
    }
    sb.push('</Types>');
    return sb.join('');
  }

  private static sectPr(headerRid: number, footerRid: number): string {
    const sb: string[] = ['<w:sectPr>'];
    if (headerRid > 0) {
      sb.push('<w:headerReference w:type="default" r:id="rId' + headerRid + '"/>');
    }
    if (footerRid > 0) {
      sb.push('<w:footerReference w:type="default" r:id="rId' + footerRid + '"/>');
    }
    sb.push('<w:pgSz w:w="11906" w:h="16838"/>');
    sb.push('<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="851" w:footer="992" w:gutter="0"/>');
    sb.push('<w:cols w:space="425"/><w:docGrid w:type="lines" w:linePitch="312"/>');
    sb.push('</w:sectPr>');
    return sb.join('');
  }

  private static headerXml(text: string): string {
    const p: string = text.length > 0 ?
      '<w:p><w:pPr><w:spacing w:after="0"/><w:jc w:val="center"/>' +
      '<w:pBdr><w:bottom w:val="single" w:sz="4" w:space="1" w:color="D9D9D9"/></w:pBdr></w:pPr>' +
      '<w:r><w:rPr><w:color w:val="808080"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>' +
      '<w:t xml:space="preserve">' + MdToDocx.esc(text) + '</w:t></w:r></w:p>' : '<w:p/>';
    return MdToDocx.XML_DECL + '<w:hdr' + MdToDocx.W_NS + MdToDocx.R_NS + '>' + p + '</w:hdr>';
  }

  private static footerXml(): string {
    return MdToDocx.XML_DECL + '<w:ftr' + MdToDocx.W_NS + MdToDocx.R_NS + '>' +
      '<w:p><w:pPr><w:spacing w:after="0"/><w:jc w:val="center"/></w:pPr>' +
      '<w:fldSimple w:instr=" PAGE "><w:r><w:rPr><w:color w:val="808080"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>' +
      '<w:t>1</w:t></w:r></w:fldSimple></w:p></w:ftr>';
  }

  private static firstHeadingText(doc: MdDoc): string {
    for (const b of doc.blocks) {
      if (b instanceof MdHeading) {
        const parts: string[] = [];
        collectInlineText(b.inline, parts);
        return parts.join('').substring(0, 60);
      }
    }
    return '';
  }

  private static containsCjk(s: string): boolean {
    for (let i: number = 0; i < s.length; i += 1) {
      const c: number = s.charCodeAt(i);
      if ((c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF) || (c >= 0xF900 && c <= 0xFAFF) ||
        (c >= 0x3040 && c <= 0x30FF) || (c >= 0xAC00 && c <= 0xD7AF)) {
        return true;
      }
    }
    return false;
  }

  private static isHttpUrl(url: string): boolean {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  private static pngSize(b: Uint8Array): ImageSize | undefined {
    if (b.length < 24 || b[0] != 0x89 || b[1] != 0x50 || b[2] != 0x4E || b[3] != 0x47 ||
      b[4] != 0x0D || b[5] != 0x0A || b[6] != 0x1A || b[7] != 0x0A) {
      return undefined;
    }
    if (b[12] != 0x49 || b[13] != 0x48 || b[14] != 0x44 || b[15] != 0x52) {
      return undefined;
    }
    const dv: DataView = new DataView(b.buffer, b.byteOffset, b.byteLength);
    const s: ImageSize = new ImageSize();
    s.w = dv.getUint32(16);
    s.h = dv.getUint32(20);
    return s;
  }

  private static jpegSize(b: Uint8Array): ImageSize | undefined {
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) {
      return undefined;
    }
    const dv: DataView = new DataView(b.buffer, b.byteOffset, b.byteLength);
    let pos: number = 2;
    while (pos + 9 < b.length) {
      if (b[pos] != 0xFF) {
        return undefined;
      }
      const m: number = b[pos + 1];
      if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
        pos += 2;
        continue;
      }
      if (m == 0xDA) {
        return undefined;
      }
      const len: number = dv.getUint16(pos + 2);
      if (m == 0xC0 || m == 0xC1 || m == 0xC2 || m == 0xC3 || m == 0xC5 || m == 0xC6 ||
        m == 0xC7 || m == 0xC9 || m == 0xCA || m == 0xCB || m == 0xCD || m == 0xCE || m == 0xCF) {
        const s: ImageSize = new ImageSize();
        s.h = dv.getUint16(pos + 5);
        s.w = dv.getUint16(pos + 7);
        return s;
      }
      if (len < 2) {
        return undefined;
      }
      pos += 2 + len;
    }
    return undefined;
  }

  private collectToc(doc: MdDoc): void {
    for (const b of doc.blocks) {
      if (b instanceof MdHeading) {
        const idx: number = this.tocTexts.length + 1;
        const parts: string[] = [];
        collectInlineText(b.inline, parts);
        this.tocTexts.push(parts.join(''));
        this.tocLevels.push(b.level);
        this.bookmarks.set(b, idx);
      }
    }
  }

  private tocBlock(): string {
    const sb: string[] = [];
    if (this.opts.tocTitle.length > 0) {
      sb.push('<w:p><w:pPr><w:spacing w:before="240" w:after="240"/><w:jc w:val="center"/></w:pPr>' +
        '<w:r><w:rPr><w:b/><w:bCs/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr>' +
        '<w:t xml:space="preserve">' + MdToDocx.esc(this.opts.tocTitle) + '</w:t></w:r></w:p>');
    }
    for (let i: number = 0; i < this.tocTexts.length; i += 1) {
      const lv: number = this.tocLevels[i];
      const ind: string = lv > 1 ? '<w:ind w:left="' + ((lv - 1) * 240) + '"/>' : '';
      sb.push('<w:p><w:pPr><w:spacing w:after="40"/>' + ind + '</w:pPr>' +
        '<w:hyperlink w:anchor="_Toc' + (i + 1) + '" w:history="1">' +
        '<w:r><w:rPr><w:color w:val="333333"/></w:rPr>' +
        '<w:t xml:space="preserve">' + MdToDocx.esc(this.tocTexts[i]) + '</w:t></w:r></w:hyperlink></w:p>');
    }
    sb.push('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
    return sb.join('');
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
      let runs: string = this.inline(b.inline, '');
      if (this.opts.toc) {
        const bm: number | undefined = this.bookmarks.get(b);
        if (bm !== undefined) {
          runs = '<w:bookmarkStart w:id="' + bm + '" w:name="_Toc' + bm + '"/>' + runs +
            '<w:bookmarkEnd w:id="' + bm + '"/>';
        }
      }
      return this.para(runs, 'Heading' + b.level, '', 0, false);
    }
    if (b instanceof MdPara) {
      const firstLine: boolean = !inQuote && indLeft == 0 && this.opts.firstLineIndent && this.hasCjk;
      return this.para(this.inline(b.inline, ''), inQuote ? 'MdcQuote' : '', '', indLeft, firstLine);
    }
    if (b instanceof MdCode) {
      return this.codeBlock(b, indLeft);
    }
    if (b instanceof MdQuote) {
      return this.blocks(b.blocks, indLeft + 360, true);
    }
    if (b instanceof MdThematicBreak) {
      return this.para('', '', '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="BFBFBF"/></w:pBdr>', 0, false);
    }
    if (b instanceof MdList) {
      return this.list(b, 0, indLeft);
    }
    if (b instanceof MdTable) {
      return this.table(b, indLeft);
    }
    return '';
  }

  private para(runs: string, pStyle: string, extraPr: string, indLeft: number, firstLine: boolean): string {
    let pPr: string = '';
    if (pStyle.length > 0) {
      pPr += '<w:pStyle w:val="' + pStyle + '"/>';
    }
    pPr += extraPr;
    let ind: string = '';
    if (indLeft > 0) {
      ind += ' w:left="' + indLeft + '"';
    }
    if (firstLine) {
      ind += ' w:firstLineChars="200"';
    }
    if (ind.length > 0) {
      pPr += '<w:ind' + ind + '/>';
    }
    const pr: string = pPr.length > 0 ? '<w:pPr>' + pPr + '</w:pPr>' : '';
    return '<w:p>' + pr + runs + '</w:p>';
  }

  private codeBlock(b: MdCode, indLeft: number): string {
    const lines: string[] = b.text.length == 0 ? [''] : b.text.split('\n');
    const sb: string[] = [];
    for (const line of lines) {
      sb.push(this.para(this.run('', line), 'MdcCode', '', indLeft + 240, false));
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
      const task: boolean = item.checked >= 0;
      const itemPr: string = task ? tightPr : numPr + tightPr;
      const prefix: string = task ? (item.checked == 1 ? '\u2611 ' : '\u2610 ') : '';
      let emitted: boolean = false;
      for (const b of item.blocks) {
        if (!emitted && b instanceof MdPara) {
          sb.push(this.para(prefix + this.inline(b.inline, ''), 'ListParagraph', itemPr, 0, false));
          emitted = true;
          continue;
        }
        if (!emitted) {
          sb.push(this.para(this.run('', prefix), 'ListParagraph', itemPr, 0, false));
          emitted = true;
        }
        if (b instanceof MdList) {
          sb.push(this.list(b, depth + 1, baseInd));
        } else {
          sb.push(this.block(b, contInd, false));
        }
      }
      if (!emitted) {
        sb.push(this.para(this.run('', prefix), 'ListParagraph', itemPr, 0, false));
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
    sb.push(this.para('', '', '', 0, false));
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
      if (this.opts.embedImages && !MdToDocx.isHttpUrl(node.url)) {
        const img: EmbedImage | undefined = this.imageFor(node.url);
        if (img !== undefined && img.w > 0) {
          return this.drawing(img);
        }
      }
      return this.run(rPr, '[' + node.alt + '](' + node.url + ')');
    }
    if (node instanceof MdBreak) {
      return '<w:r>' + (rPr.length > 0 ? '<w:rPr>' + rPr + '</w:rPr>' : '') + '<w:br/></w:r>';
    }
    return '';
  }

  private imageFor(url: string): EmbedImage | undefined {
    const hit: EmbedImage | undefined = this.imgCache.get(url);
    if (hit !== undefined) {
      return hit;
    }
    let img: EmbedImage | undefined = undefined;
    const bytes: Uint8Array | undefined = this.images.get(url);
    if (bytes !== undefined && bytes.length > 0) {
      let size: ImageSize | undefined = MdToDocx.pngSize(bytes);
      let ext: string = 'png';
      if (size === undefined) {
        size = MdToDocx.jpegSize(bytes);
        ext = 'jpg';
      }
      if (size !== undefined && size.w > 0 && size.h > 0) {
        const e: EmbedImage = new EmbedImage();
        e.bytes = bytes;
        e.ext = ext;
        e.w = size.w;
        e.h = size.h;
        e.docId = this.mediaList.length + 1;
        e.mediaName = 'image' + e.docId + '.' + ext;
        e.rid = this.nextRid;
        this.nextRid += 1;
        this.mediaRels.push('<Relationship Id="rId' + e.rid + '" Type="' + MdToDocx.REL_NS +
          '/image" Target="media/' + e.mediaName + '"/>');
        this.mediaList.push(e);
        this.imgCache.set(url, e);
        if (ext == 'png') {
          this.hasPng = true;
        } else {
          this.hasJpg = true;
        }
        img = e;
      }
    }
    if (img === undefined) {
      const bad: EmbedImage = new EmbedImage();
      this.imgCache.set(url, bad);
      return bad;
    }
    return img;
  }

  private drawing(img: EmbedImage): string {
    let cx: number = img.w * MdToDocx.EMU_PER_PX;
    let cy: number = img.h * MdToDocx.EMU_PER_PX;
    if (cx > MdToDocx.MAX_IMG_EMU) {
      cy = Math.round(cy * MdToDocx.MAX_IMG_EMU / cx);
      cx = MdToDocx.MAX_IMG_EMU;
    }
    return '<w:r><w:drawing><wp:inline' + MdToDocx.WP_NS + ' distT="0" distB="0" distL="0" distR="0">' +
      '<wp:extent cx="' + cx + '" cy="' + cy + '"/>' +
      '<wp:effectExtent l="0" t="0" r="0" b="0"/>' +
      '<wp:docPr id="' + img.docId + '" name="Image ' + img.docId + '"/>' +
      '<wp:cNvGraphicFramePr><a:graphicFrameLocks' + MdToDocx.A_NS + ' noChangeAspect="1"/></wp:cNvGraphicFramePr>' +
      '<a:graphic' + MdToDocx.A_NS + '><a:graphicData uri="' + MdToDocx.PICTURE_URI + '">' +
      '<pic:pic' + MdToDocx.PIC_NS + '>' +
      '<pic:nvPicPr><pic:cNvPr id="' + img.docId + '" name="' + img.mediaName + '"/>' +
      '<pic:cNvPicPr><a:picLocks noChangeAspect="1"/></pic:cNvPicPr></pic:nvPicPr>' +
      '<pic:blipFill><a:blip r:embed="rId' + img.rid + '"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>' +
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="' + cx + '" cy="' + cy + '"/></a:xfrm>' +
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>' +
      '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
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
        out += '\uFFFD';
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
        out += '\uFFFD';
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

  private static headingAbstract(): string {
    const sb: string[] = [];
    sb.push('<w:abstractNum w:abstractNumId="2"><w:multiLevelType w:val="multilevel"/>');
    for (let i: number = 0; i < 6; i += 1) {
      let txt: string = '%1';
      for (let k: number = 2; k <= i + 1; k += 1) {
        txt += '.%' + k;
      }
      txt += '.';
      sb.push('<w:lvl w:ilvl="' + i + '"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="' + txt +
        '"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="0" w:firstLine="0"/></w:pPr></w:lvl>');
    }
    sb.push('</w:abstractNum>');
    sb.push('<w:num w:numId="90"><w:abstractNumId w:val="2"/></w:num>');
    return sb.join('');
  }

  private static headingStyle(level: number, numbered: boolean): string {
    const sizes: number[] = [36, 30, 26, 24, 22, 22];
    const colors: string[] = ['2E74B5', '2E74B5', '2E74B5', '2E74B5', '595959', '595959'];
    const numPr: string = numbered ?
      '<w:numPr><w:ilvl w:val="' + (level - 1) + '"/><w:numId w:val="90"/></w:numPr>' : '';
    return '<w:style w:type="paragraph" w:styleId="Heading' + level + '"><w:name w:val="heading ' + level +
      '"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>' +
      '<w:pPr>' + numPr + '<w:keepNext/><w:keepLines/><w:spacing w:before="240" w:after="60"/><w:outlineLvl w:val="' +
      (level - 1) + '"/></w:pPr><w:rPr><w:b/><w:bCs/><w:color w:val="' + colors[level - 1] +
      '"/><w:sz w:val="' + sizes[level - 1] + '"/><w:szCs w:val="' + sizes[level - 1] + '"/></w:rPr></w:style>';
  }

  private static stylesXml(headingNumbers: boolean): string {
    const sb: string[] = [];
    sb.push(MdToDocx.XML_DECL);
    sb.push('<w:styles' + MdToDocx.W_NS + '>');
    sb.push('<w:docDefaults><w:rPrDefault><w:rPr>' +
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="DengXian" w:cs="Calibri"/>' +
      '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US" w:eastAsia="zh-CN"/></w:rPr></w:rPrDefault>' +
      '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>');
    sb.push('<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>');
    for (let i: number = 1; i <= 6; i += 1) {
      sb.push(MdToDocx.headingStyle(i, headingNumbers));
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
