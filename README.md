# OneText_For_Harmonry

OneText 的 HarmonyOS 版本，原项目来自 [OneText_For_Android](https://github.com/lz233/OneText_For_Android)。它是一个展示“一言”内容的 ArkTS 应用，支持从不同订阅源获取内容，在首页卡片中展示句子、作者、来源与时间，并提供复制、刷新、保存截图和字号调整等操作。

## 功能

- 首页展示一言卡片，支持点击复制正文、作者和来源。
- 支持下拉刷新和手动刷新。
- 支持保存当前卡片截图到相册。
- 支持显示或隐藏印章效果。
- 支持调节正文、作者、时间和来源字号。
- 支持首次启动引导页。
- 支持设置页中的显示模式、简繁偏好、订阅源切换与编辑。
- 支持远程 JSON 订阅源、API 订阅源以及本地订阅源。
- 支持 OneText Widget，并可同步刷新组件数据。
- 支持关于页、订阅源管理页和一系列偏好设置。

## 项目结构

- `AppScope/`：应用级元数据与资源。
- `entry/`：主模块，包含 ArkTS 代码、页面、Widget 和模块资源。
- `hvigorfile.ts`：应用级构建入口。
- `build-profile.json5`：应用级构建与签名配置。

## 环境要求

- DevEco Studio 6.x
- HarmonyOS SDK 6.1.0（API 23）
- Node.js 和 hvigor 环境由 DevEco Studio 提供即可

## 构建与运行

1. 使用 DevEco Studio 打开仓库根目录。
2. 同步依赖后，执行构建：

```bash
hvigorw clean --mode module -p product=default assembleHap
```

3. 在 DevEco Studio 中选择 `entry` 模块运行，或将生成的 HAP 安装到设备/模拟器。

## 签名与证书

本项目已经在 `build-profile.json5` 中配置了 HarmonyOS 签名信息，当前使用的是本机 DevEco Studio 生成的调试证书：

- 签名别名为 `debugKey`。
- 签名算法为 `SHA256withECDSA`。
- 产品 `default` 已绑定到默认签名配置。

如果你在另一台机器上打开这个仓库，需要重新生成或导入对应的 HarmonyOS 调试证书，并同步更新 `build-profile.json5` 中的路径。

## 页面与交互

- `Index`：主页面，负责一言展示、刷新、复制、截图和字号控制。
- `WelcomePage`：首次启动引导页。
- `SettingsPage`：设置页，负责订阅源切换、显示选项和 Widget 参数。
- `EditFeedPage`：订阅源管理页。
- `AboutPage`：关于页。

## 数据来源

应用会先从 `entry/src/main/resources/base/rawfile/Feed.json` 初始化订阅源列表，再根据当前订阅配置从远程 JSON、API 或本地文件加载内容。应用运行时会在沙箱目录中缓存远程订阅数据，以减少重复请求。

## 权限

应用声明了以下主要权限：

- `ohos.permission.INTERNET`
- `ohos.permission.DETECT_GESTURE`
- `ohos.permission.WRITE_IMAGEVIDEO`

`WRITE_IMAGEVIDEO` 用于将首页截图保存到相册。

## 说明

- 项目目标是 HarmonyOS 6 的 Stage 模式应用。
- 首页和设置页都支持左右手握持检测，用于动态调整界面布局。
- 如果订阅源文件缺失，应用会自动初始化默认资源。