import { common } from '@kit.AbilityKit';
import { DocxOptions } from '../core/DocxOut';
import { SettingsStore } from '../core/SettingsStore';

@Component
export struct SettingsPanel {
  @State docxIndent: boolean = true;
  @State docxHeadingNum: boolean = false;
  @State docxToc: boolean = false;
  @State docxPageNum: boolean = false;
  @State docxEmbed: boolean = true;

  aboutToAppear(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    try {
      SettingsStore.ensure(ctx);
      const saved: DocxOptions = SettingsStore.docxOptions();
      this.docxIndent = saved.firstLineIndent;
      this.docxHeadingNum = saved.headingNumbers;
      this.docxToc = saved.toc;
      this.docxPageNum = saved.pageNumbers;
      this.docxEmbed = saved.embedImages;
    } catch (err) {
    }
  }

  private saveDocx(): void {
    const ctx: common.Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    try {
      SettingsStore.ensure(ctx);
      const o: DocxOptions = new DocxOptions();
      o.firstLineIndent = this.docxIndent;
      o.headingNumbers = this.docxHeadingNum;
      o.toc = this.docxToc;
      o.pageNumbers = this.docxPageNum;
      o.embedImages = this.docxEmbed;
      SettingsStore.saveDocxOptions(o);
    } catch (err) {
    }
  }

  @Builder
  docxRow(label: ResourceStr, isOn: boolean, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.primary_text'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((value: boolean) => {
          onTap();
        })
    }
    .width('100%')
  }

  @Builder
  infoCard(title: ResourceStr, body: ResourceStr) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
      Text(body)
        .fontSize(13)
        .fontColor($r('app.color.secondary_text'))
        .lineHeight(20)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 10 }) {
          Text($r('app.string.app_name'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text'))
          Text($r('app.string.app_tagline'))
            .fontSize(13)
            .fontColor($r('app.color.secondary_text'))
          Row({ space: 8 }) {
            Text($r('app.string.buyout_note'))
              .fontSize(11)
              .fontColor($r('app.color.brand'))
              .backgroundColor($r('app.color.brand_tint'))
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            Text($r('app.string.offline_note'))
              .fontSize(11)
              .fontColor($r('app.color.brand'))
              .backgroundColor($r('app.color.brand_tint'))
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(16)
        .alignItems(HorizontalAlign.Start)

        this.infoCard($r('app.string.settings_dark_title'), $r('app.string.settings_dark_note'))
        this.infoCard($r('app.string.settings_privacy_title'), $r('app.string.settings_privacy_desc'))
        this.infoCard($r('app.string.settings_buyout_title'), $r('app.string.settings_buyout_desc'))

        Column({ space: 12 }) {
          Text($r('app.string.settings_docx_title'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text'))
          this.docxRow($r('app.string.settings_docx_indent'), this.docxIndent, () => {
            this.docxIndent = !this.docxIndent;
            this.saveDocx();
          })
          this.docxRow($r('app.string.settings_docx_heading_num'), this.docxHeadingNum, () => {
            this.docxHeadingNum = !this.docxHeadingNum;
            this.saveDocx();
          })
          this.docxRow($r('app.string.settings_docx_toc'), this.docxToc, () => {
            this.docxToc = !this.docxToc;
            this.saveDocx();
          })
          this.docxRow($r('app.string.settings_docx_page_num'), this.docxPageNum, () => {
            this.docxPageNum = !this.docxPageNum;
            this.saveDocx();
          })
          this.docxRow($r('app.string.settings_docx_embed'), this.docxEmbed, () => {
            this.docxEmbed = !this.docxEmbed;
            this.saveDocx();
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(16)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 6 }) {
          Text($r('app.string.version_label'))
            .fontSize(12)
            .fontColor($r('app.color.hint_text'))
          Text($r('app.string.version_value'))
            .fontSize(12)
            .fontColor($r('app.color.secondary_text'))
        }
        .padding({ top: 4, bottom: 20 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('app.color.page_background'))
  }
}
