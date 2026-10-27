import { OutlineItem } from '../core/OutlineOut';

@Component
export struct OutlineTree {
  @Prop items: OutlineItem[] = [];

  build() {
    if (this.items.length == 0) {
      Column() {
        Text($r('app.string.convert_outline_empty'))
          .fontSize(13)
          .fontColor($r('app.color.hint_text'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.page_background'))
      .borderRadius(10)
    } else {
      Scroll() {
        Column({ space: 3 }) {
          ForEach(this.items, (item: OutlineItem, idx: number) => {
            Text(item.text)
              .fontSize(item.strong ? 14 : 12)
              .fontWeight(item.strong ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(item.strong ? $r('app.color.primary_text') : $r('app.color.secondary_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: item.depth * 16 + 6, right: 6 })
              .width('100%')
          }, (item: OutlineItem, idx: number) => `${idx}-${item.text}`)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .backgroundColor($r('app.color.page_background'))
      .borderRadius(10)
    }
  }
}
