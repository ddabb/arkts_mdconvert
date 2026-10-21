import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { MindTheme } from '../core/MindmapTheme';
import { MindRenderResult, PngRender } from '../core/PngRender';

const DEMO_MD: string = [
  '# MdConvert 思维导图',
  '',
  '## 核心能力',
  '',
  '- Markdown 解析',
  '- 多格式导出',
  '  - JSON',
  '  - YAML',
  '  - Word 文档',
  '- 思维导图',
  '',
  '## 主题',
  '',
  '- 清爽',
  '- 手账',
  '- 暗夜',
  '',
  '## 特性',
  '',
  '- 鸿蒙原生',
  '- 全离线',
  '- 一次买断'
].join('\n');

@Entry
@Component
struct MindmapPreviewPage {
  @State themeIdx: number = 0;
  @State result: MindRenderResult | undefined = undefined;
  @State busy: boolean = false;
  @State viewScale: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State pinchBase: number = 1;
  @State panBaseX: number = 0;
  @State panBaseY: number = 0;
  private themes: MindTheme[] = MindTheme.all();

  aboutToAppear(): void {
    this.rerender();
  }

  private rerender(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const old: MindRenderResult | undefined = this.result;
    const theme: MindTheme = this.themes[this.themeIdx];
    PngRender.render(DEMO_MD, theme, 12).then((r: MindRenderResult) => {
      this.result = r;
      this.busy = false;
      this.resetView();
      if (old !== undefined) {
        old.pixelMap.release();
      }
    }).catch(() => {
      this.busy = false;
      hilog.error(0x0000, 'mdcPreview', '%{public}s', 'render failed');
    });
  }

  private resetView(): void {
    this.viewScale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.pinchBase = 1;
    this.panBaseX = 0;
    this.panBaseY = 0;
  }

  private exportPng(): void {
    const current: MindRenderResult | undefined = this.result;
    if (current === undefined || this.busy) {
      return;
    }
    this.busy = true;
    PngRender.toPngBytes(current).then((bytes: Uint8Array) => {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        this.busy = false;
        return;
      }
      const path: string = ctx.filesDir + '/mdc_export.png';
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, bytes.buffer);
      fileIo.closeSync(file);
      this.busy = false;
      const toast: ShowToastOptions = {
        message: $r('app.string.mindmap_export_done', path),
        duration: 2500
      };
      this.getUIContext().getPromptAction().showToast(toast);
    }).catch(() => {
      this.busy = false;
      hilog.error(0x0000, 'mdcPreview', '%{public}s', 'export failed');
    });
  }

  private themeLabel(idx: number): ResourceStr {
    if (idx == 0) {
      return $r('app.string.mindmap_theme_fresh');
    }
    if (idx == 1) {
      return $r('app.string.mindmap_theme_journal');
    }
    return $r('app.string.mindmap_theme_dark');
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 10 }) {
        Text($r('app.string.mindmap_preview_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
        Row({ space: 8 }) {
          ForEach(this.themes, (theme: MindTheme, idx: number) => {
            Text(this.themeLabel(idx))
              .fontSize(13)
              .fontColor(this.themeIdx == idx ? Color.White : $r('app.color.primary_text'))
              .backgroundColor(this.themeIdx == idx ? $r('app.color.brand') : $r('app.color.card_background'))
              .borderRadius(14)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .onClick(() => {
                if (this.themeIdx != idx) {
                  this.themeIdx = idx;
                  this.rerender();
                }
              })
          }, (theme: MindTheme) => theme.key)
        }
      }
      .width('100%')
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Stack({ alignContent: Alignment.Center }) {
        if (this.result !== undefined) {
          Image(this.result.pixelMap)
            .objectFit(ImageFit.Contain)
            .width('100%')
            .height('100%')
            .scale({ x: this.viewScale, y: this.viewScale })
            .translate({ x: this.offsetX, y: this.offsetY })
            .gesture(
              GestureGroup(GestureMode.Parallel,
                PinchGesture()
                  .onActionStart(() => {
                    this.pinchBase = this.viewScale;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    const next: number = this.pinchBase * event.scale;
                    this.viewScale = Math.min(5, Math.max(0.5, next));
                  }),
                PanGesture({ fingers: 1 })
                  .onActionStart(() => {
                    this.panBaseX = this.offsetX;
                    this.panBaseY = this.offsetY;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    this.offsetX = this.panBaseX + event.offsetX;
                    this.offsetY = this.panBaseY + event.offsetY;
                  })
              )
            )
        } else {
          Text($r('app.string.mindmap_rendering'))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        if (this.busy) {
          Text($r('app.string.mindmap_rendering'))
            .fontSize(12)
            .fontColor($r('app.color.hint_text'))
            .padding(8)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('app.color.page_background'))

      Row({ space: 12 }) {
        Button($r('app.string.mindmap_reset_view'))
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.primary_text'))
          .onClick(() => {
            this.resetView();
          })
        Button($r('app.string.mindmap_export_png'))
          .backgroundColor($r('app.color.brand'))
          .fontColor(Color.White)
          .onClick(() => {
            this.exportPng();
          })
      }

      Text($r('app.string.mindmap_demo_note'))
        .fontSize(11)
        .fontColor($r('app.color.hint_text'))
        .padding({ bottom: 8 })
    }
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
