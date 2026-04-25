import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { CoreUtil } from '../common/CoreUtil';
import { UiStyle } from '../common/UiStyle';
import { FeedConfig } from '../model/DataModels';

/**
 * 编辑订阅源页面 - 替代 Android EditFeedActivity
 * HarmonyOS 6: 使用 NavDestination 作为导航目的地
 */
@Component
export struct EditFeedPageContent {
  @State feeds: FeedConfig[] = [];
  @State showAddDialog: boolean = false;
  @State newFeedName: string = '';
  @State newFeedUrl: string = '';
  @State newFeedType: number = 0; // 0: remote, 1: internet
  @State showEditDialog: boolean = false;
  @State editFeedIndex: number = -1;
  @State editFeedName: string = '';
  @State editFeedUrl: string = '';
  @Consume('navPathStack') navPathStack: NavPathStack;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private coreUtil: CoreUtil = new CoreUtil(this.context);
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
    this.resetAddFeedForm();
    await this.loadFeeds();
    promptAction.showToast({ message: $r('app.string.succeed') });
  }

  private getFeedUrl(feed: FeedConfig): string {
    return feed.feed_type === 'internet' ? (feed.api_url ?? feed.feed_url ?? '') : (feed.feed_url ?? feed.feed_path ?? '');
  }

  private resetAddFeedForm(): void {
    this.newFeedName = '';
    this.newFeedUrl = '';
    this.newFeedType = 0;
  }

  private resetEditFeedForm(): void {
    this.editFeedIndex = -1;
    this.editFeedName = '';
    this.editFeedUrl = '';
  }

  private showEditFeedDialog(index: number): void {
    const feed = this.feeds[index];
    this.editFeedIndex = index;
    this.editFeedName = feed.feed_name;
    this.editFeedUrl = this.getFeedUrl(feed);
    this.showEditDialog = true;
  }

  private async saveEditFeed(): Promise<void> {
    if (this.editFeedIndex < 0) {
      return;
    }
    if (this.editFeedName.trim() === '') {
      promptAction.showToast({ message: '请输入订阅源名称' });
      return;
    }
    if (this.editFeedUrl.trim() === '') {
      promptAction.showToast({ message: '请输入订阅源地址' });
      return;
    }
    await this.coreUtil.updateFeed(this.editFeedIndex, this.editFeedName.trim(), this.editFeedUrl.trim());
    this.showEditDialog = false;
    this.resetEditFeedForm();
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
      .height(UiStyle.HEADER_ROW_HEIGHT)
      .padding({ left: UiStyle.PAGE_SIDE, right: UiStyle.PAGE_SIDE })

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

                Text(this.getFeedUrl(item))
                  .fontSize(12)
                  .fontColor($r('app.color.colorText4'))
                  .margin({ top: 4 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row() {
                  Text(item.feed_type === 'remote' ? '远程' : item.feed_type === 'internet' ? 'API' : '本地')
                    .fontSize(11)
                    .fontColor(Color.White)
                    .backgroundColor(item.feed_type === 'internet' ? UiStyle.TAG_GREEN : UiStyle.TAG_BLUE)
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
                .fillColor(UiStyle.DANGER)
                .onClick(() => {
                  this.deleteFeed(index);
                })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 16 })
            .backgroundColor($r('app.color.colorCard'))
            .borderRadius(UiStyle.DIALOG_RADIUS)
            .shadow({ radius: 18, color: UiStyle.CARD_SHADOW, offsetX: 0, offsetY: 8 })
            .gesture(
              LongPressGesture()
                .onAction(() => {
                  this.showEditFeedDialog(index);
                })
            )
          }
          .margin({ left: 18, right: 18, top: 12 })
        }, (item: FeedConfig, index: number) => `${index}-${item.feed_name}-${this.getFeedUrl(item)}`)
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
                  this.resetAddFeedForm();
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
          .borderRadius(UiStyle.DIALOG_RADIUS)
          .shadow({ radius: 22, color: UiStyle.CARD_SHADOW, offsetX: 0, offsetY: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(UiStyle.OVERLAY_BG)
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAddDialog = false;
          this.resetAddFeedForm();
        })
      }
      if (this.showEditDialog) {
        Column() {
          Column() {
            Text('编辑订阅源')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.colorText1'))
              .width('100%')
              .margin({ bottom: 16 })

            TextInput({ placeholder: '订阅源名称', text: this.editFeedName })
              .width('100%')
              .height(44)
              .fontSize(14)
              .margin({ bottom: 12 })
              .onChange((value: string) => {
                this.editFeedName = value;
              })

            TextInput({ placeholder: '订阅源地址', text: this.editFeedUrl })
              .width('100%')
              .height(44)
              .fontSize(14)
              .margin({ bottom: 20 })
              .onChange((value: string) => {
                this.editFeedUrl = value;
              })

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
                  this.showEditDialog = false;
                  this.resetEditFeedForm();
                })

              Button('保存')
                .type(ButtonType.Normal)
                .borderRadius(5)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.colorPrimary'))
                .height(40)
                .layoutWeight(1)
                .margin({ left: 12 })
                .onClick(() => {
                  this.saveEditFeed();
                })
            }
            .width('100%')
          }
          .width('90%')
          .padding(24)
          .backgroundColor($r('app.color.colorCard'))
          .borderRadius(UiStyle.DIALOG_RADIUS)
          .shadow({ radius: 22, color: UiStyle.CARD_SHADOW, offsetX: 0, offsetY: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(UiStyle.OVERLAY_BG)
        .position({ x: 0, y: 0 })
      }
      }
      .width('100%')
      .height('100%')
      .padding({ top: UiStyle.PAGE_TOP })
      .backgroundColor(UiStyle.PAGE_BG)
    }
    .hideTitleBar(true)
  }
}
