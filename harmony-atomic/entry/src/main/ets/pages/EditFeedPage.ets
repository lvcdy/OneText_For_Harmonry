import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { CoreUtil } from '../common/CoreUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { FeedConfig } from '../model/DataModels';

/**
 * 编辑订阅源页面 - 元服务版
 * 使用 NavDestination 作为导航目的地
 */
@Component
export struct EditFeedPageContent {
  @State feeds: FeedConfig[] = [];
  @State showAddDialog: boolean = false;
  @State newFeedName: string = '';
  @State newFeedUrl: string = '';
  @State newFeedType: number = 0; // 0: remote, 1: internet
  @Consume('navPathStack') navPathStack: NavPathStack;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private coreUtil: CoreUtil = new CoreUtil(this.context);
  private prefs: PreferencesUtil = PreferencesUtil.getInstance();
  private feedTypes: string[] = ['远程 JSON', 'API 接口'];

  async aboutToAppear(): Promise<void> {
    await this.loadFeeds();
  }

  private async loadFeeds(): Promise<void> {
    this.feeds = this.coreUtil.getAllFeeds();
  }

  private async deleteFeed(index: number): Promise<void> {
    if (this.feeds.length <= 1) {
      promptAction.showToast({ message: '至少保留一个订阅源' });
      return;
    }
    AlertDialog.show({
      title: '删除订阅源',
      message: `确定要删除 "${this.feeds[index].feed_name}" 吗？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          await this.coreUtil.deleteFeed(index);
          await this.loadFeeds();
          promptAction.showToast({ message: $r('app.string.delete_succeed') });
        }
      }
    });
  }

  private async addFeed(): Promise<void> {
    if (this.newFeedName.trim() === '') {
      promptAction.showToast({ message: '请输入订阅源名称' });
      return;
    }
    if (this.newFeedUrl.trim() === '') {
      promptAction.showToast({ message: '请输入订阅源地址' });
      return;
    }
    const feedType = this.newFeedType === 0 ? 'remote' : 'internet';
    await this.coreUtil.addFeed(this.newFeedName.trim(), feedType, this.newFeedUrl.trim());
    this.showAddDialog = false;
    this.newFeedName = '';
    this.newFeedUrl = '';
    await this.loadFeeds();
    promptAction.showToast({ message: $r('app.string.succeed') });
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部标题栏
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.navPathStack.pop();
            })

        Text($r('app.string.feed_edit'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.colorText1'))
          .margin({ left: 16 })

        Blank()

        Image($r('app.media.ic_add'))
          .width(24)
          .height(24)
          .onClick(() => {
            this.showAddDialog = true;
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // 订阅源列表
      List() {
        ForEach(this.feeds, (item: FeedConfig, index: number) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.feed_name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.colorText1'))

                Text(item.feed_type === 'internet' ? (item.api_url ?? '') : (item.feed_url ?? item.feed_path ?? ''))
                  .fontSize(12)
                  .fontColor($r('app.color.colorText4'))
                  .margin({ top: 4 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row() {
                  Text(item.feed_type === 'remote' ? '远程' : item.feed_type === 'internet' ? 'API' : '本地')
                    .fontSize(11)
                    .fontColor(Color.White)
                    .backgroundColor(item.feed_type === 'internet' ? '#4CAF50' : '#2196F3')
                    .borderRadius(4)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .margin({ top: 6 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Image($r('app.media.ic_delete'))
                .width(20)
                .height(20)
                .fillColor('#FF5252')
                .onClick(() => {
                  this.deleteFeed(index);
                })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 16 })
            .backgroundColor($r('app.color.colorCard'))
            .borderRadius(22)
            .shadow({ radius: 18, color: '#10000000', offsetX: 0, offsetY: 8 })
          }
          .margin({ left: 18, right: 18, top: 12 })
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 8, bottom: 24 })
      .scrollBar(BarState.Off)

      // 添加订阅源对话框
      if (this.showAddDialog) {
        Column() {
          Column() {
            Text('添加订阅源')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.colorText1'))
              .width('100%')
              .margin({ bottom: 16 })

            // 类型选择
            Row() {
              Text('类型')
                .fontSize(14)
                .fontColor($r('app.color.colorText2'))
                .width(60)
              Select(this.feedTypes.map((item: string) => ({ value: item } as SelectOption)))
                .selected(this.newFeedType)
                .value(this.feedTypes[this.newFeedType])
                .font({ size: 14 })
                .onSelect((index: number) => {
                  this.newFeedType = index;
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            // 名称输入
            TextInput({ placeholder: '订阅源名称', text: this.newFeedName })
              .width('100%')
              .height(44)
              .fontSize(14)
              .margin({ bottom: 12 })
              .onChange((value: string) => {
                this.newFeedName = value;
              })

            // URL 输入
            TextInput({ placeholder: this.newFeedType === 0 ? 'JSON 文件 URL' : 'API 接口 URL', text: this.newFeedUrl })
              .width('100%')
              .height(44)
              .fontSize(14)
              .margin({ bottom: 20 })
              .onChange((value: string) => {
                this.newFeedUrl = value;
              })

            // 按钮行
            Row() {
              Button('取消')
                .type(ButtonType.Normal)
                .borderRadius(5)
                .fontSize(14)
                .fontColor($r('app.color.colorText2'))
                .backgroundColor(Color.Transparent)
                .border({ width: 1.05, color: $r('app.color.colorMD2BG') })
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.showAddDialog = false;
                  this.newFeedName = '';
                  this.newFeedUrl = '';
                })

              Button('添加')
                .type(ButtonType.Normal)
                .borderRadius(5)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.colorPrimary'))
                .height(40)
                .layoutWeight(1)
                .margin({ left: 12 })
                .onClick(() => {
                  this.addFeed();
                })
            }
            .width('100%')
          }
          .width('90%')
          .padding(24)
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(24)
          .shadow({ radius: 22, color: '#24000000', offsetX: 0, offsetY: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#80000000')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAddDialog = false;
        })
      }
      }
      .width('100%')
      .height('100%')
      .padding({ top: 36 })
      .backgroundColor($r('app.color.colorBackground'))
    }
    .hideTitleBar(true)
  }
}
