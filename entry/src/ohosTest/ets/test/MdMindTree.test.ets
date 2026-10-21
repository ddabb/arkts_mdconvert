import { describe, it, expect } from '@ohos/hypium';
import { MindNode, MindTreeBuilder } from '../../../main/ets/core/MindmapTree';

function build(src: string, maxChildren: number): MindNode {
  return MindTreeBuilder.buildSrc(src, maxChildren);
}

function assertTexts(node: MindNode, expected: string[]): void {
  expect(node.children.length).assertEqual(expected.length);
  for (let i: number = 0; i < expected.length; i += 1) {
    expect(node.children[i].text).assertEqual(expected[i]);
  }
}

export default function mdMindTreeTest() {
  describe('mdMindTreeTest', () => {
    it('emptyDocFallsBackToRootPlaceholder', 0, () => {
      const root: MindNode = build('', 0);
      expect(root.text).assertEqual('文档大纲');
      expect(root.children.length).assertEqual(0);
    });
    it('singleH1BecomesRoot', 0, () => {
      const root: MindNode = build('# 标题甲\n\n内容段', 0);
      expect(root.text).assertEqual('标题甲');
      assertTexts(root, ['内容段']);
    });
    it('multiH1FallsBack', 0, () => {
      const root: MindNode = build('# 甲\n\n甲内容\n\n# 乙\n\n乙内容', 0);
      expect(root.text).assertEqual('文档大纲');
      assertTexts(root, ['甲', '乙']);
      assertTexts(root.children[0], ['甲内容']);
      assertTexts(root.children[1], ['乙内容']);
    });
    it('h2OnlyFallsBack', 0, () => {
      const root: MindNode = build('## 小节\n\n段落', 0);
      expect(root.text).assertEqual('文档大纲');
      assertTexts(root, ['小节']);
      assertTexts(root.children[0], ['段落']);
    });
    it('paraWithoutHeading', 0, () => {
      const root: MindNode = build('无标题段落', 0);
      expect(root.text).assertEqual('文档大纲');
      assertTexts(root, ['无标题段落']);
    });
    it('inlineTextStripsUrl', 0, () => {
      const root: MindNode = build('点击 [链接](https://x.example.com/a) 与 **粗体** 结束', 0);
      assertTexts(root, ['点击 链接 与 粗体 结束']);
    });
    it('firstLineOnly', 0, () => {
      const root: MindNode = build('第一行\n第二行', 0);
      assertTexts(root, ['第一行']);
    });
    it('nestedList', 0, () => {
      const root: MindNode = build('- 甲\n  - 乙\n    - 丙', 0);
      assertTexts(root, ['甲']);
      assertTexts(root.children[0], ['乙']);
      assertTexts(root.children[0].children[0], ['丙']);
    });
    it('codeLabel', 0, () => {
      const root: MindNode = build('```ts\nlet a = 1;\nlet b = 2;\n```', 0);
      assertTexts(root, ['[ts] let a = 1;']);
    });
    it('codeEmptyBody', 0, () => {
      const root: MindNode = build('```py\n```', 0);
      assertTexts(root, ['[py]']);
    });
    it('tableRows', 0, () => {
      const root: MindNode = build('| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |', 0);
      assertTexts(root, ['表格：A | B']);
      assertTexts(root.children[0], ['1 | 2', '3 | 4']);
    });
    it('quoteFlattened', 0, () => {
      const root: MindNode = build('> 引用一\n> 继续引用', 0);
      assertTexts(root, ['引用一']);
    });
    it('quoteListFlattened', 0, () => {
      const root: MindNode = build('> - 甲\n> - 乙', 0);
      assertTexts(root, ['甲', '乙']);
    });
    it('hrSkipped', 0, () => {
      const root: MindNode = build('---', 0);
      expect(root.children.length).assertEqual(0);
    });
    it('collapseOver12', 0, () => {
      const lines: string[] = [];
      for (let i: number = 0; i < 15; i += 1) {
        lines.push(`P${i}`);
        lines.push('');
      }
      const root: MindNode = build(lines.join('\n'), 12);
      expect(root.children.length).assertEqual(12);
      expect(root.children[10].text).assertEqual('P10');
      expect(root.children[11].text).assertEqual('…还有 4 项');
    });
    it('noCollapseWhenZero', 0, () => {
      const lines: string[] = [];
      for (let i: number = 0; i < 15; i += 1) {
        lines.push(`P${i}`);
        lines.push('');
      }
      const root: MindNode = build(lines.join('\n'), 0);
      expect(root.children.length).assertEqual(15);
    });
    it('itemFallbackLabel', 0, () => {
      const root: MindNode = build('- \n  - 乙\n- 甲', 0);
      assertTexts(root, ['条目', '甲']);
      assertTexts(root.children[0], ['乙']);
    });
    it('looseItemFollowUpParaBecomesChild', 0, () => {
      const root: MindNode = build('- 甲\n\n  补充段\n\n- 乙', 0);
      assertTexts(root, ['甲', '乙']);
      assertTexts(root.children[0], ['补充段']);
    });
  });
}
