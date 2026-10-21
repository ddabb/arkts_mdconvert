import { describe, it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MindTheme } from '../../../main/ets/core/MindmapTheme';
import { MindRenderResult, PngRender } from '../../../main/ets/core/PngRender';

function perfDoc(): string {
  const lines: string[] = ['# 性能样本'];
  for (let b: number = 0; b < 5; b++) {
    lines.push('', `## 分支${b}`);
    for (let m: number = 0; m < 5; m++) {
      lines.push('', `### 组${b}_${m}`);
      for (let i: number = 0; i < 4; i++) {
        lines.push('', `#### 层${b}_${m}_${i}`);
        for (let j: number = 0; j < 4; j++) {
          lines.push('', `##### 叶${b}_${m}_${i}_${j}`);
        }
      }
    }
  }
  return lines.join('\n');
}

function tallDoc(): string {
  const lines: string[] = ['# 四K上限'];
  for (let b: number = 0; b < 30; b++) {
    lines.push('', `## 分支${b}`);
    for (let i: number = 0; i < 20; i++) {
      lines.push('', `### 叶${b}_${i}`);
    }
  }
  return lines.join('\n');
}

export default function mdPngRenderTest() {
  describe('mdPngRenderTest', () => {
    it('renderPngMagic', 0, async () => {
      const bytes: Uint8Array = await PngRender.renderBytes('# 标\n\n- 甲\n- 乙\n',
        MindTheme.fresh(), 12);
      expect(bytes.length > 8).assertTrue();
      expect(bytes[0]).assertEqual(0x89);
      expect(bytes[1]).assertEqual(0x50);
      expect(bytes[2]).assertEqual(0x4E);
      expect(bytes[3]).assertEqual(0x47);
      expect(bytes[4]).assertEqual(0x0D);
      expect(bytes[5]).assertEqual(0x0A);
      expect(bytes[6]).assertEqual(0x1A);
      expect(bytes[7]).assertEqual(0x0A);
    });

    it('ihdrDimsMatch', 0, async () => {
      const result: MindRenderResult = await PngRender.render('# 尺寸\n\n- 一\n',
        MindTheme.fresh(), 12);
      const bytes: Uint8Array = await PngRender.toPngBytes(result);
      const w: number = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      const h: number = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect(w).assertEqual(result.width);
      expect(h).assertEqual(result.height);
      await result.pixelMap.release();
    });

    it('emptyDocRenders', 0, async () => {
      const result: MindRenderResult = await PngRender.render('', MindTheme.fresh(), 12);
      expect(result.nodeCount).assertEqual(1);
      expect(result.width >= 88).assertTrue();
      expect(result.height >= 84).assertTrue();
      expect(result.scale).assertEqual(1);
      await result.pixelMap.release();
    });

    it('allThemesValidPng', 0, async () => {
      const themes: MindTheme[] = MindTheme.all();
      expect(themes.length).assertEqual(3);
      for (const theme of themes) {
        const bytes: Uint8Array = await PngRender.renderBytes('# 主题', theme, 12);
        expect(bytes.length > 64).assertTrue();
        expect(bytes[0]).assertEqual(0x89);
        expect(bytes[1]).assertEqual(0x50);
        expect(bytes[2]).assertEqual(0x4E);
      }
    });

    it('themeBackgroundPixels', 0, async () => {
      const fresh: MindRenderResult = await PngRender.render('# 主题\n\n- 甲\n',
        MindTheme.fresh(), 12);
      const dark: MindRenderResult = await PngRender.render('# 主题\n\n- 甲\n',
        MindTheme.dark(), 12);
      const freshBuf: ArrayBuffer = new ArrayBuffer(fresh.width * fresh.height * 4 + 4096);
      await fresh.pixelMap.readPixelsToBuffer(freshBuf);
      const darkBuf: ArrayBuffer = new ArrayBuffer(dark.width * dark.height * 4 + 4096);
      await dark.pixelMap.readPixelsToBuffer(darkBuf);
      const fb: Uint8Array = new Uint8Array(freshBuf);
      const db: Uint8Array = new Uint8Array(darkBuf);
      expect(fb[3]).assertEqual(255);
      expect(fb[0]).assertEqual(248);
      expect(db[3]).assertEqual(255);
      expect(db[0]).assertEqual(15);
      await fresh.pixelMap.release();
      await dark.pixelMap.release();
    });

    it('capAt4K', 0, async () => {
      const result: MindRenderResult = await PngRender.render(tallDoc(),
        MindTheme.fresh(), 0);
      expect(result.nodeCount).assertEqual(631);
      expect(result.scale < 1).assertTrue();
      expect(result.width <= 4096).assertTrue();
      expect(result.height <= 4096).assertTrue();
      expect(result.height).assertEqual(4096);
      hilog.info(0x0000, 'mdcPng', '%{public}s',
        `PNG_4K:w=${result.width} h=${result.height} scale=${result.scale}`);
      await result.pixelMap.release();
    });

    it('perf531Nodes', 0, async () => {
      const md: string = perfDoc();
      const t0: number = Date.now();
      const result: MindRenderResult = await PngRender.render(md, MindTheme.fresh(), 0);
      const t1: number = Date.now();
      const bytes: Uint8Array = await PngRender.toPngBytes(result);
      const t2: number = Date.now();
      hilog.info(0x0000, 'mdcPng', '%{public}s',
        `PNG_531:nodes=${result.nodeCount} w=${result.width} h=${result.height}`
        + ` render=${t1 - t0}ms pack=${t2 - t1}ms total=${t2 - t0}ms bytes=${bytes.length}`);
      expect(result.nodeCount).assertEqual(531);
      expect(t2 - t0 < 5000).assertTrue();
      await result.pixelMap.release();
    });
  });
}
