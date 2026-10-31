import { describe, it, expect } from '@ohos/hypium';
import { MdToXmind } from '../../../main/ets/core/XmindOut';
import { MindNode, MindTreeBuilder } from '../../../main/ets/core/MindmapTree';
import { MindTheme } from '../../../main/ets/core/MindmapTheme';

class ZipInfo {
  name: string = '';
  data: Uint8Array = new Uint8Array(0);
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
    info.lho = dv.getUint32(pos + 42, true);
    info.name = decodeUtf8(bytes.subarray(pos + 46, pos + 46 + nameLen));
    const lNameLen: number = dv.getUint16(info.lho + 26, true);
    const lExtraLen: number = dv.getUint16(info.lho + 28, true);
    const csize: number = dv.getUint32(pos + 20, true);
    const start: number = info.lho + 30 + lNameLen + lExtraLen;
    info.data = bytes.subarray(start, start + csize);
    out.push(info);
    pos += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

function textOf(infos: ZipInfo[], name: string): string {
  for (const e of infos) {
    if (e.name == name) {
      return decodeUtf8(e.data);
    }
  }
  expect(false).assertTrue();
  return '';
}

function has(s: string, sub: string): void {
  expect(s.indexOf(sub) >= 0).assertTrue();
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

const SRC: string = '# 根\n\n## 甲\n\n- 一\n- 二\n\n## 乙\n\n- 三';

export default function mdXmindTest() {
  describe('mdXmindTest', () => {
    it('xmindZipStructure', 0, () => {
      const bytes: Uint8Array = MdToXmind.xmind(SRC);
      const infos: ZipInfo[] = readZip(bytes);
      expect(infos.length).assertEqual(3);
      expect(infos[0].name).assertEqual('content.json');
      expect(infos[1].name).assertEqual('metadata.json');
      expect(infos[2].name).assertEqual('manifest.json');
      const dv: DataView = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      for (const e of infos) {
        expect(dv.getUint16(e.lho + 6, true) & 0x0800).assertEqual(0x0800);
      }
    });
    it('contentJsonRootAndKids', 0, () => {
      const infos: ZipInfo[] = readZip(MdToXmind.xmind(SRC));
      const content: string = textOf(infos, 'content.json');
      has(content, '"class":"sheet"');
      has(content, '"rootTopic":{');
      has(content, '"title":"根"');
      has(content, '"children":{"attached":[');
      has(content, '"title":"甲"');
      has(content, '"title":"一"');
      has(content, '"title":"三"');
    });
    it('structureClassOnRootOnly', 0, () => {
      const infos: ZipInfo[] = readZip(MdToXmind.xmind(SRC));
      const content: string = textOf(infos, 'content.json');
      expect(countOf(content, '"structureClass"')).assertEqual(1);
      has(content, '"structureClass":"org.xmind.ui.logic.right"');
    });
    it('topicIdsUnique', 0, () => {
      const infos: ZipInfo[] = readZip(MdToXmind.xmind(SRC));
      const content: string = textOf(infos, 'content.json');
      for (let i: number = 1; i <= 6; i += 1) {
        expect(countOf(content, `"id":"t${i}"`)).assertEqual(1);
      }
      expect(countOf(content, '"class":"topic"')).assertEqual(6);
    });
    it('leafChildrenOmitted', 0, () => {
      const infos: ZipInfo[] = readZip(MdToXmind.xmind(SRC));
      const content: string = textOf(infos, 'content.json');
      expect(countOf(content, '"children"')).assertEqual(3);
    });
    it('metadataCreator', 0, () => {
      const infos: ZipInfo[] = readZip(MdToXmind.xmind(SRC));
      const meta: string = textOf(infos, 'metadata.json');
      has(meta, '"creator"');
      has(meta, '"name":"MdConvert"');
      has(meta, '"version":"1.0.2"');
    });
    it('manifestFileEntries', 0, () => {
      const infos: ZipInfo[] = readZip(MdToXmind.xmind(SRC));
      const manifest: string = textOf(infos, 'manifest.json');
      has(manifest, '"file-entries"');
      has(manifest, '"content.json":{}');
      has(manifest, '"metadata.json":{}');
    });
    it('escJsonSpecials', 0, () => {
      const infos: ZipInfo[] = readZip(MdToXmind.xmind('# 引\n\n- 他说"你好"\n- 反斜\\\\杠'));
      const content: string = textOf(infos, 'content.json');
      has(content, '他说\\"你好\\"');
      has(content, '反斜\\\\杠');
    });
    it('escJsonControlChars', 0, () => {
      const escaped: string = MdToXmind.escJson('a\u0001b\nc');
      expect(escaped).assertEqual('a\\u0001b\\nc');
    });
    it('assignPathsScheme', 0, () => {
      const tree: MindNode = MindTreeBuilder.buildSrc(SRC, 12);
      MindTreeBuilder.assignPaths(tree);
      expect(tree.path).assertEqual('0');
      expect(tree.children[0].path).assertEqual('0.0');
      expect(tree.children[0].children[0].path).assertEqual('0.0.0');
      expect(tree.children[0].children[1].path).assertEqual('0.0.1');
      expect(tree.children[1].path).assertEqual('0.1');
      expect(tree.children[1].children[0].path).assertEqual('0.1.0');
    });
    it('pruneFoldCounts', 0, () => {
      const tree: MindNode = MindTreeBuilder.buildSrc(SRC, 12);
      MindTreeBuilder.assignPaths(tree);
      const collapsed: Set<string> = new Set<string>();
      collapsed.add('0.0');
      const pruned: MindNode = MindTreeBuilder.prune(tree, collapsed);
      expect(pruned.children.length).assertEqual(2);
      expect(pruned.children[0].folded).assertEqual(2);
      expect(pruned.children[0].children.length).assertEqual(0);
      expect(pruned.children[1].children.length).assertEqual(1);
      expect(pruned.children[1].children[0].text).assertEqual('三');
    });
    it('pruneOriginalUntouched', 0, () => {
      const tree: MindNode = MindTreeBuilder.buildSrc(SRC, 12);
      MindTreeBuilder.assignPaths(tree);
      const collapsed: Set<string> = new Set<string>();
      collapsed.add('0.0');
      const pruned: MindNode = MindTreeBuilder.prune(tree, collapsed);
      expect(pruned.children[0].children.length).assertEqual(0);
      expect(tree.children[0].children.length).assertEqual(2);
      expect(pruned.children[0] === tree.children[0]).assertFalse();
    });
    it('pruneEmptySetEquivalent', 0, () => {
      const tree: MindNode = MindTreeBuilder.buildSrc(SRC, 12);
      MindTreeBuilder.assignPaths(tree);
      const pruned: MindNode = MindTreeBuilder.prune(tree, new Set<string>());
      expect(MindTreeBuilder.descendantCount(pruned)).assertEqual(MindTreeBuilder.descendantCount(tree));
      expect(pruned.children[0].folded).assertEqual(0);
    });
    it('themePrintRegistered', 0, () => {
      const themes: MindTheme[] = MindTheme.all();
      expect(themes.length).assertEqual(4);
      expect(themes[3].key).assertEqual('print');
      expect(themes[3].bg).assertEqual('#FFFFFF');
    });
  });
}
