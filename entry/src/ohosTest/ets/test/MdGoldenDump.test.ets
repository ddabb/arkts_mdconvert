import { describe, it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo } from '@kit.CoreFileKit';
import { MdToJson } from '../../../main/ets/core/MdJsonOut';
import { MdToYaml } from '../../../main/ets/core/MdYamlOut';

const GOLDEN_LINES: string[] = [
  '# MdConvert 对账样本',
  '',
  '前言段落，含 **粗体**、*斜体*、~~删除~~、`行内码`、[链接](https://example.com/a)。',
  '',
  '## 列表',
  '',
  '- 无序一',
  '- 无序二',
  '  1. 有序嵌套',
  '  2. 第二项',
  '',
  '## 代码',
  '',
  '```ts',
  'const s: string = "hello";',
  'console.log(s);',
  '```',
  '',
  '## 表格',
  '',
  '| 名称 | 数量 | 备注 |',
  '| --- | :-- | --: |',
  '| 甲 | 1 | 左 |',
  '| 乙 | 2 | 右 |',
  '',
  '> 引用一段',
  '> 继续引用',
  '',
  '---',
  '',
  '尾段 [外部](https://example.com/(x)) ![图](img.png)。',
  ''
];

export default function mdGoldenDumpTest() {
  describe('mdGoldenDumpTest', () => {
    it('dumpGoldenOutputs', 0, () => {
      const md: string = GOLDEN_LINES.join('\n');
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const dir: string = delegator.getAppContext().filesDir;
      hilog.info(0x0000, 'mdcDump', '%{public}s', 'MDC_DUMP_DIR:' + dir);
      const write = (name: string, content: string): void => {
        const file = fileIo.openSync(dir + '/' + name,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, content);
        fileIo.closeSync(file);
      };
      write('mdc_source.md', md);
      write('mdc_flat.json', MdToJson.flat(md));
      write('mdc_tree.json', MdToJson.tree(md));
      write('mdc_flat.yaml', MdToYaml.flat(md));
      write('mdc_tree.yaml', MdToYaml.tree(md));
      expect(true).assertTrue();
    });
  });
}
