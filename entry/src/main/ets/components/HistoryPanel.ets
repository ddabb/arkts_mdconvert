import { common } from '@kit.AbilityKit';
import { HistoryRecord, HistoryStore } from '../core/HistoryStore';

@Component
export struct HistoryPanel {
  @State records: HistoryRecord[] = [];
  @StorageProp('mdc.historySeq') @Watch('onHistoryChanged') historySeq: number = 0;
  requestConvert: () => void = () => {};

  aboutToAppear(): void {
    this.reload();
  }

  private onHistoryChanged(): void {
    this.reload();
  }

  private reload(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    try {
      this.records = HistoryStore.load(ctx.filesDir);
    } catch (err) {
      this.records = [];
    }
  }

  private pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  private formatTime(time: number): string {
    const d: Date = new Date(time);
    return `${d.getFullYear()}-${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())} ` +
      `${this.pad(d.getHours())}:${this.pad(d.getMinutes())}`;
  }

  private fmtDisplay(fmt: string): string {
    if (fmt == 'json') {
      return 'JSON';
    }
    if (fmt == 'yaml') {
      return 'YAML';
    }
    if (fmt == 'mm') {
      return 'MM';
    }
    if (fmt == 'opml') {
      return 'OPML';
    }
    return 'DOCX';
  }

  private displayName(rec: HistoryRecord): ResourceStr {
    return rec.fileName.length > 0 ? rec.fileName : $r('app.string.history_pasted');
  }

  private reconvert(rec: HistoryRecord): void {
    AppStorage.setOrCreate('mdc.pendingRecord', rec);
    const cur: number | undefined = AppStorage.get<number>('mdc.pendingSeq');
    AppStorage.setOrCreate('mdc.pendingSeq', (cur ?? 0) + 1);
    this.requestConvert();
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.history_clear'),
      message: $r('app.string.history_clear_confirm'),
      primaryButton: {
        value: $r('app.string.dialog_cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.dialog_ok'),
        action: () => {
          const ctx: common.Context | undefined = this.getUIContext().getHostContext();
          if (ctx === undefined) {
            return;
          }
          try {
            HistoryStore.clear(ctx.filesDir);
          } catch (err) {
          }
          this.records = [];
          this.getUIContext().getPromptAction().showToast({
            message: $r('app.string.history_clear_done'),
            duration: 1500
          });
        }
      }
    });
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text($r('app.string.tab_history'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
        Blank()
        if (this.records.length > 0) {
          Text($r('app.string.history_clear'))
            .fontSize(13)
            .fontColor($r('app.color.danger_red'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .onClick(() => {
              this.confirmClear();
            })
        }
      }
      .width('100%')
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)

      if (this.records.length == 0) {
        Column() {
          Text($r('app.string.history_empty'))
            .fontSize(13)
            .fontColor($r('app.color.hint_text'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.records, (rec: HistoryRecord) => {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(this.displayName(rec))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.primary_text'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${this.fmtDisplay(rec.fmt)} · ${this.formatTime(rec.time)} · ${rec.chars}`)
                    .fontSize(11)
                    .fontColor($r('app.color.hint_text'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text($r('app.string.history_reconvert'))
                  .fontSize(12)
                  .fontColor($r('app.color.brand'))
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.brand_tint'))
                  .borderRadius(12)
                  .onClick(() => {
                    this.reconvert(rec);
                  })
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .alignItems(VerticalAlign.Center)
            }, (rec: HistoryRecord) => `${rec.id}`)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
