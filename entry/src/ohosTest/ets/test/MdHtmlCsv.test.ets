import { describe, it, expect } from '@ohos/hypium';
import { util } from '@kit.ArkTS';
import { MdToHtml } from '../../../main/ets/core/MdHtmlOut';
import { MdToCsv } from '../../../main/ets/core/MdCsvOut';

function has(s: string, sub: string): void {
  expect(s.indexOf(sub) >= 0).assertTrue();
}

export default function mdHtmlCsvTest() {
  describe('mdHtmlCsvTest', () => {
    it('htmlStructureSelfContained', 0, () => {
      const html: string = MdToHtml.html('# 标题\n\n正文', '我的文档');
      expect(html.startsWith('<!DOCTYPE html>')).assertTrue();
      has(html, '<html lang="zh-CN">');
      has(html, '<meta charset="utf-8">');
      has(html, '<meta name="viewport" content="width=device-width,initial-scale=1">');
      has(html, '<title>我的文档</title>');
      has(html, '<style>');
      has(html, '</head>');
      has(html, '<body>');
      has(html, '</body>');
      expect(html.endsWith('</html>')).assertTrue();
    });

    it('htmlTitleFromHeadingAndEscaped', 0, () => {
      const html: string = MdToHtml.html('# 首章 <主线>\n\n正文', '');
      has(html, '<title>首章 &lt;主线&gt;</title>');
      has(html, '<h1>首章 &lt;主线&gt;</h1>');
    });

    it('htmlEscapesText', 0, () => {
      const html: string = MdToHtml.html('文本 <div> 与 & 符号 "引号"', '');
      has(html, '文本 &lt;div&gt; 与 &amp; 符号 &quot;引号&quot;');
      expect(html.indexOf('<div>')).assertEqual(-1);
    });

    it('htmlBlockProbes', 0, () => {
      const md: string = [
        '# 大标题',
        '',
        '段落一。',
        '',
        '> 引用内容',
        '',
        '---',
        '',
        '```ts',
        'const a = 1;',
        '```',
        '',
        '| 表头 | 数值 |',
        '| --- | --- |',
        '| 甲 | 1 |',
        ''
      ].join('\n');
      const html: string = MdToHtml.html(md, '');
      has(html, '<h1>大标题</h1>');
      has(html, '<p>段落一。</p>');
      has(html, '<blockquote>');
      has(html, '引用内容');
      has(html, '<hr>');
      has(html, '<pre><code class="language-ts">const a = 1;</code></pre>');
      has(html, '<table>');
      has(html, '<thead>');
      has(html, '<tr>');
      has(html, '<th>表头</th>');
      has(html, '<th>数值</th>');
      has(html, '</thead>');
      has(html, '<tbody>');
      has(html, '<td>甲</td>');
      has(html, '<td>1</td>');
      has(html, '</tbody>');
      has(html, '</table>');
    });

    it('htmlInlineProbes', 0, () => {
      const md: string = '**粗** *斜* ~~删~~ `码` [链](https://a.b/c) ![图](i.png) 甲<br>乙';
      const html: string = MdToHtml.html(md, '');
      has(html, '<strong>粗</strong>');
      has(html, '<em>斜</em>');
      has(html, '<del>删</del>');
      has(html, '<code>码</code>');
      has(html, '<a href="https://a.b/c">链</a>');
      has(html, '<img src="i.png" alt="图">');
      has(html, '甲<br>乙');
    });

    it('htmlTaskCheckbox', 0, () => {
      const md: string = '- [x] 完成\n- [ ] 未完';
      const html: string = MdToHtml.html(md, '');
      has(html, '<input type="checkbox" disabled checked> 完成');
      has(html, '<input type="checkbox" disabled> 未完');
    });

    it('htmlTableAlign', 0, () => {
      const md: string = [
        '| L | C | R | N |',
        '| :-- | :-: | --: | --- |',
        '| a | b | c | d |',
        ''
      ].join('\n');
      const html: string = MdToHtml.html(md, '');
      has(html, '<th style="text-align:left">L</th>');
      has(html, '<th style="text-align:center">C</th>');
      has(html, '<th style="text-align:right">R</th>');
      has(html, '<th>N</th>');
      has(html, '<td style="text-align:center">b</td>');
    });

    it('htmlNestedListLooseContinues', 0, () => {
      const md: string = [
        '1. 一',
        '2. 二',
        '   - 嵌套',
        '',
        '3. 从三开始',
        ''
      ].join('\n');
      const html: string = MdToHtml.html(md, '');
      has(html, '<ol>');
      has(html, '<li>一</li>');
      has(html, '<p>二</p>');
      has(html, '<ul>');
      has(html, '<li>嵌套</li>');
      has(html, '</ul>');
      has(html, '<li>从三开始</li>');
      has(html, '</ol>');
      expect(html.indexOf('<ol start=')).assertEqual(-1);
      const md2: string = '3. 丙\n4. 丁\n';
      has(MdToHtml.html(md2, ''), '<ol start="3">');
      has(MdToHtml.html(md2, ''), '<li>丙</li>');
    });

    it('csvBomAndTextConsistent', 0, () => {
      const md: string = '| 名称 | 备注 |\n| --- | --- |\n| 甲 | 含,逗号 |\n| 乙 | 引"号 |';
      const text: string = MdToCsv.csvText(md);
      const bytes: Uint8Array = MdToCsv.csvBytes(md);
      expect(bytes[0]).assertEqual(0xEF);
      expect(bytes[1]).assertEqual(0xBB);
      expect(bytes[2]).assertEqual(0xBF);
      const body: string = util.TextDecoder.create('utf-8')
        .decodeToString(bytes.subarray(3));
      expect(body == text).assertTrue();
    });

    it('csvQuoteAndCrlf', 0, () => {
      const md: string = '| 名称 | 备注 |\n| --- | --- |\n| 甲 | 含,逗号 |\n| 乙 | 引"号 |';
      const text: string = MdToCsv.csvText(md);
      expect(text).assertEqual('名称,备注\r\n甲,"含,逗号"\r\n乙,"引""号"');
    });

    it('csvNewlineInCellQuoted', 0, () => {
      const md: string = '| 项 | 说明 |\n| --- | --- |\n| x | 甲<br>乙 |';
      const text: string = MdToCsv.csvText(md);
      expect(text).assertEqual('项,说明\r\nx,"甲\n乙"');
    });

    it('csvInlineFlattened', 0, () => {
      const md: string = '| 项 |\n| --- |\n| **粗**和`码` |';
      expect(MdToCsv.csvText(md)).assertEqual('项\r\n粗和码');
    });

    it('csvMultiTableBlankLine', 0, () => {
      const md: string = '| A |\n| --- |\n| 1 |\n\n段落\n\n| B |\n| --- |\n| 2 |';
      expect(MdToCsv.csvText(md)).assertEqual('A\r\n1\r\n\r\nB\r\n2');
    });

    it('csvNoTableEmpty', 0, () => {
      expect(MdToCsv.csvText('- 列表\n\n段落')).assertEqual('');
      expect(MdToCsv.csvBytes('- 列表').length).assertEqual(3);
    });
  });
}
