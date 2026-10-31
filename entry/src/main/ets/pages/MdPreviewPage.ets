import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';
import { pasteboard } from '@kit.BasicServicesKit';

const DEMO_MD: string = [
  '# MdConvert 渲染预览',
  '',
  '> 想让文字像在原生世界里呼吸，就得从**渲染**开始。',
  '',
  '## 格式转换矩阵',
  '',
  '| 输入 | 输出 | 说明 |',
  '| --- | --- | --- |',
  '| Markdown | JSON | 结构化数据 |',
  '| Markdown | YAML | 配置友好 |',
  '| Markdown | Word | .docx 文档 |',
  '| Markdown | 思维导图 | PNG / .mm / .opml |',
  '',
  '## 任务规划',
  '',
  '- [x] 自研受控 MD 解析器',
  '- [x] 思维导图三主题渲染',
  '- [ ] 批量转换',
  '- [ ] 文件选择接入',
  '',
  '## 代码块示例',
  '',
  '```json',
  '{',
  '  "app": "MarkDown转换器",',
  '  "offline": true,',
  '  "formats": ["json", "yaml", "docx", "mindmap"]',
  '}',
  '```',
  '',
  '## 特性',
  '',
  '*鸿蒙原生* 离线渲染，支持**表格**、`行内代码`、***混合强调*** 与任务列表。'
].join('\n');

@Entry
@Component
struct MdPreviewPage {
  private controller: MarkdownController = new MarkdownController();

  aboutToAppear(): void {
    this.controller
      .setTextColor($r('app.color.primary_text'))
      .setTitleColor($r('app.color.primary_text'))
      .setQuoteBackgroundColor($r('app.color.page_background'))
      .setQuoteBorderColor($r('app.color.brand'))
      .setQuoteTextColor($r('app.color.secondary_text'))
      .setInlineCodeColor($r('app.color.brand'))
      .setInlineCodeBackgroundColor($r('app.color.page_background'))
      .setCodeBlockTheme('light')
      .setCodeCopyListener((text: string) => {
        const data: pasteboard.PasteData =
          pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
        pasteboard.getSystemPasteboard().setData(data).then(() => {
          this.getUIContext().getPromptAction().showToast({
            message: $r('app.string.md_preview_copy_done'),
            duration: 1500
          });
        });
      });
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 10 }) {
        Text($r('app.string.md_preview_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
        Text($r('app.string.md_preview_entry_desc'))
          .fontSize(13)
          .fontColor($r('app.color.secondary_text'))
      }
      .width('100%')
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Scroll() {
        Markdown({
          controller: this.controller,
          text: DEMO_MD,
          mode: 'text'
        })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor($r('app.color.page_background'))

      Text($r('app.string.md_preview_demo_note'))
        .fontSize(11)
        .fontColor($r('app.color.hint_text'))
        .padding({ bottom: 8 })
    }
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
