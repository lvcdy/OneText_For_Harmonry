# Hitokoto

Hitokoto 是一个 HarmonyOS 版本的句子展示应用，项目地址为 <https://github.com/lvcdy/OneText_For_Harmonry>。应用支持从不同订阅源获取内容，在首页卡片中展示句子、作者、来源与时间，并提供复制、刷新、保存截图、字号调整和桌面小组件等功能。

应用包名：`cn.lvcdy.hitokoto`

## 功能

- 首页展示 Hitokoto 卡片，支持点击复制正文、作者和来源。
- 支持下拉刷新和手动刷新。
- 支持保存当前卡片截图到相册。
- 支持显示或隐藏印章效果。
- 支持调节正文、作者、时间和来源字号。
- 支持自定义应用背景，可选择本地图片或使用返回图片的网络地址。
- 支持首次启动引导页。
- 支持华为账号登录，并在“我的”页展示头像和昵称。
- 支持设置页中的显示模式、简繁偏好、订阅源切换与编辑。
- 支持远程 JSON 订阅源、API 订阅源以及本地订阅源。
- 支持 Hitokoto Widget，并可同步刷新组件数据。
- 支持透明小组件；小组件底部保留 12% 不透明区域，用于满足透明卡片审核要求。

## 项目结构

- `AppScope/`：应用级元数据与资源。
- `entry/`：主模块，包含 ArkTS 代码、页面、Widget 和模块资源。
- `entry/src/main/ets/pages/`：主页面、设置页、关于页、订阅源管理页和欢迎页。
- `entry/src/main/ets/widget/`：桌面小组件页面。
- `entry/src/main/resources/`：字符串、图片、rawfile 和 profile 配置。
- `build-profile.json5`：应用级构建与签名配置。
- `hvigorfile.ts`：应用级构建入口。

## 环境要求

- DevEco Studio 6.x
- HarmonyOS SDK 6.1.0（API 23）
- Node.js 和 hvigor 环境由 DevEco Studio 提供即可

## 构建与运行

1. 使用 DevEco Studio 打开仓库根目录。
2. 同步依赖。
3. 执行构建：

```bash
hvigorw clean --mode module -p product=default -p buildMode=release assembleHap
```

4. 在 DevEco Studio 中选择 `entry` 模块运行，或将生成的 HAP 安装到设备/模拟器。
5. 如果要上传到 AppGallery Connect，请使用 `release` 构建模式生成的包，不要上传 `debug` 包。

## 页面与交互

- `Index`：主页面，负责 Hitokoto 展示、刷新、复制、截图、登录入口和字号控制。
- `WelcomePage`：首次启动引导页。
- `SettingsPage`：设置页，负责订阅源切换、显示选项和 Widget 参数。
- `EditFeedPage`：订阅源管理页。
- `AboutPage`：关于页，包含项目主页和核心库链接。

## 数据来源

应用会先从 `entry/src/main/resources/base/rawfile/Feed.json` 初始化订阅源列表，再根据当前订阅配置从远程 JSON、API 或本地文件加载内容。应用运行时会在沙箱目录中缓存远程订阅数据，以减少重复请求。

## 权限

应用声明了以下主要权限：

- `ohos.permission.INTERNET`
- `ohos.permission.DETECT_GESTURE`
- `ohos.permission.WRITE_IMAGEVIDEO`

`WRITE_IMAGEVIDEO` 用于将首页截图保存到相册。`DETECT_GESTURE` 用于左右手握持检测，以动态调整界面布局。

## 发布注意

- `build-profile.json5` 中的签名配置应在发布前替换为正式发布证书。
- 不建议将真实发布证书、密钥文件或明文密码提交到仓库；更稳妥的方式是通过本地配置或 CI 注入。

## 许可证

本项目采用 [GNU Lesser General Public License v3.0](./LICENSE) 许可发布。
