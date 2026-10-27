import { describe, it, expect } from '@ohos/hypium';
import {
  HistoryRecord,
  HistoryStore,
  HISTORY_MAX
} from '../../../main/ets/core/HistoryStore';
import {
  buildOutline,
  OutlineItem,
  OUTLINE_MAX
} from '../../../main/ets/core/OutlineOut';
import { MdInlineParser } from '../../../main/ets/core/MdInlineParser';

function rec(id: number, fileName: string, fmt: string, content: string): HistoryRecord {
  return HistoryStore.record(fileName, fmt, 'tree', content, id);
}

export default function mdHistoryTest() {
  describe('mdHistoryTest', () => {
    it('recordFields', 0, () => {
      const r: HistoryRecord = HistoryStore.record('notes.md', 'json', 'flat', '# 标题', 1000);
      expect(r.id).assertEqual(1000);
      expect(r.time).assertEqual(1000);
      expect(r.chars).assertEqual(4);
      expect(r.fmt).assertEqual('json');
      expect(r.mode).assertEqual('flat');
      expect(r.fileName).assertEqual('notes.md');
      expect(r.content).assertEqual('# 标题');
    });

    it('encodeDecodeRoundtrip', 0, () => {
      const src: string = '# 甲\n\n- 项目\n  - 嵌套\n\n```ts\nlet a = 1;\n```\n\n' +
        '[链接](https://x.example.com/a?b=1&c=2) emoji 😀 \u001f 分隔符 % 百分号';
      const records: HistoryRecord[] = [
        rec(100, '笔记.md', 'json', src),
        rec(200, '', 'docx', 'plain'),
        rec(300, 'readme.markdown', 'mm', '')
      ];
      const decoded: HistoryRecord[] = HistoryStore.decode(HistoryStore.encode(records));
      expect(decoded.length).assertEqual(3);
      expect(decoded[0].content).assertEqual(src);
      expect(decoded[0].fileName).assertEqual('笔记.md');
      expect(decoded[0].fmt).assertEqual('json');
      expect(decoded[1].fileName).assertEqual('');
      expect(decoded[1].fmt).assertEqual('docx');
      expect(decoded[2].content).assertEqual('');
      expect(decoded[2].id).assertEqual(300);
    });

    it('decodeSkipsMalformedLines', 0, () => {
      const good: HistoryRecord = rec(1, 'a.md', 'json', 'x');
      const text: string = HistoryStore.encode([good]) +
        '\nbad-line-without-separators\n\u001f\u001f';
      const decoded: HistoryRecord[] = HistoryStore.decode(text);
      expect(decoded.length).assertEqual(1);
      expect(decoded[0].fileName).assertEqual('a.md');
    });

    it('encodeDecodeEmpty', 0, () => {
      expect(HistoryStore.encode([])).assertEqual('');
      expect(HistoryStore.decode('').length).assertEqual(0);
    });

    it('capKeepsNewestHead', 0, () => {
      const records: HistoryRecord[] = [];
      for (let i: number = 0; i < 25; i += 1) {
        records.push(rec(i, `f${i}.md`, 'json', 'c'));
      }
      const capped: HistoryRecord[] = HistoryStore.cap(records, HISTORY_MAX);
      expect(capped.length).assertEqual(HISTORY_MAX);
      expect(capped[0].fileName).assertEqual('f0.md');
      expect(capped[capped.length - 1].fileName).assertEqual('f19.md');
      expect(HistoryStore.cap(records, 0).length).assertEqual(0);
      expect(HistoryStore.cap(records, -1).length).assertEqual(0);
      expect(HistoryStore.cap(records.slice(0, 5), 20).length).assertEqual(5);
    });

    it('outlineHeadingDepthAndPara', 0, () => {
      const items: OutlineItem[] = buildOutline(MdInlineParser.parseFull(
        '# 一级\n\n段落内容\n\n## 二级\n\n正文'));
      expect(items.length).assertEqual(4);
      expect(items[0].depth).assertEqual(0);
      expect(items[0].text).assertEqual('一级');
      expect(items[0].strong).assertTrue();
      expect(items[1].text).assertEqual('段落内容');
      expect(items[1].depth).assertEqual(1);
      expect(items[1].strong).assertFalse();
      expect(items[2].depth).assertEqual(1);
      expect(items[2].text).assertEqual('二级');
      expect(items[3].text).assertEqual('正文');
      expect(items[3].depth).assertEqual(2);
    });

    it('outlineListNestedAndOrdered', 0, () => {
      const items: OutlineItem[] = buildOutline(MdInlineParser.parseFull(
        '- 甲\n  - 乙\n    - 丙\n\n1. 第一\n2. 第二'));
      expect(items.length).assertEqual(5);
      expect(items[0].text).assertEqual('• 甲');
      expect(items[0].depth).assertEqual(0);
      expect(items[1].text).assertEqual('• 乙');
      expect(items[1].depth).assertEqual(1);
      expect(items[2].text).assertEqual('• 丙');
      expect(items[2].depth).assertEqual(2);
      expect(items[3].text).assertEqual('1. 第一');
      expect(items[4].text).assertEqual('2. 第二');
    });

    it('outlineCodeQuoteTableHr', 0, () => {
      const items: OutlineItem[] = buildOutline(MdInlineParser.parseFull(
        '```ts\nlet a = 1;\nlet b = 2;\n```\n\n> 引用第一行\n\n' +
        '| 甲 | 乙 |\n| --- | --- |\n| 1 | 2 |\n\n---\n\n结尾段'));
      expect(items.length).assertEqual(4);
      expect(items[0].text).assertEqual('[ts] let a = 1;');
      expect(items[1].text).assertEqual('引用第一行');
      expect(items[2].text.indexOf('表格 2×2：甲 · 乙')).assertEqual(0);
      expect(items[3].text).assertEqual('结尾段');
    });

    it('outlineInlineStripped', 0, () => {
      const items: OutlineItem[] = buildOutline(MdInlineParser.parseFull(
        '点击 [链接](https://x.example.com/a) 与 **粗体** `代码` ![图](img.png) 结束'));
      expect(items.length).assertEqual(1);
      expect(items[0].text).assertEqual('点击 链接 与 粗体 代码 图 结束');
    });

    it('outlineTruncatesLongText', 0, () => {
      const longLine: string = '字'.repeat(100);
      const items: OutlineItem[] = buildOutline(MdInlineParser.parseFull(longLine));
      expect(items.length).assertEqual(1);
      expect(items[0].text.length).assertEqual(61);
      expect(items[0].text.charAt(60)).assertEqual('…');
    });

    it('outlineEmptyDoc', 0, () => {
      expect(buildOutline(MdInlineParser.parseFull('')).length).assertEqual(0);
      expect(buildOutline(MdInlineParser.parseFull('---')).length).assertEqual(0);
    });

    it('outlineCap', 0, () => {
      const parts: string[] = [];
      for (let i: number = 0; i < OUTLINE_MAX + 50; i += 1) {
        parts.push(`# 标题${i}`);
        parts.push('');
      }
      const items: OutlineItem[] = buildOutline(MdInlineParser.parseFull(parts.join('\n')));
      expect(items.length).assertEqual(OUTLINE_MAX);
    });
  });
}
