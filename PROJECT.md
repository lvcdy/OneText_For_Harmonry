# OneText For HarmonyOS —— 项目说明文档

## 项目概述

**OneText（一言）** 是一个简洁的应用，能够在桌面上通过**桌面卡片（Form Widget）**显示自定义的句子（一言）。用户还可以在应用内生成句子截图并保存或分享。

本项目包含 **Android 原版** 和 **HarmonyOS（鸿蒙）移植版** 两个版本。

### Android 版本

- **包名**: `com.lz233.onetext`
- **最低 SDK**: 23（Android 6.0）
- **目标 SDK**: 31（Android 12）
- **开发语言**: Kotlin + Java 混合

### HarmonyOS 版本

- **Bundle Name**: `com.lz233.onetext`
- **兼容 SDK**: HarmonyOS 5.0.0 (API 12)
- **开发语言**: ArkTS (TypeScript)
- **UI 框架**: ArkUI 声明式
- **项目目录**: `harmony/`
- **许可证**: LGPL v3

---

## 项目结构

```
OneText_For_Harmonry/
├── app/                         # 主应用模块
├── instant/                     # Instant App 模块（免安装体验版）
├── lawnchair/                   # Lawnchair 启动器相关库模块
├── OneText/                     # 设计素材资源（截图、PSD、PNG 等）
├── build.gradle                 # 根项目 Gradle 构建脚本
├── settings.gradle              # 模块包含配置（app, instant, lawnchair）
├── gradle.properties            # Gradle 全局配置（AndroidX 等）
├── translate.sh                 # 简繁中文翻译脚本（OpenCC）
├── LICENSE                      # LGPL v3 许可证
└── README.md                    # 原始 README
```

### 主模块 `app/` 核心目录

```
app/src/main/
├── AndroidManifest.xml
├── assets/
│   ├── xposed_init              # Xposed 模块入口声明
│   └── Feed/Feed.json           # 内置订阅源配置
├── java/com/lz233/onetext/
│   ├── OneTextApp.kt            # Application 入口类
│   ├── activity/                # Activity 页面
│   │   ├── MainActivity.java        # 主界面（展示一言、保存/分享截图）
│   │   ├── SettingActivity.java     # 设置页
│   │   ├── AboutActivity.kt         # 关于页
│   │   ├── EditFeedActivity.java    # 编辑订阅源
│   │   ├── WelcomeActivity.java     # 欢迎引导页
│   │   ├── OauthActivity.java       # OAuth 认证
│   │   ├── PrivacyPolicyActivity.kt # 隐私政策
│   │   ├── CrashReportActivity.java # 崩溃报告
│   │   └── BaseActivity.kt          # Activity 基类
│   ├── fragment/                # 欢迎页 Fragment（WelcomeFragment0~5）
│   ├── hook/                    # Xposed Hook 模块
│   │   ├── InitHook.kt             # Hook 入口，针对网易云音乐歌词分享
│   │   ├── HookConfig.kt           # Hook 常量配置
│   │   └── utils/                   # Hook 工具类
│   ├── provider/
│   │   └── WidgetProvider.java      # 桌面小部件 Provider
│   ├── service/
│   │   └── ExternalControlService.kt # Android 11+ 设备控制面板集成
│   ├── tools/
│   │   ├── feed/                    # 订阅源数据模型与适配器
│   │   │   ├── Feed.kt
│   │   │   └── FeedAdapter.java
│   │   └── utils/                   # 工具类
│   │       ├── CoreUtil.java            # 核心逻辑（读取/随机一言、订阅源管理）
│   │       ├── GetUtil.java             # 网络请求工具
│   │       ├── DownloadUtil.java        # 下载工具
│   │       ├── FileUtil.java            # 文件操作工具
│   │       ├── SaveBitmapUtil.java      # 截图保存工具
│   │       ├── QRCodeUtil.java          # 二维码生成工具
│   │       ├── AppUtil.kt               # 应用信息工具
│   │       └── CoolapkAuthUtil.kt       # 酷安认证工具
│   └── view/                    # 自定义 View
│       ├── AdjustImageView.kt
│       └── NiceImageView.java
└── res/                         # 资源文件
    ├── layout/                      # 布局文件（23 个）
    ├── drawable/                    # 图标和样式
    ├── values/                      # 默认语言字符串、颜色、样式
    ├── values-zh/                   # 简体中文
    ├── values-zh-rTW/               # 繁体中文（台湾）
    ├── values-zh-rHK/               # 繁体中文（香港）
    ├── values-zh-rMO/               # 繁体中文（澳门）
    ├── values-night/                # 夜间模式
    └── xml/                         # Widget 配置、网络安全策略等
```

---

## 核心功能

### 1. 一言展示与桌面小部件
- 从订阅源（远程 JSON 或本地文件）随机获取一条句子
- **桌面 Widget** 显示句子内容、作者、来源等信息
- 支持 Markdown 渲染（通过 Markwon 库）
- 支持暗色/亮色模式切换

### 2. 订阅源系统（Feed）
- 内置默认订阅源：OneText Library、Hitokoto 等
- 支持添加自定义远程/本地订阅源
- 订阅源配置灵活（可自定义 JSON key 映射：text、by、from、time、uri）
- 通过 `EditFeedActivity` 进行管理

### 3. 句子截图生成与分享
- 在主界面可将当前句子渲染为图片
- 支持自定义字体大小、字体文件
- 可保存到本地或分享给其他应用

### 4. Xposed 模块（Hook 网易云音乐）
- Hook 网易云音乐（`com.netease.cloudmusic`）的歌词分享页面
- 长按"歌词图片"可将选中歌词、歌手名、歌曲名导入到 OneText
- 使用 EzXHelper 库简化 Hook 操作

### 5. Android 11+ 设备控制面板
- 通过 `ExternalControlService` 集成到 Android 11 的设备控制面板
- 提供快捷展示一言的控制按钮

### 6. 多语言支持
- 默认英文 + 简体中文
- 通过 OpenCC 自动转换生成繁体中文（台湾/香港/澳门）
- `translate.sh` 脚本自动化简繁转换

---

## 技术栈与依赖

| 类别 | 依赖 |
|------|------|
| 语言 | Kotlin 1.5.21 + Java 11 |
| 构建 | Gradle 7.0.0，Android Gradle Plugin |
| 网络 | OkHttp 5.0.0-alpha.2 |
| UI | Material Design Components 1.5.0，ViewPager2，SwipeRefreshLayout，ConstraintLayout |
| Markdown | Markwon 4.6.2（core + tasklist + strikethrough） |
| 字体 | Calligraphy 3.1.1 + ViewPump 2.0.3 |
| 权限 | EasyPermissions 3.0.0 |
| 简繁转换 | android-opencc 1.1.0 |
| 二维码 | ZXing Core 3.4.1 |
| 弹幕 | EasyBarrage 0.0.1 |
| 滑块 | IndicatorSeekBar 2.1.2 |
| 响应式 | RxJava3 3.0.13 |
| Xposed | Xposed API 82 + EzXHelper 0.5.5 |
| 崩溃/分析 | Microsoft App Center（Analytics + Crashes）4.2.0 |
| 编码 | Commons Codec |

---

## 构建与运行

### 环境要求
- JDK 11+
- Android SDK（compileSdk 31，buildTools 31.0.0）
- Gradle（使用项目自带 `gradlew` 包装器）

### 构建命令

```bash
# Debug 构建
./gradlew assembleDebug

# Release 构建（需要配置签名环境变量）
export KEYSTORE_PASSWORD=<your_keystore_password>
export KEY_ALIAS=<your_key_alias>
export KEY_PASSWORD=<your_key_password>
./gradlew assembleRelease
```

### 构建变体
- **release** — 标准发布版
- **coolapk** — 酷安渠道版
- **GooglePlay** — Google Play 渠道版

### 简繁转换
```bash
# 需要安装 OpenCC
./translate.sh
```

---

## 多模块说明

| 模块 | 类型 | 说明 |
|------|------|------|
| `app` | Application | 主应用，包含所有核心功能 |
| `instant` | Application | Instant App 免安装体验版 |
| `lawnchair` | Library | Lawnchair 启动器相关组件库（RecyclerView 动画等） |

---

## 相关链接

- 项目主页: https://github.com/lz233/OneText_For_Android
- 核心库: https://github.com/lz233/OneText-Library
- Telegram 群组: https://t.me/OneTextProject

## 贡献者

[lz233](https://github.com/lz233) · [xbl233](https://github.com/XiaoMengXinX) · [Kanglyh](https://github.com/kanglyh) · [猫耳逆变器](https://github.com/NekoInverter) · [RebornQ](https://github.com/RebornQ)

---

## HarmonyOS（鸿蒙）版本

### 项目结构

```
harmony/
├── AppScope/                          # 应用级配置
│   ├── app.json5                          # 应用信息（bundleName、版本等）
│   └── resources/base/element/
│       └── string.json                    # 应用级字符串
├── build-profile.json5                # 构建配置
├── oh-package.json5                   # 包管理配置
├── hvigorfile.ts                      # 构建脚本
└── entry/                             # 主模块
    ├── build-profile.json5
    ├── oh-package.json5
    └── src/main/
        ├── module.json5                   # 模块配置（Ability、权限等）
        ├── ets/
        │   ├── entryability/
        │   │   └── EntryAbility.ets       # 应用入口 Ability
        │   ├── entryformability/
        │   │   └── EntryFormAbility.ets   # 桌面卡片 FormExtensionAbility
        │   ├── pages/
        │   │   ├── Index.ets              # 主页面（一言展示、截图保存）
        │   │   ├── SettingsPage.ets       # 设置页（界面、订阅源、小组件）
        │   │   ├── AboutPage.ets          # 关于页
        │   │   └── EditFeedPage.ets       # 订阅源编辑页
        │   ├── widget/pages/
        │   │   └── WidgetCard.ets         # 桌面卡片 UI
        │   ├── common/
        │   │   ├── CoreUtil.ets           # 核心业务逻辑
        │   │   ├── FileUtil.ets           # 文件操作工具
        │   │   ├── HttpUtil.ets           # 网络请求工具
        │   │   └── PreferencesUtil.ets    # 偏好设置工具
        │   └── model/
        │       └── DataModels.ets         # 数据模型定义
        └── resources/
            ├── base/
            │   ├── element/
            │   │   ├── string.json        # 英文字符串
            │   │   └── color.json         # 颜色定义
            │   ├── media/                 # 图标资源（SVG）
            │   └── profile/
            │       ├── main_pages.json    # 页面路由
            │       └── form_config.json   # 卡片配置
            ├── zh_CN/element/
            │   └── string.json            # 简体中文字符串
            ├── dark/element/
            │   └── color.json             # 暗色模式颜色
            └── rawfile/
                └── Feed.json              # 内置订阅源配置
```

### Android → HarmonyOS 技术映射

| Android 概念 | HarmonyOS 对应 | 说明 |
|---|---|---|
| Activity | UIAbility + Page | EntryAbility 作为入口，页面用 @Entry @Component 实现 |
| Fragment | @Component | ArkUI 组件即可复用 |
| AppWidgetProvider | FormExtensionAbility | 桌面卡片（Form Widget） |
| SharedPreferences | @kit.ArkData preferences | 轻量级键值存储 |
| OkHttp | @kit.NetworkKit http | 系统原生 HTTP 请求 |
| XML Layout | ArkUI 声明式 | Column/Row/Text/Image 等组件 |
| RecyclerView | List + ForEach | ArkUI 列表组件 |
| Broadcast | CommonEvent | 应用内事件通知 |
| MediaStore | @kit.MediaLibraryKit | 图片保存 |
| File I/O | @kit.CoreFileKit fileIo | 沙箱文件操作 |
| Clipboard | @kit.BasicServicesKit pasteboard | 剪贴板服务 |
| Snackbar/Toast | promptAction.showToast | 提示消息 |
| AlertDialog | AlertDialog.show | 对话框 |
| Material Switch | Toggle | 开关组件 |
| SeekBar/Slider | Slider | 滑块组件 |
| Spinner | Select | 下拉选择器 |

### 已移植功能

- ✅ 一言展示与随机刷新
- ✅ 多订阅源支持（远程 JSON / API 接口）
- ✅ 订阅源管理（添加/删除/切换）
- ✅ 桌面卡片（Form Widget）
- ✅ 截图保存
- ✅ 字体大小自定义
- ✅ 文字复制到剪贴板
- ✅ 设置页面（显示模式、订阅源、小组件配置）
- ✅ 关于页面
- ✅ 暗色/亮色模式
- ✅ 多语言（中英文）

### 未移植/不适用功能

- ❌ Xposed Hook 模块（鸿蒙无对应机制）
- ❌ Android 11 设备控制面板
- ❌ Instant App 模块
- ❌ 自定义字体文件加载（需适配鸿蒙字体管理）
- ❌ 简繁中文自动转换（需第三方库或自行实现）
- ❌ Markdown 渲染（需第三方富文本组件）
- ❌ 二维码生成
- ❌ Microsoft AppCenter 崩溃收集

### 构建与运行

#### 环境要求

- DevEco Studio 5.0+ (NEXT)
- HarmonyOS SDK 5.0.0 (API 12)
- Node.js 16+

#### 构建步骤

1. 使用 DevEco Studio 打开 `harmony/` 目录
2. 等待依赖同步完成
3. 连接鸿蒙设备或启动模拟器
4. 点击 Run 按钮编译运行
