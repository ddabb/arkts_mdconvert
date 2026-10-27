import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { LengthMetrics } from '@kit.ArkUI';
import { MdToJson } from '../core/MdJsonOut';
import { MdToYaml } from '../core/MdYamlOut';
import { MdToDocx } from '../core/DocxOut';
import { MdToMm, MdToOpml } from '../core/MmOpmlOut';
import { FileUtil } from '../core/FileIoUtil';
import { HistoryRecord, HistoryStore } from '../core/HistoryStore';
import { buildOutline, OutlineItem } from '../core/OutlineOut';
import { MdInlineParser } from '../core/MdInlineParser';
import { CodePreview } from './CodePreview';
import { OutlineTree } from './OutlineTree';

const MAX_CHARS: number = 200000;

class RecentFile {
  name: string = '';
  content: string = '';

  static of(name: string, content: string): RecentFile {
    const f: RecentFile = new RecentFile();
    f.name = name;
    f.content = content;
    return f;
  }
}

@Component
export struct ConvertPanel {
  @State mdText: string = '';
  @State fileName: string = '';
  @State fmtIdx: number = 0;
  @State treeMode: boolean = true;
  @State resultText: string = '';
  @State docxKb: number = 0;
  private docxBytes: Uint8Array | undefined = undefined;
  @State previewTab: number = 0;
  @State outlineItems: OutlineItem[] = [];
  @State recents: RecentFile[] = [];
  @StorageLink('mdc.pendingSeq') @Watch('onPending') pendingSeq: number = 0;

  aboutToAppear(): void {
    this.loadRecents();
  }

  private onPending(): void {
    const rec: HistoryRecord | undefined = AppStorage.get<HistoryRecord>('mdc.pendingRecord');
    if (rec === undefined || rec.content.length == 0) {
      return;
    }
    this.mdText = rec.content;
    this.fileName = rec.fileName;
    if (rec.fmt == 'json') {
      this.fmtIdx = 0;
    } else if (rec.fmt == 'yaml') {
      this.fmtIdx = 1;
    } else if (rec.fmt == 'mm') {
      this.fmtIdx = 2;
    } else if (rec.fmt == 'opml') {
      this.fmtIdx = 3;
    } else {
      this.fmtIdx = 4;
    }
    this.treeMode = rec.mode != 'flat';
    this.previewTab = 0;
    this.doConvert();
  }

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
    return $r('app.string.convert_fmt_docx');
  }

  private fmtKey(): string {
    if (this.fmtIdx == 0) {
      return 'json';
    }
    if (this.fmtIdx == 1) {
      return 'yaml';
    }
    if (this.fmtIdx == 2) {
      return 'mm';
    }
    if (this.fmtIdx == 3) {
      return 'opml';
    }
    return 'docx';
  }

  private modeKey(): string {
    if (this.fmtIdx == 0 || this.fmtIdx == 1) {
      return this.treeMode ? 'tree' : 'flat';
    }
    return '';
  }

  private previewLang(): string {
    if (this.fmtIdx == 0) {
      return 'json';
    }
    if (this.fmtIdx == 1) {
      return 'yaml';
    }
    return 'text';
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
    return '.docx';
  }

  private toast(msg: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({
      message: msg,
      duration: 2000
    });
  }

  private loadRecents(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    try {
      const records: HistoryRecord[] = HistoryStore.load(ctx.filesDir);
      const seen: Set<string> = new Set<string>();
      const out: RecentFile[] = [];
      for (const rec of records) {
        if (rec.content.length == 0) {
          continue;
        }
        if (seen.has(rec.fileName)) {
          continue;
        }
        seen.add(rec.fileName);
        out.push(RecentFile.of(rec.fileName, rec.content));
        if (out.length >= 3) {
          break;
        }
      }
      this.recents = out;
    } catch (err) {
    }
  }

  private pickFile(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
    const opt: picker.DocumentSelectOptions = {
      maxSelectNumber: 1,
      fileSuffixFilters: ['.md', '.markdown']
    };
    docPicker.select(opt).then((uris: Array<string>) => {
      if (uris.length == 0) {
        return;
      }
      try {
        let text: string = FileUtil.readText(uris[0]);
        if (text.length > MAX_CHARS) {
          text = text.substring(0, MAX_CHARS);
          this.toast($r('app.string.convert_too_large', MAX_CHARS));
        }
        this.fileName = FileUtil.fileNameOf(uris[0]);
        this.mdText = text;
        this.resultText = '';
        this.docxBytes = undefined;
        this.docxKb = 0;
        this.outlineItems = [];
      } catch (err) {
        this.toast($r('app.string.read_fail'));
      }
    }).catch(() => {
    });
  }

  private refreshOutline(): void {
    const src: string = this.mdText.trim();
    if (src.length == 0) {
      this.outlineItems = [];
      return;
    }
    try {
      this.outlineItems = buildOutline(MdInlineParser.parseFull(src));
    } catch (err) {
      this.outlineItems = [];
    }
  }

  private doConvert(): void {
    const src: string = this.mdText.trim();
    if (src.length == 0) {
      this.toast($r('app.string.convert_empty_input'));
      return;
    }
    this.resultText = '';
    this.docxBytes = undefined;
    this.docxKb = 0;
    try {
      if (this.fmtIdx == 0) {
        this.resultText = this.treeMode ? MdToJson.tree(src) : MdToJson.flat(src);
      } else if (this.fmtIdx == 1) {
        this.resultText = this.treeMode ? MdToYaml.tree(src) : MdToYaml.flat(src);
      } else if (this.fmtIdx == 2) {
        this.resultText = MdToMm.mm(src);
      } else if (this.fmtIdx == 3) {
        this.resultText = MdToOpml.opml(src);
      } else {
        const bytes: Uint8Array = MdToDocx.generate(src);
        this.docxBytes = bytes;
        this.docxKb = Math.ceil(bytes.length / 1024);
      }
      this.recordHistory(src);
    } catch (err) {
      this.toast($r('app.string.convert_fail'));
    }
  }

  private recordHistory(src: string): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    try {
      HistoryStore.add(ctx.filesDir,
        HistoryStore.record(this.fileName, this.fmtKey(), this.modeKey(), src, Date.now()));
      const seq: number | undefined = AppStorage.get<number>('mdc.historySeq');
      AppStorage.setOrCreate('mdc.historySeq', (seq ?? 0) + 1);
      this.loadRecents();
    } catch (err) {
    }
  }

  private exportName(): string {
    const base: string = this.fileName.length > 0 ?
      FileUtil.baseName(this.fileName) : 'mdconvert';
    return base + this.extOf();
  }

  private doExport(): void {
    const bytes: Uint8Array | undefined = this.docxBytes;
    if (this.resultText.length == 0 && bytes === undefined) {
      this.toast($r('app.string.convert_export_first'));
      return;
    }
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    const name: string = this.exportName();
    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
    const opt: picker.DocumentSaveOptions = {
      newFileNames: [name]
    };
    docPicker.save(opt).then((uris: Array<string>) => {
      if (uris.length == 0) {
        return;
      }
      try {
        if (bytes !== undefined) {
          FileUtil.writeBytes(uris[0], bytes);
        } else {
          FileUtil.writeText(uris[0], this.resultText);
        }
        this.toast($r('app.string.export_done', name));
      } catch (err) {
        this.toast($r('app.string.export_fail'));
      }
    }).catch(() => {
    });
  }

  private doShare(): void {
    const bytes: Uint8Array | undefined = this.docxBytes;
    if (this.resultText.length == 0 && bytes === undefined) {
      this.toast($r('app.string.convert_export_first'));
      return;
    }
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    const path: string = ctx.cacheDir + '/mdc_share' + this.extOf();
    try {
      if (bytes !== undefined) {
        FileUtil.writeBytes(path, bytes);
      } else {
        FileUtil.writeText(path, this.resultText);
      }
      const record: systemShare.SharedRecord = {
        utd: bytes !== undefined ?
          uniformTypeDescriptor.UniformDataType.WORD_DOC :
          uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        uri: fileUri.getUriFromPath(path)
      };
      const data: systemShare.SharedData = new systemShare.SharedData(record);
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const options: systemShare.ShareControllerOptions = {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      };
      controller.show(ctx as common.UIAbilityContext, options).catch(() => {
        this.toast($r('app.string.convert_share_fail'));
      });
    } catch (err) {
      this.toast($r('app.string.convert_share_fail'));
    }
  }

  private openMindPreview(): void {
    if (this.mdText.trim().length == 0) {
      this.toast($r('app.string.convert_empty_input'));
      return;
    }
    AppStorage.setOrCreate('mdc.mind.src', this.mdText);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MindmapPreviewPage' });
  }

  private loadRecent(f: RecentFile): void {
    this.fileName = f.name;
    this.mdText = f.content;
    this.resultText = '';
    this.docxBytes = undefined;
    this.docxKb = 0;
    this.outlineItems = [];
    this.previewTab = 0;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text($r('app.string.convert_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text'))
          Text($r('app.string.convert_desc'))
            .fontSize(12)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .padding({ top: 14, bottom: 14, left: 16, right: 16 })
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(16)

        Column({ space: 10 }) {
          if (this.fileName.length > 0) {
            Text(this.fileName)
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Row({ space: 8 }) {
            Button($r('app.string.convert_pick_file'))
              .backgroundColor($r('app.color.brand_tint'))
              .fontColor($r('app.color.brand'))
              .onClick(() => {
                this.pickFile();
              })
            if (this.recents.length > 0) {
              Text($r('app.string.convert_recent'))
                .fontSize(12)
                .fontColor($r('app.color.hint_text'))
            }
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
              ForEach(this.recents, (f: RecentFile) => {
                Text(f.name.length > 0 ? f.name : $r('app.string.history_pasted'))
                  .fontSize(11)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .constraintSize({ maxWidth: 120 })
                  .fontColor($r('app.color.primary_text'))
                  .backgroundColor($r('app.color.page_background'))
                  .borderRadius(10)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .onClick(() => {
                    this.loadRecent(f);
                  })
              }, (f: RecentFile) => f.content.length.toString() + f.name)
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            Text($r('app.string.convert_source_tab'))
              .fontSize(12)
              .fontColor(this.previewTab == 0 ? Color.White : $r('app.color.primary_text'))
              .backgroundColor(this.previewTab == 0 ? $r('app.color.brand') : $r('app.color.page_background'))
              .borderRadius(12)
              .padding({ left: 12, right: 12, top: 4, bottom: 4 })
              .onClick(() => {
                this.previewTab = 0;
              })
            Text($r('app.string.convert_outline_tab'))
              .fontSize(12)
              .fontColor(this.previewTab == 1 ? Color.White : $r('app.color.primary_text'))
              .backgroundColor(this.previewTab == 1 ? $r('app.color.brand') : $r('app.color.page_background'))
              .borderRadius(12)
              .padding({ left: 12, right: 12, top: 4, bottom: 4 })
              .onClick(() => {
                this.previewTab = 1;
                this.refreshOutline();
              })
          }
          .width('100%')

          if (this.previewTab == 0) {
            TextArea({ text: this.mdText, placeholder: $r('app.string.convert_paste_placeholder') })
              .maxLength(MAX_CHARS)
              .height(150)
              .fontSize(13)
              .backgroundColor($r('app.color.page_background'))
              .borderRadius(10)
              .onChange((value: string) => {
                this.mdText = value;
              })
          } else {
            OutlineTree({ items: this.outlineItems })
              .height(150)
          }
          if (this.previewTab == 0 && this.mdText.length > 0) {
            Text($r('app.string.convert_chars', this.mdText.length))
              .fontSize(11)
              .fontColor($r('app.color.hint_text'))
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(16)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 10 }) {
          Text($r('app.string.convert_fmt_label'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text'))
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            ForEach([0, 1, 2, 3, 4], (idx: number) => {
              Text(this.fmtLabel(idx))
                .fontSize(13)
                .fontColor(this.fmtIdx == idx ? Color.White : $r('app.color.primary_text'))
                .backgroundColor(this.fmtIdx == idx ? $r('app.color.brand') : $r('app.color.page_background'))
                .borderRadius(14)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => {
                  this.fmtIdx = idx;
                  this.resultText = '';
                  this.docxBytes = undefined;
                  this.docxKb = 0;
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
                  this.resultText = '';
                })
              Text($r('app.string.convert_mode_tree'))
                .fontSize(13)
                .fontColor(this.treeMode ? Color.White : $r('app.color.primary_text'))
                .backgroundColor(this.treeMode ? $r('app.color.brand') : $r('app.color.page_background'))
                .borderRadius(14)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => {
                  this.treeMode = true;
                  this.resultText = '';
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

        Row({ space: 12 }) {
          Button($r('app.string.convert_run'))
            .backgroundColor($r('app.color.brand'))
            .fontColor(Color.White)
            .layoutWeight(1)
            .onClick(() => {
              this.doConvert();
            })
          Button($r('app.string.convert_export'))
            .backgroundColor($r('app.color.accent'))
            .fontColor(Color.White)
            .layoutWeight(1)
            .onClick(() => {
              this.doExport();
            })
        }
        .width('100%')

        Row({ space: 12 }) {
          Button($r('app.string.convert_share'))
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.primary_text'))
            .layoutWeight(1)
            .onClick(() => {
              this.doShare();
            })
          Button($r('app.string.convert_mind_preview'))
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.primary_text'))
            .layoutWeight(1)
            .onClick(() => {
              this.openMindPreview();
            })
        }
        .width('100%')

        Row({ space: 10 }) {
          Text($r('app.string.convert_batch_entry'))
            .fontSize(12)
            .fontColor($r('app.color.brand'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.brand_tint'))
            .borderRadius(12)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/BatchConvertPage' });
            })
          Text($r('app.string.convert_mdpreview_entry'))
            .fontSize(12)
            .fontColor($r('app.color.brand'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.brand_tint'))
            .borderRadius(12)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/MdPreviewPage' });
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        if (this.resultText.length > 0) {
          Column({ space: 8 }) {
            Text($r('app.string.convert_result_title'))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text'))
            CodePreview({ text: this.resultText, lang: this.previewLang() })
              .height(240)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
        }
        if (this.docxKb > 0) {
          Text($r('app.string.convert_docx_ready', this.docxKb))
            .fontSize(13)
            .fontColor($r('app.color.success_green'))
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor($r('app.color.page_background'))
  }
}
