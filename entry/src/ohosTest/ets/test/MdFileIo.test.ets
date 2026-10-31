import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { FileUtil } from '../../../main/ets/core/FileIoUtil';

function testDir(): string {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext().filesDir;
}

function writeRaw(path: string, text: string): void {
  const file = fileIo.openSync(path,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  fileIo.writeSync(file.fd, text);
  fileIo.closeSync(file);
}

function mixedText(): string {
  const parts: string[] = [];
  for (let i: number = 0; i < 120; i++) {
    parts.push('第' + i.toString().padStart(3, '0') + '段中文内容 tail😀 end\n');
  }
  return parts.join('');
}

export default function mdFileIoTest() {
  describe('mdFileIoTest', () => {
    it('chunkedReadSplitsMultibyte', 0, () => {
      const path: string = testDir() + '/mdc_io_chunk.md';
      const text: string = mixedText();
      writeRaw(path, text);
      expect(FileUtil.readTextChunked(path, 7) == text).assertTrue();
      expect(FileUtil.readText(path) == text).assertTrue();
      const ref: string = util.TextDecoder.create('utf-8')
        .decodeToString(FileUtil.readBytes(path));
      expect(FileUtil.readTextChunked(path, 7) == ref).assertTrue();
    });

    it('chunkedReadExactChunkMultiple', 0, () => {
      const path: string = testDir() + '/mdc_io_exact.md';
      const text: string = 'abcdefg';
      writeRaw(path, text.repeat(3));
      expect(FileUtil.readTextChunked(path, 7) == 'abcdefgabcdefgabcdefg').assertTrue();
    });

    it('chunkedReadEmptyFile', 0, () => {
      const path: string = testDir() + '/mdc_io_empty.md';
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.closeSync(file);
      expect(FileUtil.readText(path) == '').assertTrue();
      expect(FileUtil.readTextChunked(path, 3) == '').assertTrue();
    });

    it('readBytesRoundtrip', 0, () => {
      const path: string = testDir() + '/mdc_io_bin.dat';
      const data: Uint8Array = new Uint8Array(25600);
      for (let i: number = 0; i < data.length; i += 1) {
        data[i] = i % 256;
      }
      FileUtil.writeBytes(path, data);
      const back: Uint8Array = FileUtil.readBytes(path);
      expect(back.length).assertEqual(25600);
      let mismatch: number = 0;
      for (let i: number = 0; i < back.length; i += 1) {
        if (back[i] != i % 256) {
          mismatch += 1;
        }
      }
      expect(mismatch).assertEqual(0);
    });

    it('largeFileChunkedReadOver2Mb', 0, () => {
      const path: string = testDir() + '/mdc_io_large.md';
      const unit: string = '中文段落样本〇一二三四五六七八九\n';
      const text: string = unit.repeat(70000);
      expect(text.length).assertEqual(17 * 70000);
      writeRaw(path, text);
      expect(FileUtil.readBytes(path).length > 2000000).assertTrue();
      const back: string = FileUtil.readText(path);
      expect(back.length).assertEqual(text.length);
      expect(back == text).assertTrue();
    });
  });
}
