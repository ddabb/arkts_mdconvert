import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { LengthMetrics } from '@kit.ArkUI';
import { MindTheme } from '../core/MindmapTheme';
import { MindRenderResult, PngRender } from '../core/PngRender';
import { AlbumImageSaver } from '../core/AlbumImageSaver';
import { MindNode, MindTreeBuilder } from '../core/MindmapTree';
import { MdToXmind } from '../core/XmindOut';
import { FileUtil } from '../core/FileIoUtil';

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
  '- 打印',
  '',
  '## 特性',
  '',
  '- 鸿蒙原生',
  '- 全离线',
  '- 一次买断'
].join('\n');

class MindListNode {
  path: string = '';
  text: string = '';
  depth: number = 0;
  hasKids: boolean = false;
  folded: boolean = false;

  static of(path: string, text: string, depth: number, hasKids: boolean, folded: boolean): MindListNode {
    const n: MindListNode = new MindListNode();
    n.path = path;
    n.text = text;
    n.depth = depth;
    n.hasKids = hasKids;
    n.folded = folded;
    return n;
  }
}

@Entry
@Component
struct MindmapPreviewPage {
  @State themeIdx: number = 0;
  @State result: MindRenderResult | undefined = undefined;
  @State busy: boolean = false;
  @State saving: boolean = false;
  @State viewScale: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State pinchBase: number = 1;
  @State panBaseX: number = 0;
  @State panBaseY: number = 0;
  @State isCustom: boolean = false;
  @State showFoldPanel: boolean = false;
  @State collapsedPaths: Set<string> = new Set<string>();
  @State flatNodes: MindListNode[] = [];
  private sourceMd: string = DEMO_MD;
  private fullTree: MindNode | undefined = undefined;
  private themes: MindTheme[] = MindTheme.all();

  aboutToAppear(): void {
    const src: string | undefined = AppStorage.get<string>('mdc.mind.src');
    if (src !== undefined && src.trim().length > 0) {
      this.sourceMd = src;
      this.isCustom = true;
      AppStorage.setOrCreate('mdc.mind.src', '');
    }
    try {
      const tree: MindNode = MindTreeBuilder.buildSrc(this.sourceMd, 12);
      MindTreeBuilder.assignPaths(tree);
      this.fullTree = tree;
    } catch (err) {
      this.fullTree = undefined;
    }
    this.rebuildFlat();
    this.requestRender();
  }

  private rebuildFlat(): void {
    const out: MindListNode[] = [];
    const tree: MindNode | undefined = this.fullTree;
    if (tree !== undefined) {
      MindmapPreviewPage.walkFlat(tree, 0, out, this.collapsedPaths);
    }
    this.flatNodes = out;
  }

  private static walkFlat(node: MindNode, depth: number, out: MindListNode[],
    collapsed: Set<string>): void {
    const folded: boolean = collapsed.has(node.path);
    out.push(MindListNode.of(node.path, node.text, depth, node.children.length > 0, folded));
    if (folded) {
      return;
    }
    for (const child of node.children) {
      MindmapPreviewPage.walkFlat(child, depth + 1, out, collapsed);
    }
  }

  private toggleFold(path: string): void {
    const next: Set<string> = new Set<string>(this.collapsedPaths);
    if (next.has(path)) {
      next.delete(path);
    } else {
      next.add(path);
    }
    this.collapsedPaths = next;
    this.rebuildFlat();
    this.requestRender();
  }

  private unfoldAll(): void {
    if (this.collapsedPaths.size == 0) {
      return;
    }
    this.collapsedPaths = new Set<string>();
    this.rebuildFlat();
    this.requestRender();
  }

  private requestRender(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const old: MindRenderResult | undefined = this.result;
    const theme: MindTheme = this.themes[this.themeIdx];
    let tree: MindNode | undefined = this.fullTree;
    if (tree === undefined) {
      tree = MindTreeBuilder.buildSrc(this.sourceMd, 12);
      MindTreeBuilder.assignPaths(tree);
      this.fullTree = tree;
    }
    const pruned: MindNode = this.collapsedPaths.size == 0 ? tree : MindTreeBuilder.prune(tree, this.collapsedPaths);
    PngRender.renderTree(pruned, theme).then((r: MindRenderResult) => {
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

  private async exportPng(): Promise<void> {
    const current: MindRenderResult | undefined = this.result;
    if (current === undefined || this.busy) {
      return;
    }
    this.busy = true;
    this.saving = true;
    try {
      const ctx: common.Context | undefined = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        const bytes: Uint8Array = await PngRender.toPngBytes(current);
        const saved: boolean = await AlbumImageSaver.savePngBytesToAlbum(ctx, bytes, 'mdc_mindmap');
        if (saved) {
          this.getUIContext().getPromptAction().showToast({
            message: $r('app.string.mindmap_export_done'),
            duration: 2500
          });
        }
      }
    } catch (err) {
      hilog.error(0x0000, 'mdcPreview', '%{public}s', 'export failed');
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.export_fail'),
        duration: 2500
      });
    }
    this.busy = false;
    this.saving = false;
  }

  private exportXmind(): void {
    const tree: MindNode | undefined = this.fullTree;
    if (tree === undefined || this.busy) {
      return;
    }
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    try {
      const bytes: Uint8Array = MdToXmind.xmindTree(tree);
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const opt: picker.DocumentSaveOptions = {
        newFileNames: ['mdconvert_mindmap.xmind']
      };
      docPicker.save(opt).then((uris: Array<string>) => {
        if (uris.length == 0) {
          return;
        }
        try {
          FileUtil.writeBytes(uris[0], bytes);
          this.getUIContext().getPromptAction().showToast({
            message: $r('app.string.export_done', 'mdconvert_mindmap.xmind'),
            duration: 2500
          });
        } catch (err) {
          this.getUIContext().getPromptAction().showToast({
            message: $r('app.string.export_fail'),
            duration: 2500
          });
        }
      }).catch(() => {
      });
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.export_fail'),
        duration: 2500
      });
    }
  }

  private themeLabel(idx: number): ResourceStr {
    if (idx == 0) {
      return $r('app.string.mindmap_theme_fresh');
    }
    if (idx == 1) {
      return $r('app.string.mindmap_theme_journal');
    }
    if (idx == 2) {
      return $r('app.string.mindmap_theme_dark');
    }
    return $r('app.string.mindmap_theme_print');
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
                  this.requestRender();
                }
              })
          }, (theme: MindTheme) => theme.key)
        }
      }
      .width('100%')
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Stack({ alignContent: Alignment.Top }) {
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
        if (this.showFoldPanel && this.flatNodes.length > 0) {
          Column({ space: 8 }) {
            Row() {
              Text($r('app.string.mindmap_fold_panel'))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text'))
                .layoutWeight(1)
              Text($r('app.string.mindmap_unfold_all'))
                .fontSize(12)
                .fontColor($r('app.color.brand'))
                .onClick(() => {
                  this.unfoldAll();
                })
            }
            .width('100%')
            List({ space: 2 }) {
              ForEach(this.flatNodes, (n: MindListNode) => {
                ListItem() {
                  Row({ space: 6 }) {
                    Text(n.folded ? '+' : (n.hasKids ? '-' : '·'))
                      .fontSize(12)
                      .fontColor($r('app.color.brand'))
                      .width(14)
                    Text(n.text.length > 0 ? n.text : ' ')
                      .fontSize(12)
                      .fontColor($r('app.color.primary_text'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 4 + n.depth * 12, right: 8, top: 4, bottom: 4 })
                  .borderRadius(8)
                  .backgroundColor(this.collapsedPaths.has(n.path) ? $r('app.color.brand_tint') : Color.Transparent)
                  .onClick(() => {
                    if (n.hasKids) {
                      this.toggleFold(n.path);
                    }
                  })
                }
              }, (n: MindListNode) => n.path + (n.folded ? 'f' : 'e') + n.text.length.toString())
            }
            .width('100%')
            .layoutWeight(1)
            .edgeEffect(EdgeEffect.Spring)
          }
          .width('72%')
          .height('82%')
          .padding(12)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(16)
          .margin({ top: 8 })
        }
        if (this.busy) {
          Text(this.saving ? $r('app.string.mindmap_saving') : $r('app.string.mindmap_rendering'))
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

      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(8) } }) {
        Button($r('app.string.mindmap_reset_view'))
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.primary_text'))
          .onClick(() => {
            this.resetView();
          })
        Button($r('app.string.mindmap_fold_panel'))
          .backgroundColor(this.showFoldPanel ? $r('app.color.brand') : $r('app.color.card_background'))
          .fontColor(this.showFoldPanel ? Color.White : $r('app.color.primary_text'))
          .onClick(() => {
            this.showFoldPanel = !this.showFoldPanel;
          })
        Button($r('app.string.mindmap_export_xmind'))
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.primary_text'))
          .onClick(() => {
            this.exportXmind();
          })
        Button($r('app.string.mindmap_export_png'))
          .backgroundColor($r('app.color.brand'))
          .fontColor(Color.White)
          .onClick(() => {
            this.exportPng();
          })
      }
      .width('100%')

      Text(this.isCustom ? $r('app.string.mindmap_custom_note') : $r('app.string.mindmap_demo_note'))
        .fontSize(11)
        .fontColor($r('app.color.hint_text'))
        .padding({ bottom: 8 })
    }
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
