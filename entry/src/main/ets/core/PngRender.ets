import { drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { MindNode, MindTreeBuilder } from './MindmapTree';
import { MindLayout, MindLayoutItem, MindRect, MindmapLayout, MindMetrics } from './MindmapLayout';
import { MindTheme } from './MindmapTheme';

class RenderMetrics extends MindMetrics {
  readonly font: drawing.Font;

  constructor(size: number) {
    super();
    this.font = new drawing.Font();
    this.font.setSize(size);
    this.font.setEdging(drawing.FontEdging.ANTI_ALIAS);
  }

  textWidth(text: string): number {
    return this.font.measureText(text, drawing.TextEncoding.TEXT_ENCODING_UTF8);
  }
}

class RenderCtx {
  readonly theme: MindTheme;
  readonly font: drawing.Font;
  readonly bgBrush: drawing.Brush;
  readonly rootFillBrush: drawing.Brush;
  readonly nodeFillBrush: drawing.Brush;
  readonly rootTextBrush: drawing.Brush;
  readonly nodeTextBrush: drawing.Brush;
  readonly nodePen: drawing.Pen;
  readonly linePen: drawing.Pen;

  constructor(theme: MindTheme, font: drawing.Font) {
    this.theme = theme;
    this.font = font;
    this.bgBrush = RenderCtx.brush(theme.bg);
    this.rootFillBrush = RenderCtx.brush(theme.rootFill);
    this.nodeFillBrush = RenderCtx.brush(theme.nodeFill);
    this.rootTextBrush = RenderCtx.brush(theme.rootText);
    this.nodeTextBrush = RenderCtx.brush(theme.nodeText);
    this.nodePen = RenderCtx.pen(theme.nodeStroke, 1);
    this.linePen = RenderCtx.pen(theme.branches[0], 2);
  }

  static brush(hex: string): drawing.Brush {
    const b: drawing.Brush = new drawing.Brush();
    b.setColor(PngRender.color(hex));
    return b;
  }

  static pen(hex: string, width: number): drawing.Pen {
    const p: drawing.Pen = new drawing.Pen();
    p.setAntiAlias(true);
    p.setStrokeWidth(width);
    p.setColor(PngRender.color(hex));
    return p;
  }
}

export class MindRenderResult {
  readonly pixelMap: image.PixelMap;
  readonly width: number;
  readonly height: number;
  readonly scale: number;
  readonly nodeCount: number;

  constructor(pixelMap: image.PixelMap, width: number, height: number,
    scale: number, nodeCount: number) {
    this.pixelMap = pixelMap;
    this.width = width;
    this.height = height;
    this.scale = scale;
    this.nodeCount = nodeCount;
  }
}

export class PngRender {
  static readonly MAX_SIDE: number = 4096;
  static readonly FONT_SIZE: number = 16;
  static readonly ROOT_RADIUS: number = 18;
  static readonly NODE_RADIUS: number = 10;
  static readonly LINE_W: number = 2;

  static async render(src: string, theme: MindTheme,
    maxChildren: number): Promise<MindRenderResult> {
    const metrics: RenderMetrics = new RenderMetrics(PngRender.FONT_SIZE);
    const root: MindNode = MindTreeBuilder.buildSrc(src, maxChildren);
    const layout: MindLayout = MindmapLayout.layout(root, metrics);
    const longest: number = Math.max(layout.width, layout.height);
    const scale: number = Math.min(1, PngRender.MAX_SIDE / longest);
    const w: number = Math.max(1, Math.round(layout.width * scale));
    const h: number = Math.max(1, Math.round(layout.height * scale));
    const buf: ArrayBuffer = new ArrayBuffer(w * h * 4);
    const size: image.Size = { width: w, height: h };
    const opts: image.InitializationOptions = {
      size: size,
      pixelFormat: image.PixelMapFormat.RGBA_8888
    };
    const pm: image.PixelMap = await image.createPixelMap(buf, opts);
    const canvas: drawing.Canvas = new drawing.Canvas(pm);
    if (scale < 1) {
      canvas.scale(scale, scale);
    }
    const ctx: RenderCtx = new RenderCtx(theme, metrics.font);
    PngRender.paintBackground(canvas, layout, ctx);
    PngRender.paintConnectors(canvas, layout, ctx);
    for (const item of layout.items) {
      PngRender.paintNode(canvas, item, ctx);
    }
    return new MindRenderResult(pm, w, h, scale, layout.items.length);
  }

  static async renderBytes(src: string, theme: MindTheme,
    maxChildren: number): Promise<Uint8Array> {
    const result: MindRenderResult = await PngRender.render(src, theme, maxChildren);
    const bytes: Uint8Array = await PngRender.toPngBytes(result);
    await result.pixelMap.release();
    return bytes;
  }

  static async toPngBytes(result: MindRenderResult): Promise<Uint8Array> {
    const packer: image.ImagePacker = image.createImagePacker();
    const opt: image.PackingOption = { format: 'image/png', quality: 100 };
    const data: ArrayBuffer = await packer.packToData(result.pixelMap, opt);
    await packer.release();
    return new Uint8Array(data);
  }

  static color(hex: string): common2D.Color {
    const h: string = hex.startsWith('#') ? hex.substring(1) : hex;
    const v: number = parseInt(h, 16);
    const c: common2D.Color = {
      alpha: 255,
      red: (v >> 16) & 0xFF,
      green: (v >> 8) & 0xFF,
      blue: v & 0xFF
    };
    return c;
  }

  static paintBackground(canvas: drawing.Canvas, layout: MindLayout, ctx: RenderCtx): void {
    canvas.attachBrush(ctx.bgBrush);
    const rect: common2D.Rect = {
      left: 0,
      top: 0,
      right: layout.width,
      bottom: layout.height
    };
    canvas.drawRect(rect);
    canvas.detachBrush();
  }

  static paintConnectors(canvas: drawing.Canvas, layout: MindLayout, ctx: RenderCtx): void {
    canvas.attachPen(ctx.linePen);
    for (const item of layout.items) {
      const parent: MindLayoutItem | undefined = item.parent;
      if (parent === undefined) {
        continue;
      }
      ctx.linePen.setColor(PngRender.color(ctx.theme.branchColor(item.depth)));
      const pr: MindRect = parent.rect;
      const r: MindRect = item.rect;
      const sy: number = pr.y + pr.h / 2;
      const ey: number = r.y + r.h / 2;
      let sx: number = 0;
      let ex: number = 0;
      if (item.side == 1) {
        sx = pr.x + pr.w;
        ex = r.x;
      } else {
        sx = pr.x;
        ex = r.x + r.w;
      }
      const midX: number = (sx + ex) / 2;
      const path: drawing.Path = new drawing.Path();
      path.moveTo(sx, sy);
      path.cubicTo(midX, sy, midX, ey, ex, ey);
      canvas.drawPath(path);
    }
    canvas.detachPen();
  }

  static paintNode(canvas: drawing.Canvas, item: MindLayoutItem, ctx: RenderCtx): void {
    const isRoot: boolean = item.depth == 0;
    const r: MindRect = item.rect;
    const radius: number = isRoot ? PngRender.ROOT_RADIUS : PngRender.NODE_RADIUS;
    const rect: common2D.Rect = {
      left: r.x,
      top: r.y,
      right: r.x + r.w,
      bottom: r.y + r.h
    };
    const round: drawing.RoundRect = new drawing.RoundRect(rect, radius, radius);
    canvas.attachBrush(isRoot ? ctx.rootFillBrush : ctx.nodeFillBrush);
    if (!isRoot) {
      canvas.attachPen(ctx.nodePen);
    }
    canvas.drawRoundRect(round);
    if (!isRoot) {
      canvas.detachPen();
    }
    canvas.detachBrush();
    canvas.attachBrush(isRoot ? ctx.rootTextBrush : ctx.nodeTextBrush);
    PngRender.paintText(canvas, item.node.text, r, ctx.font);
    canvas.detachBrush();
  }

  static paintText(canvas: drawing.Canvas, text: string, r: MindRect,
    font: drawing.Font): void {
    const fm: drawing.FontMetrics = font.getMetrics();
    const baseline: number = r.y + r.h / 2 - (fm.ascent + fm.descent) / 2;
    const tw: number = font.measureText(text, drawing.TextEncoding.TEXT_ENCODING_UTF8);
    const x: number = r.x + (r.w - tw) / 2;
    const blob: drawing.TextBlob = drawing.TextBlob.makeFromString(
      text, font, drawing.TextEncoding.TEXT_ENCODING_UTF8);
    canvas.drawTextBlob(blob, x, baseline);
  }
}
