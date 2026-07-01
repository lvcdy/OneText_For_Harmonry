import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { CoreUtil } from '../common/CoreUtil';
import { AppBackgroundLayer } from '../common/AppBackgroundUtil';
import { UiStyle } from '../common/UiStyle';
import { FeedConfig } from '../model/DataModels';

const EDIT_FEED_RESPONSIVE_WIDE_WIDTH: number = 720;
const EDIT_FEED_CONTENT_MAX_WIDTH_COMPACT: number = 560;
const EDIT_FEED_CONTENT_MAX_WIDTH_WIDE: number = 760;
const FEED_CONFIG_UPDATED_AT_KEY: string = 'feedConfigUpdatedAt';

/**
 * 编辑订阅源页面 - 替代 Android EditFeedActivity
 * HarmonyOS 7: 使用 NavDestination 作为导航目的地
 */
@Component
export struct EditFeedPageContent {
  @Env(SystemProperties.WINDOW_AVOID_AREA) avoidAreas!: window.UIEnvWindowAvoidAreaInfoVP
  @State statusBarHeight: number = 0;
  @State feeds: FeedConfig[] = [];
  @State showAddDialog: boolean = false;
  @State newFeedName: string = '';
  @State newFeedUrl: string = '';
  @State newFeedType: number = 0; // 0: remote, 1: internet, 2: local
  @State newShowAdvanced: boolean = false;
  @State newApiMethodIndex: number = 0;
  @State newTextKey: string = 'text';
  @State newByKey: string = 'by';
  @State newFromKey: string = 'from';
  @State newTimeKey: string = 'time';
  @State newUriKey: string = 'uri';
  @State newObjectKey: string = '';
  @State showEditDialog: boolean = false;
  @State editFeedIndex: number = -1;
  @State editFeedName: string = '';
  @State editFeedUrl: string = '';
  @State editShowAdvanced: boolean = false;
  @State editApiMethodIndex: number = 0;
  @State editTextKey: string = 'text';
  @State editByKey: string = 'by';
  @State editFromKey: string = 'from';
  @State editTimeKey: string = 'time';
  @State editUriKey: string = 'uri';
  @State editObjectKey: string = '';
  @State pageWidth: number = 0;
  @State feedIndexes: number[] = [];
  @Consume('navPathStack') navPathStack: NavPathStack;

  private context!: common.UIAbilityContext;
  private coreUtil!: CoreUtil;
  private feedTypes: string[] = ['远程 JSON', 'API 接口', '本地文件'];
  private apiMethods: string[] = ['GET', 'POST'];

  private isWideLayout(): boolean {
    return this.pageWidth >= EDIT_FEED_RESPONSIVE_WIDE_WIDTH;
  }

  private getContentMaxWidth(): number {
    return this.isWideLayout() ? EDIT_FEED_CONTENT_MAX_WIDTH_WIDE : EDIT_FEED_CONTENT_MAX_WIDTH_COMPACT;
  }

  /**
   * 获取状态栏高度（vp），优先使用窗口API，回退到@Env
   */
  private getStatusBarHeight(): number {
    if (this.statusBarHeight > 0) {
      return this.statusBarHeight;
    }
    const statusBarHeightPx: number = this.avoidAreas.statusBar?.topRect?.height ?? 0;
    return statusBarHeightPx > 0 ? this.getUIContext().px2vp(statusBarHeightPx) : 44;
  }

  private getGlassCardColor(): ResourceColor {
    return $r('app.color.colorGlassCard');
  }

  private getGlassCardBorder(): ResourceColor {
    return $r('app.color.colorGlassBorder');
  }

  private getGlassControlColor(): ResourceColor {
    return $r('app.color.colorGlassControl');
  }

  private getGlassShadowColor(): ResourceColor {
    return $r('app.color.colorGlassShadow');
  }

  async aboutToAppear(): Promise<void> {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.coreUtil = new CoreUtil(this.context);

    // 获取状态栏高度（窗口API，比@Env更可靠）
    try {
      const win = await window.getLastWindow(this.context);
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = this.getUIContext().px2vp(avoidArea.topRect.height);
    } catch (e) {
      console.warn('EditFeedPage', `get status bar height failed: ${JSON.stringify(e)}`);
      this.statusBarHeight = 44;
    }

    this.loadFeeds();
  }

  private loadFeeds(): void {
    const allFeeds = this.coreUtil.getAllFeeds();
    const visibleFeeds: FeedConfig[] = [];
    const visibleIndexes: number[] = [];
    allFeeds.forEach((feed: FeedConfig, index: number) => {
      if (this.hasFeedAddress(feed)) {
        visibleFeeds.push(feed);
        visibleIndexes.push(index);
      }
    });
    this.feeds = visibleFeeds;
    this.feedIndexes = visibleIndexes;
  }

  private hasFeedAddress(feed: FeedConfig): boolean {
    if (feed.feed_type === CoreUtil.FEED_TYPE_INTERNET) {
      return (feed.api_url ?? feed.feed_url ?? '').trim() !== '';
    }
    if (feed.feed_type === CoreUtil.FEED_TYPE_LOCAL) {
      return (feed.feed_path ?? '').trim() !== '';
    }
    return (feed.feed_url ?? '').trim() !== '';
  }

  private notifyFeedConfigUpdated(): void {
    AppStorage.setOrCreate<number>(FEED_CONFIG_UPDATED_AT_KEY, Date.now());
  }

  private async deleteFeed(index: number): Promise<void> {
    if (index < 0 || index >= this.feeds.length) {
      return;
    }
    const sourceIndex = this.feedIndexes[index] ?? index;
    this.getUIContext().showAlertDialog({
      title: '删除订阅源',
      message: `确定要删除 "${this.feeds[index].feed_name}" 吗？`,
      buttons: [
        {
          value: '取消',
          action: () => {
          }
        },
        {
          value: '删除',
          fontColor: Color.Red,
          action: async () => {
            await this.coreUtil.deleteFeed(sourceIndex);
            this.notifyFeedConfigUpdated();
            this.loadFeeds();
            this.getUIContext().getPromptAction().showToast({ message: $r('app.string.delete_succeed') });
          }
        }
      ]
    });
  }

  private async addFeed(): Promise<void> {
    if (this.newFeedName.trim() === '') {
      this.getUIContext().getPromptAction().showToast({ message: '请输入订阅源名称' });
      return;
    }
    if (this.newFeedUrl.trim() === '') {
      this.getUIContext().getPromptAction().showToast({ message: '请输入订阅源地址' });
      return;
    }
    const feedType = this.newFeedType === 1 ? CoreUtil.FEED_TYPE_INTERNET :
      (this.newFeedType === 2 ? CoreUtil.FEED_TYPE_LOCAL : CoreUtil.FEED_TYPE_REMOTE);
    await this.coreUtil.addFeed(this.newFeedName.trim(), feedType,
      feedType === CoreUtil.FEED_TYPE_LOCAL ? '' : this.newFeedUrl.trim(),
      feedType === CoreUtil.FEED_TYPE_LOCAL ? this.newFeedUrl.trim() : '',
      this.normalizeKey(this.newTextKey, 'text'), this.normalizeKey(this.newByKey, 'by'),
      this.normalizeKey(this.newFromKey, 'from'), this.normalizeKey(this.newTimeKey, 'time'),
      this.normalizeKey(this.newUriKey, 'uri'), this.newObjectKey.trim(), this.apiMethods[this.newApiMethodIndex]);
    this.notifyFeedConfigUpdated();
    this.showAddDialog = false;
    this.resetAddFeedForm();
    this.loadFeeds();
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.succeed') });
  }

  private getFeedUrl(feed: FeedConfig): string {
    return feed.feed_type === CoreUtil.FEED_TYPE_INTERNET ? (feed.api_url ?? feed.feed_url ?? '') :
      (feed.feed_url ?? feed.feed_path ?? '');
  }

  private getApiMethodIndex(feed: FeedConfig): number {
    return (feed.api_method ?? 'GET').toUpperCase() === 'POST' ? 1 : 0;
  }

  private getEditingFeedType(): string {
    if (this.editFeedIndex < 0 || this.editFeedIndex >= this.feeds.length) {
      return '';
    }
    return this.feeds[this.editFeedIndex].feed_type;
  }

  private normalizeKey(value: string, fallback: string): string {
    const trimmed = value.trim();
    return trimmed === '' ? fallback : trimmed;
  }

  private resetAddFeedForm(): void {
    this.newFeedName = '';
    this.newFeedUrl = '';
    this.newFeedType = 0;
    this.newShowAdvanced = false;
    this.newApiMethodIndex = 0;
    this.newTextKey = 'text';
    this.newByKey = 'by';
    this.newFromKey = 'from';
    this.newTimeKey = 'time';
    this.newUriKey = 'uri';
    this.newObjectKey = '';
  }

  private resetEditFeedForm(): void {
    this.editFeedIndex = -1;
    this.editFeedName = '';
    this.editFeedUrl = '';
    this.editShowAdvanced = false;
    this.editApiMethodIndex = 0;
    this.editTextKey = 'text';
    this.editByKey = 'by';
    this.editFromKey = 'from';
    this.editTimeKey = 'time';
    this.editUriKey = 'uri';
    this.editObjectKey = '';
  }

  private showEditFeedDialog(index: number): void {
    const feed = this.feeds[index];
    this.editFeedIndex = index;
    this.editFeedName = feed.feed_name;
    this.editFeedUrl = this.getFeedUrl(feed);
    this.editShowAdvanced = false;
    this.editApiMethodIndex = this.getApiMethodIndex(feed);
    this.editTextKey = feed.text_key ?? 'text';
    this.editByKey = feed.by_key ?? 'by';
    this.editFromKey = feed.from_key ?? 'from';
    this.editTimeKey = feed.time_key ?? 'time';
    this.editUriKey = feed.uri_key ?? 'uri';
    this.editObjectKey = feed.object_key ?? '';
    this.showEditDialog = true;
  }

  private async saveEditFeed(): Promise<void> {
    if (this.editFeedIndex < 0) {
      return;
    }
    if (this.editFeedName.trim() === '') {
      this.getUIContext().getPromptAction().showToast({ message: '请输入订阅源名称' });
      return;
    }
    if (this.editFeedUrl.trim() === '') {
      this.getUIContext().getPromptAction().showToast({ message: '请输入订阅源地址' });
      return;
    }
    const sourceIndex = this.feedIndexes[this.editFeedIndex] ?? this.editFeedIndex;
    await this.coreUtil.updateFeed(sourceIndex, this.editFeedName.trim(), this.editFeedUrl.trim(),
      this.normalizeKey(this.editTextKey, 'text'), this.normalizeKey(this.editByKey, 'by'),
      this.normalizeKey(this.editFromKey, 'from'), this.normalizeKey(this.editTimeKey, 'time'),
      this.normalizeKey(this.editUriKey, 'uri'), this.editObjectKey.trim(), this.apiMethods[this.editApiMethodIndex]);
    this.notifyFeedConfigUpdated();
    this.showEditDialog = false;
    this.resetEditFeedForm();
    this.loadFeeds();
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.succeed') });
  }

  build() {
    NavDestination() {
      Stack() {
        AppBackgroundLayer()

        Column() {
          this.PageHeader()

          Column() {
            this.FeedList()
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          if (this.showAddDialog) {
            this.AddFeedDialog()
          }
          if (this.showEditDialog) {
            this.EditFeedDialog()
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.getStatusBarHeight() })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(UiStyle.TRANSPARENT)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageWidth = Number.parseFloat(String(newValue.width));
    })
  }

  @Builder
  PageHeader() {
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
  }

  @Builder
  AddFeedDialog() {
    Column() {
      Column() {
        this.DialogTitle('添加订阅源')
        this.AddFeedFields()
        this.DialogActions('取消', '添加', () => {
          this.showAddDialog = false;
          this.resetAddFeedForm();
        }, async () => {
          await this.addFeed();
        })
      }
      .width('90%')
      .constraintSize({ maxWidth: this.getContentMaxWidth() })
      .padding(24)
      .backgroundColor(this.getGlassCardColor())
      .borderRadius(UiStyle.DIALOG_RADIUS)
      .border({ width: 1, color: this.getGlassCardBorder() })
      .shadow({ radius: 22, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 10 })
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

  @Builder
  AddFeedFields() {
    Column() {
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

      TextInput({ placeholder: '订阅源名称', text: this.newFeedName })
        .width('100%')
        .height(44)
        .fontSize(14)
        .margin({ bottom: 12 })
        .onChange((value: string) => {
          this.newFeedName = value;
        })

      TextInput({ placeholder: this.newFeedType === 0 ? 'JSON 文件 URL' :
        (this.newFeedType === 1 ? 'API 接口 URL' : '本地 JSON 文件路径'), text: this.newFeedUrl })
        .width('100%')
        .height(44)
        .fontSize(14)
        .margin({ bottom: 20 })
        .onChange((value: string) => {
          this.newFeedUrl = value;
        })

      this.AdvancedToggle(this.newShowAdvanced, () => {
        this.newShowAdvanced = !this.newShowAdvanced;
      })

      if (this.newShowAdvanced) {
        this.AdvancedFeedFields(this.newFeedType === 1, this.newApiMethodIndex, (index: number) => {
          this.newApiMethodIndex = index;
        }, this.newTextKey, (value: string) => {
          this.newTextKey = value;
        }, this.newByKey, (value: string) => {
          this.newByKey = value;
        }, this.newFromKey, (value: string) => {
          this.newFromKey = value;
        }, this.newTimeKey, (value: string) => {
          this.newTimeKey = value;
        }, this.newUriKey, (value: string) => {
          this.newUriKey = value;
        }, this.newObjectKey, (value: string) => {
          this.newObjectKey = value;
        })
      }
    }
    .width('100%')
  }

  @Builder
  EditFeedDialog() {
    Column() {
      Column() {
        this.DialogTitle('编辑订阅源')

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

        this.AdvancedToggle(this.editShowAdvanced, () => {
          this.editShowAdvanced = !this.editShowAdvanced;
        })

        if (this.editShowAdvanced) {
          this.AdvancedFeedFields(this.getEditingFeedType() === CoreUtil.FEED_TYPE_INTERNET, this.editApiMethodIndex,
            (index: number) => {
              this.editApiMethodIndex = index;
            }, this.editTextKey, (value: string) => {
              this.editTextKey = value;
            }, this.editByKey, (value: string) => {
              this.editByKey = value;
            }, this.editFromKey, (value: string) => {
              this.editFromKey = value;
            }, this.editTimeKey, (value: string) => {
              this.editTimeKey = value;
            }, this.editUriKey, (value: string) => {
              this.editUriKey = value;
            }, this.editObjectKey, (value: string) => {
              this.editObjectKey = value;
            })
        }

        this.DialogActions('取消', '保存', () => {
          this.showEditDialog = false;
          this.resetEditFeedForm();
        }, async () => {
          await this.saveEditFeed();
        })
      }
      .width('90%')
      .constraintSize({ maxWidth: this.getContentMaxWidth() })
      .padding(24)
      .backgroundColor(this.getGlassCardColor())
      .borderRadius(UiStyle.DIALOG_RADIUS)
      .border({ width: 1, color: this.getGlassCardBorder() })
      .shadow({ radius: 22, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(UiStyle.OVERLAY_BG)
    .position({ x: 0, y: 0 })
  }

  @Builder
  DialogTitle(title: string) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.colorText1'))
      .width('100%')
      .margin({ bottom: 16 })
  }

  @Builder
  AdvancedToggle(expanded: boolean, onClick: () => void) {
    Row() {
      Text('高级配置')
        .fontSize(13)
        .fontColor($r('app.color.colorPrimary'))

      Blank()

      Image($r('app.media.ic_expand'))
        .width(14)
        .height(14)
        .opacity(0.7)
        .rotate({ angle: expanded ? 180 : 0 })
    }
    .width('100%')
    .height(38)
    .margin({ bottom: expanded ? 8 : 16 })
    .onClick(() => {
      onClick();
    })
  }

  @Builder
  AdvancedFeedFields(showMethod: boolean, methodIndex: number, onMethodChange: (index: number) => void,
    textKey: string, onTextKeyChange: (value: string) => void, byKey: string, onByKeyChange: (value: string) => void,
    fromKey: string, onFromKeyChange: (value: string) => void, timeKey: string,
    onTimeKeyChange: (value: string) => void, uriKey: string, onUriKeyChange: (value: string) => void,
    objectKey: string, onObjectKeyChange: (value: string) => void) {
    Column() {
      if (showMethod) {
        Row() {
          Text('方法')
            .fontSize(14)
            .fontColor($r('app.color.colorText2'))
            .width(60)
          Select(this.apiMethods.map((item: string) => ({ value: item } as SelectOption)))
            .selected(methodIndex)
            .value(this.apiMethods[methodIndex])
            .font({ size: 14 })
            .onSelect((index: number) => {
              onMethodChange(index);
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
      }

      this.KeyInput('正文字段', textKey, onTextKeyChange)
      this.KeyInput('作者字段', byKey, onByKeyChange)
      this.KeyInput('来源字段', fromKey, onFromKeyChange)
      this.KeyInput('时间字段', timeKey, onTimeKeyChange)
      this.KeyInput('链接字段', uriKey, onUriKeyChange)
      this.KeyInput('对象路径', objectKey, onObjectKeyChange)
    }
    .width('100%')
  }

  @Builder
  KeyInput(label: string, textValue: string, onChange: (value: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.colorText2'))
        .width(74)

      TextInput({ placeholder: label, text: textValue })
        .height(40)
        .fontSize(13)
        .layoutWeight(1)
        .onChange((value: string) => {
          onChange(value);
        })
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  @Builder
  DialogActions(cancelText: string, confirmText: string, onCancel: () => void | Promise<void>,
    onConfirm: () => void | Promise<void>) {
    Row() {
      Button(cancelText)
        .type(ButtonType.Capsule)
        .borderRadius(22)
        .fontSize(14)
        .fontColor($r('app.color.colorText2'))
        .backgroundColor(this.getGlassControlColor())
        .border({ width: 1, color: this.getGlassCardBorder() })
        .height(44)
        .layoutWeight(1)
        .onClick(() => {
          Promise.resolve(onCancel()).catch((e: Error) => {
            console.error('EditFeedPage', `dialog cancel error: ${JSON.stringify(e)}`);
          });
        })

      Button(confirmText)
        .type(ButtonType.Capsule)
        .borderRadius(22)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.colorPrimary'))
        .border({ width: 1, color: $r('app.color.colorPrimary') })
        .height(44)
        .layoutWeight(1)
        .margin({ left: 12 })
        .onClick(() => {
          Promise.resolve(onConfirm()).catch((e: Error) => {
            console.error('EditFeedPage', `dialog confirm error: ${JSON.stringify(e)}`);
          });
        })
    }
    .width('100%')
  }

  @Builder
  FeedList() {
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
                Text(item.feed_type === CoreUtil.FEED_TYPE_REMOTE ? '远程' :
                  item.feed_type === CoreUtil.FEED_TYPE_INTERNET ? 'API' : '本地')
                  .fontSize(11)
                  .fontColor(Color.White)
                  .backgroundColor(item.feed_type === CoreUtil.FEED_TYPE_INTERNET ? UiStyle.TAG_GREEN : UiStyle.TAG_BLUE)
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
                this.deleteFeed(index).catch((e: Error) => {
                  console.error('EditFeedPage', `delete feed error: ${JSON.stringify(e)}`);
                });
              })
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 16, bottom: 16 })
          .backgroundColor(this.getGlassCardColor())
          .borderRadius(UiStyle.DIALOG_RADIUS)
          .border({ width: 1, color: this.getGlassCardBorder() })
          .shadow({ radius: 18, color: this.getGlassShadowColor(), offsetX: 0, offsetY: 8 })
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
    .height('100%')
    .constraintSize({ maxWidth: this.getContentMaxWidth() })
    .padding({ top: 8, bottom: 24 })
    .scrollBar(BarState.Off)
  }
}
