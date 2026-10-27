const PREVIEW_LINES: number = 400;

@Component
export struct CodePreview {
  @Prop text: string = '';
  @Prop lang: string = 'text';

  private lines(): string[] {
    const all: string[] = this.text.split('\n');
    return all.length > PREVIEW_LINES ? all.slice(0, PREVIEW_LINES) : all;
  }

  private lineColor(line: string): ResourceColor {
    const trimmed: string = line.trim();
    if (this.lang == 'json') {
      if (trimmed.startsWith('"') && trimmed.includes('":')) {
        return $r('app.color.brand');
      }
      if (trimmed.startsWith('"')) {
        return $r('app.color.success_green');
      }
      if (trimmed.length > 0 && trimmed.charAt(0) >= '0' && trimmed.charAt(0) <= '9') {
        return $r('app.color.accent');
      }
      if (trimmed == 'true' || trimmed == 'false' || trimmed == 'null') {
        return $r('app.color.accent');
      }
      return $r('app.color.secondary_text');
    }
    if (this.lang == 'yaml') {
      if (trimmed.startsWith('- ')) {
        return $r('app.color.accent');
      }
      const colon: number = trimmed.indexOf(':');
      if (colon > 0) {
        return $r('app.color.brand');
      }
      return $r('app.color.secondary_text');
    }
    return $r('app.color.secondary_text');
  }

  build() {
    Scroll() {
      Column() {
        ForEach(this.lines(), (line: string, idx: number) => {
          Text(line.length > 0 ? line : ' ')
            .fontSize(11)
            .fontFamily('monospace')
            .fontColor(this.lineColor(line))
            .width('100%')
        }, (line: string, idx: number) => `${idx}`)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(8)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor($r('app.color.page_background'))
    .borderRadius(10)
  }
}
