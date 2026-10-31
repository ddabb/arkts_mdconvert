import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DocxOptions } from './DocxOut';

export class SettingsStore {
  private static readonly STORE_NAME: string = 'mdc_settings';
  private static readonly KEY_INDENT: string = 'docx.firstLineIndent';
  private static readonly KEY_HEADING_NUMBERS: string = 'docx.headingNumbers';
  private static readonly KEY_TOC: string = 'docx.toc';
  private static readonly KEY_PAGE_NUMBERS: string = 'docx.pageNumbers';
  private static readonly KEY_EMBED_IMAGES: string = 'docx.embedImages';
  private static store: preferences.Preferences | undefined = undefined;
  private static opts: DocxOptions | undefined = undefined;

  static ensure(ctx: common.Context): void {
    if (SettingsStore.opts !== undefined) {
      return;
    }
    const o: DocxOptions = new DocxOptions();
    try {
      const p: preferences.Preferences = preferences.getPreferencesSync(ctx, { name: SettingsStore.STORE_NAME });
      const vIndent: preferences.ValueType = p.getSync(SettingsStore.KEY_INDENT, true);
      o.firstLineIndent = typeof vIndent === 'boolean' ? vIndent : true;
      const vNum: preferences.ValueType = p.getSync(SettingsStore.KEY_HEADING_NUMBERS, false);
      o.headingNumbers = typeof vNum === 'boolean' ? vNum : false;
      const vToc: preferences.ValueType = p.getSync(SettingsStore.KEY_TOC, false);
      o.toc = typeof vToc === 'boolean' ? vToc : false;
      const vPage: preferences.ValueType = p.getSync(SettingsStore.KEY_PAGE_NUMBERS, false);
      o.pageNumbers = typeof vPage === 'boolean' ? vPage : false;
      const vImg: preferences.ValueType = p.getSync(SettingsStore.KEY_EMBED_IMAGES, true);
      o.embedImages = typeof vImg === 'boolean' ? vImg : true;
      SettingsStore.store = p;
    } catch (err) {
      SettingsStore.store = undefined;
    }
    SettingsStore.opts = o;
  }

  static docxOptions(): DocxOptions {
    return SettingsStore.opts !== undefined ? SettingsStore.opts : new DocxOptions();
  }

  static saveDocxOptions(o: DocxOptions): void {
    SettingsStore.opts = o;
    const p: preferences.Preferences | undefined = SettingsStore.store;
    if (p === undefined) {
      return;
    }
    try {
      p.putSync(SettingsStore.KEY_INDENT, o.firstLineIndent);
      p.putSync(SettingsStore.KEY_HEADING_NUMBERS, o.headingNumbers);
      p.putSync(SettingsStore.KEY_TOC, o.toc);
      p.putSync(SettingsStore.KEY_PAGE_NUMBERS, o.pageNumbers);
      p.putSync(SettingsStore.KEY_EMBED_IMAGES, o.embedImages);
      p.flush().catch(() => {
      });
    } catch (err) {
    }
  }
}
