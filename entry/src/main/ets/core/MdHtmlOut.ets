import {
  MdBold,
  MdBlock,
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
  MdListItem,
  MdPara,
  MdQuote,
  MdStrike,
  MdTable,
  MdTableCell,
  MdText,
  MdThematicBreak,
  MdAlign
} from './MdModel';
import { MdInlineParser } from './MdInlineParser';

export class MdToHtml {
  static readonly CSS: string = [
    'body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,"PingFang SC",'
    + '"Hiragino Sans GB","Microsoft YaHei",sans-serif;line-height:1.75;max-width:820px;'
    + 'margin:0 auto;padding:24px 16px;color:#1F2937;background:#F8FAFC}',
    'h1,h2,h3,h4,h5,h6{line-height:1.35;margin:1.4em 0 .6em}',
    'h1,h2{border-bottom:2px solid #E2E8F0;padding-bottom:8px}',
    'p{margin:.7em 0}',
    'code{background:#EEF2F7;border-radius:4px;padding:2px 5px;font-family:ui-monospace,'
    + 'Consolas,"Courier New",monospace;font-size:.9em}',
    'pre{background:#0F172A;color:#E2E8F0;padding:14px;border-radius:10px;'
    + 'overflow-x:auto;margin:1em 0}',
    'pre code{background:transparent;color:inherit;padding:0;font-size:.88em}',
    'table{border-collapse:collapse;width:100%;margin:1em 0}',
    'th,td{border:1px solid #CBD5E1;padding:8px 10px}',
    'th{background:#EDF2F8}',
    'blockquote{border-left:4px solid #93C5FD;margin:1em 0;padding:6px 16px;'
    + 'background:#EFF6FF;color:#475569;border-radius:0 8px 8px 0}',
    'img{max-width:100%}',
    'hr{border:none;border-top:1px solid #CBD5E1;margin:1.5em 0}',
    'li{margin:.3em 0}',
    'a{color:#0284C7}'
  ].join('\n');

  static html(src: string, title: string): string {
    const doc: MdDoc = MdInlineParser.parseFull(src);
    const sb: string[] = [];
    sb.push('<!DOCTYPE html>');
    sb.push('<html lang="zh-CN">');
    sb.push('<head>');
    sb.push('<meta charset="utf-8">');
    sb.push('<meta name="viewport" content="width=device-width,initial-scale=1">');
    sb.push('<title>' + MdToHtml.esc(MdToHtml.titleOf(title, doc)) + '</title>');
    sb.push('<style>');
    sb.push(MdToHtml.CSS);
    sb.push('</style>');
    sb.push('</head>');
    sb.push('<body>');
    MdToHtml.blocks(doc.blocks, sb);
    sb.push('</body>');
    sb.push('</html>');
    return sb.join('\n');
  }

  static titleOf(title: string, doc: MdDoc): string {
    if (title.trim().length > 0) {
      return title.trim();
    }
    for (const block of doc.blocks) {
      if (block instanceof MdHeading) {
        const parts: string[] = [];
        MdToHtml.plainText(block.inline, parts);
        const t: string = parts.join('').trim();
        if (t.length > 0) {
          return t;
        }
      }
    }
    return 'MdConvert';
  }

  static esc(s: string): string {
    let out: string = '';
    for (let i: number = 0; i < s.length; i += 1) {
      const c: string = s.charAt(i);
      if (c == '&') {
        out += '&amp;';
      } else if (c == '<') {
        out += '&lt;';
      } else if (c == '>') {
        out += '&gt;';
      } else if (c == '"') {
        out += '&quot;';
      } else if (c == '\'') {
        out += '&#39;';
      } else {
        out += c;
      }
    }
    return out;
  }

  static blocks(blocks: MdBlock[], sb: string[]): void {
    for (const block of blocks) {
      MdToHtml.block(block, sb);
    }
  }

  static block(block: MdBlock, sb: string[]): void {
    if (block instanceof MdHeading) {
      const tag: string = 'h' + block.level.toString();
      sb.push('<' + tag + '>' + MdToHtml.inlineHtml(block.inline) + '</' + tag + '>');
      return;
    }
    if (block instanceof MdPara) {
      sb.push('<p>' + MdToHtml.inlineHtml(block.inline) + '</p>');
      return;
    }
    if (block instanceof MdCode) {
      const cls: string = block.lang.length > 0 ?
        ' class="language-' + MdToHtml.esc(block.lang) + '"' : '';
      sb.push('<pre><code' + cls + '>' + MdToHtml.esc(block.text) + '</code></pre>');
      return;
    }
    if (block instanceof MdQuote) {
      sb.push('<blockquote>');
      MdToHtml.blocks(block.blocks, sb);
      sb.push('</blockquote>');
      return;
    }
    if (block instanceof MdThematicBreak) {
      sb.push('<hr>');
      return;
    }
    if (block instanceof MdList) {
      MdToHtml.listHtml(block, sb);
      return;
    }
    if (block instanceof MdTable) {
      MdToHtml.tableHtml(block, sb);
      return;
    }
  }

  static listHtml(list: MdList, sb: string[]): void {
    if (list.ordered) {
      const start: string = list.start != 1 ? ' start="' + list.start.toString() + '"' : '';
      sb.push('<ol' + start + '>');
      for (const item of list.items) {
        MdToHtml.itemHtml(item, sb);
      }
      sb.push('</ol>');
    } else {
      sb.push('<ul>');
      for (const item of list.items) {
        MdToHtml.itemHtml(item, sb);
      }
      sb.push('</ul>');
    }
  }

  static itemHtml(item: MdListItem, sb: string[]): void {
    let prefix: string = '';
    if (item.checked >= 0) {
      prefix = '<input type="checkbox" disabled'
        + (item.checked == 1 ? ' checked' : '') + '> ';
    }
    if (item.blocks.length == 1 && item.blocks[0] instanceof MdPara) {
      const para: MdPara = item.blocks[0];
      sb.push('<li>' + prefix + MdToHtml.inlineHtml(para.inline) + '</li>');
      return;
    }
    if (item.blocks.length == 0) {
      sb.push('<li>' + prefix + '</li>');
      return;
    }
    sb.push('<li>');
    const inner: string[] = [];
    MdToHtml.blocks(item.blocks, inner);
    sb.push(prefix + inner.join('\n'));
    sb.push('</li>');
  }

  static tableHtml(table: MdTable, sb: string[]): void {
    sb.push('<table>');
    if (table.rows.length > 0) {
      sb.push('<thead>');
      sb.push('<tr>');
      for (let c: number = 0; c < table.rows[0].length; c += 1) {
        sb.push('<th' + MdToHtml.alignStyle(table.aligns, c) + '>'
          + MdToHtml.inlineHtml(table.rows[0][c].inline) + '</th>');
      }
      sb.push('</tr>');
      sb.push('</thead>');
    }
    if (table.rows.length > 1) {
      sb.push('<tbody>');
      for (let r: number = 1; r < table.rows.length; r += 1) {
        sb.push('<tr>');
        for (let c: number = 0; c < table.rows[r].length; c += 1) {
          sb.push('<td' + MdToHtml.alignStyle(table.aligns, c) + '>'
            + MdToHtml.inlineHtml(table.rows[r][c].inline) + '</td>');
        }
        sb.push('</tr>');
      }
      sb.push('</tbody>');
    }
    sb.push('</table>');
  }

  static alignStyle(aligns: MdAlign[], col: number): string {
    if (col >= aligns.length) {
      return '';
    }
    const a: MdAlign = aligns[col];
    if (a == MdAlign.Center) {
      return ' style="text-align:center"';
    }
    if (a == MdAlign.Right) {
      return ' style="text-align:right"';
    }
    if (a == MdAlign.Left) {
      return ' style="text-align:left"';
    }
    return '';
  }

  static inlineHtml(inlines: MdInline[]): string {
    const sb: string[] = [];
    MdToHtml.inlineInto(inlines, sb);
    return sb.join('');
  }

  static inlineInto(inlines: MdInline[], sb: string[]): void {
    for (const node of inlines) {
      if (node instanceof MdText) {
        sb.push(MdToHtml.esc(node.text));
      } else if (node instanceof MdInlineCode) {
        sb.push('<code>' + MdToHtml.esc(node.text) + '</code>');
      } else if (node instanceof MdBold) {
        sb.push('<strong>');
        MdToHtml.inlineInto(node.inline, sb);
        sb.push('</strong>');
      } else if (node instanceof MdItalic) {
        sb.push('<em>');
        MdToHtml.inlineInto(node.inline, sb);
        sb.push('</em>');
      } else if (node instanceof MdStrike) {
        sb.push('<del>');
        MdToHtml.inlineInto(node.inline, sb);
        sb.push('</del>');
      } else if (node instanceof MdLink) {
        sb.push('<a href="' + MdToHtml.esc(node.url) + '">');
        MdToHtml.inlineInto(node.inline, sb);
        sb.push('</a>');
      } else if (node instanceof MdImage) {
        sb.push('<img src="' + MdToHtml.esc(node.url) + '" alt="' + MdToHtml.esc(node.alt) + '">');
      } else if (node instanceof MdBreak) {
        sb.push('<br>');
      }
    }
  }

  static plainText(inlines: MdInline[], parts: string[]): void {
    for (const node of inlines) {
      if (node instanceof MdText) {
        parts.push(node.text);
      } else if (node instanceof MdInlineCode) {
        parts.push(node.text);
      } else if (node instanceof MdBold) {
        MdToHtml.plainText(node.inline, parts);
      } else if (node instanceof MdItalic) {
        MdToHtml.plainText(node.inline, parts);
      } else if (node instanceof MdStrike) {
        MdToHtml.plainText(node.inline, parts);
      } else if (node instanceof MdLink) {
        MdToHtml.plainText(node.inline, parts);
      } else if (node instanceof MdImage) {
        parts.push(node.alt);
      } else if (node instanceof MdBreak) {
        parts.push(' ');
      }
    }
  }
}
