import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { hilog, hidebug } from '@kit.PerformanceAnalysisKit';
import { MdToJson } from '../core/MdJsonOut';
import { MdToYaml } from '../core/MdYamlOut';
import { MdToDocx, DocxOptions } from '../core/DocxOut';
import { MdToHtml } from '../core/MdHtmlOut';
import { MdToCsv } from '../core/MdCsvOut';
import { DocxImageLoader } from '../core/DocxImageLoader';
import { SettingsStore } from '../core/SettingsStore';
import { MdToMm, MdToOpml } from '../core/MmOpmlOut';
import { FileUtil } from '../core/FileIoUtil';
import { ZipWriter } from '../core/ZipWriter';

@Observed
class BatchFile {
  name: string;
  uri: string;
  status: number;

  constructor(name: string, uri: string) {
    this.name = name;
    this.uri = uri;
    this.status = 0;
  }
}

@Component
struct BatchFileRow {
  @ObjectLink file: BatchFile;

  private statusLabel(): ResourceStr {
    if (this.file.status == 1) {
      return $r('app.string.batch_ok');
    }
    if (this.file.status == 2) {
      return $r('app.string.batch_fail');
    }
    return $r('app.string.batch_pending');
  }

  private statusColor(): ResourceColor {
    if (this.file.status == 1) {
      return $r('app.color.success_green');
    }
    if (this.file.status == 2) {
      return $r('app.color.danger_red');
    }
    return $r('app.color.hint_text');
  }

  build() {
    Row({ space: 8 }) {
      Text(this.file.name)
        .fontSize(13)
        .fontColor($r('app.color.primary_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.statusLabel())
        .fontSize(12)
        .fontColor(this.statusColor())
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        .backgroundColor($r('app.color.page_background'))
        .borderRadius(10)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
  }
}

@Entry
@Component
struct BatchConvertPage {
  @State files: BatchFile[] = [];
  @State fmtIdx: number = 0;
  @State treeMode: boolean = true;
  @State busy: boolean = false;
  @State done: number = 0;
  @State total: number = 0;

  private fmtLabel(idx: number): ResourceStr {
    if (idx == 0) {
      return $r('app.string.convert_fmt_json');
    }
    if (idx == 1) {
      return $r('app.string.convert_fmt_yaml');
    }
    if (idx == 2) {
      return $r('app.string.convert_fmt_mm');
    }
    if (idx == 3) {
      return $r('app.string.convert_fmt_opml');
    }
    if (idx == 4) {
      return $r('app.string.convert_fmt_docx');
    }
    if (idx == 5) {
      return $r('app.string.convert_fmt_html');
    }
    return $r('app.string.convert_fmt_csv');
  }

  private extOf(): string {
    if (this.fmtIdx == 0) {
      return '.json';
    }
    if (this.fmtIdx == 1) {
      return '.yaml';
    }
    if (this.fmtIdx == 2) {
      return '.mm';
    }
    if (this.fmtIdx == 3) {
      return '.opml';
    }
    if (this.fmtIdx == 4) {
      return '.docx';
    }
    if (this.fmtIdx == 5) {
      return '.html';
    }
    return '.csv';
  }

  private toast(msg: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({
      message: msg,
      duration: 2000
    });
  }

  private pickFiles(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
    const opt: picker.DocumentSelectOptions = {
      maxSelectNumber: 100,
      fileSuffixFilters: ['.md', '.markdown']
    };
    docPicker.select(opt).then((uris: Array<string>) => {
      const next: BatchFile[] = [];
      const seen: Set<string> = new Set<string>();
      for (const old of this.files) {
        next.push(old);
        seen.add(old.uri);
      }
      for (const uri of uris) {
        if (!seen.has(uri)) {
          next.push(new BatchFile(FileUtil.fileNameOf(uri), uri));
          seen.add(uri);
        }
      }
      this.files = next;
    }).catch(() => {
    });
  }

  private docxOptions(): DocxOptions {
    const opts: DocxOptions = new DocxOptions();
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return opts;
    }
    try {
      SettingsStore.ensure(ctx);
      const saved: DocxOptions = SettingsStore.docxOptions();
      opts.firstLineIndent = saved.firstLineIndent;
      opts.headingNumbers = saved.headingNumbers;
      opts.toc = saved.toc;
      opts.pageNumbers = saved.pageNumbers;
      opts.embedImages = saved.embedImages;
      opts.tocTitle = ctx.resourceManager.getStringSync($r('app.string.docx_toc_title'));
    } catch (err) {
    }
    return opts;
  }

  private yieldUi(): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, 0);
    });
  }

  private async runBatch(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.files.length == 0) {
      this.toast($r('app.string.batch_empty'));
      return;
    }
    this.busy = true;
    this.done = 0;
    this.total = this.files.length;
    for (const f of this.files) {
      f.status = 0;
    }
    const docxOpts: DocxOptions = this.docxOptions();
    const zip: ZipWriter = new ZipWriter();
    const used: Map<string, number> = new Map<string, number>();
    let ok: number = 0;
    let fail: number = 0;
    let peakVss: bigint = hidebug.getVss();
    for (const f of this.files) {
      try {
        const text: string = FileUtil.readText(f.uri);
        const base: string = FileUtil.baseName(f.name);
        const count: number | undefined = used.get(base);
        let entryBase: string = base;
        if (count === undefined) {
          used.set(base, 1);
        } else {
          used.set(base, count + 1);
          entryBase = base + '_' + count.toString();
        }
        if (this.fmtIdx == 4) {
          const images: Map<string, Uint8Array> = docxOpts.embedImages ?
            DocxImageLoader.load(text, FileUtil.dirOf(f.uri)) : new Map<string, Uint8Array>();
          zip.addBytes(entryBase + this.extOf(), MdToDocx.generateWith(text, docxOpts, images));
        } else if (this.fmtIdx == 0) {
          zip.add(entryBase + '.json', this.treeMode ? MdToJson.tree(text) : MdToJson.flat(text));
        } else if (this.fmtIdx == 1) {
          zip.add(entryBase + '.yaml', this.treeMode ? MdToYaml.tree(text) : MdToYaml.flat(text));
        } else if (this.fmtIdx == 2) {
          zip.add(entryBase + '.mm', MdToMm.mm(text));
        } else if (this.fmtIdx == 3) {
          zip.add(entryBase + '.opml', MdToOpml.opml(text));
        } else if (this.fmtIdx == 5) {
          zip.add(entryBase + '.html', MdToHtml.html(text, entryBase));
        } else {
          zip.addBytes(entryBase + '.csv', MdToCsv.csvBytes(text));
        }
        f.status = 1;
        ok += 1;
      } catch (err) {
        f.status = 2;
        fail += 1;
      }
      this.done += 1;
      const vss: bigint = hidebug.getVss();
      if (vss > peakVss) {
        peakVss = vss;
      }
      await this.yieldUi();
    }
    hilog.info(0x0000, 'mdcBatch',
      'BATCH_MEM files=%{public}d ok=%{public}d fail=%{public}d peakVss=%{public}sKB',
      this.total, ok, fail, peakVss.toString());
    if (ok == 0) {
      this.busy = false;
      this.toast($r('app.string.batch_all_fail'));
      return;
    }
    const zipBytes: Uint8Array = zip.bytes();
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      this.busy = false;
      return;
    }
    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
    const opt: picker.DocumentSaveOptions = {
      newFileNames: ['MdConvert_Batch.zip']
    };
    docPicker.save(opt).then((uris: Array<string>) => {
      this.busy = false;
      if (uris.length == 0) {
        return;
      }
      try {
        FileUtil.writeBytes(uris[0], zipBytes);
        this.toast($r('app.string.batch_summary', ok, fail));
      } catch (err) {
        this.toast($r('app.string.export_fail'));
      }
    }).catch(() => {
      this.busy = false;
    });
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 10 }) {
        Text($r('app.string.batch_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
        Text($r('app.string.batch_desc'))
          .fontSize(13)
          .fontColor($r('app.color.secondary_text'))
      }
      .width('100%')
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 10 }) {
            Text($r('app.string.convert_fmt_label'))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text'))
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
              ForEach([0, 1, 2, 3, 4, 5, 6], (idx: number) => {
                Text(this.fmtLabel(idx))
                  .fontSize(13)
                  .fontColor(this.fmtIdx == idx ? Color.White : $r('app.color.primary_text'))
                  .backgroundColor(this.fmtIdx == idx ? $r('app.color.brand') : $r('app.color.page_background'))
                  .borderRadius(14)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.fmtIdx = idx;
                  })
              }, (idx: number) => idx.toString())
            }
            .width('100%')
            if (this.fmtIdx == 0 || this.fmtIdx == 1) {
              Text($r('app.string.convert_mode_label'))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text'))
              Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
                Text($r('app.string.convert_mode_flat'))
                  .fontSize(13)
                  .fontColor(!this.treeMode ? Color.White : $r('app.color.primary_text'))
                  .backgroundColor(!this.treeMode ? $r('app.color.brand') : $r('app.color.page_background'))
                  .borderRadius(14)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.treeMode = false;
                  })
                Text($r('app.string.convert_mode_tree'))
                  .fontSize(13)
                  .fontColor(this.treeMode ? Color.White : $r('app.color.primary_text'))
                  .backgroundColor(this.treeMode ? $r('app.color.brand') : $r('app.color.page_background'))
                  .borderRadius(14)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.treeMode = true;
                  })
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Row() {
              Button($r('app.string.batch_pick'))
                .backgroundColor($r('app.color.brand_tint'))
                .fontColor($r('app.color.brand'))
                .onClick(() => {
                  this.pickFiles();
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            if (this.files.length == 0) {
              Text($r('app.string.batch_empty'))
                .fontSize(13)
                .fontColor($r('app.color.hint_text'))
            } else {
              Text($r('app.string.batch_file_count', this.files.length))
                .fontSize(12)
                .fontColor($r('app.color.secondary_text'))
              ForEach(this.files, (f: BatchFile) => {
                BatchFileRow({ file: f })
              }, (f: BatchFile) => f.uri)
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)

      if (this.busy) {
        Column({ space: 6 }) {
          Progress({ value: this.done, total: this.total, type: ProgressType.Linear })
            .width('86%')
            .color($r('app.color.brand'))
            .backgroundColor($r('app.color.page_background'))
            .borderRadius(4)
          Text($r('app.string.batch_progress', this.done, this.total))
            .fontSize(12)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
      }

      Button($r('app.string.batch_run'))
        .backgroundColor($r('app.color.brand'))
        .fontColor(Color.White)
        .width('90%')
        .enabled(!this.busy)
        .onClick(() => {
          this.runBatch();
        })
    }
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
