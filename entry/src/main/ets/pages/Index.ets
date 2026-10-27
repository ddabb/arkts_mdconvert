import { ConvertPanel } from '../components/ConvertPanel';
import { HistoryPanel } from '../components/HistoryPanel';
import { SettingsPanel } from '../components/SettingsPanel';

@Entry
@Component
struct Index {
  @State tabIdx: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.tabIdx }) {
      TabContent() {
        ConvertPanel()
      }
      .tabBar($r('app.string.tab_convert'))

      TabContent() {
        HistoryPanel({
          requestConvert: () => {
            this.tabIdx = 0;
          }
        })
      }
      .tabBar($r('app.string.tab_history'))

      TabContent() {
        SettingsPanel()
      }
      .tabBar($r('app.string.tab_settings'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .onChange((index: number) => {
      this.tabIdx = index;
    })
  }
}
