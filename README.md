# ChatGPT Web

ChatGPT Web 是一个面向 iPhone 14、iOS 16.5 和 TrollStore 的原生 iOS Web Wrapper。App 使用 `WKWebView` 直接加载 [chatgpt.com](https://chatgpt.com/)，不显示 Safari 的地址栏、底部工具栏或标签页界面。

项目不包含 OpenAI 的官方图标、代码或品牌资源，也不是 OpenAI 官方客户端。仓库中的图标是原创占位图标。

## 设计目标

- 原生 Swift 与 UIKit，不依赖第三方库。
- Deployment Target 为 iOS 16.0，可在 iOS 16.5 上运行。
- 使用持久化 `WKWebsiteDataStore.default()`，保留 Cookie、LocalStorage 和 IndexedDB。
- 不读取、记录或上传聊天内容、Cookie、Token 和认证信息。
- 不注入 JavaScript，不代理或修改 ChatGPT 网络请求。
- 不使用私有 API，可由常规 Xcode 环境构建。

## 已实现功能

- 全屏独立 App 窗口，适配刘海、安全区、横竖屏和深浅色模式。
- JavaScript、持久网站数据、inline media playback 和网页媒体权限请求。
- 左右滑动前进/后退、下拉刷新和交互式键盘收起。
- 主页面加载失败提示、失败请求重试和 Web Content Process 终止恢复。
- OpenAI 第一方页面留在 App 内，普通第三方网页由系统打开。
- 支持 `target="_blank"`、多级 `window.open()`、重定向和常见外部 URL Scheme。
- 第三方 OAuth 使用共享持久网站数据的受控认证窗口，窗口显示当前域名。
- WebKit 原生 `<input type="file">` 文件选择，支持 Files、Photos 和网站请求的 Camera 入口。
- 使用 `WKDownload` 下载附件，保留 suggested filename，完成后打开系统 Share Sheet，可选择“存储到文件”。
- 下载失败提示、并发分享排队和临时文件清理。

## 工程结构

```text
ChatGPTWeb/
├── App/                 App 与 Scene 生命周期
├── Authentication/      OAuth 与登录窗口
├── Download/            WKDownload 与系统分享
├── Resources/           Info.plist 和 Asset Catalog
├── UI/                  原生错误覆盖层
└── Web/                 WebView、导航策略与协调器
```

主要 Target 和 Scheme 均为 `ChatGPTWeb`。

## 修改 Bundle ID

在 Xcode 中选择：

1. Project Navigator 中的 `ChatGPTWeb` 工程。
2. `TARGETS > ChatGPTWeb > Signing & Capabilities`。
3. 修改 `Bundle Identifier`。

当前默认值为 `com.example.chatgptweb`。也可以直接修改 `ChatGPTWeb.xcodeproj/project.pbxproj` 中 Debug 和 Release 的两个 `PRODUCT_BUNDLE_IDENTIFIER`。

## 修改 App 名称

桌面显示名称位于 `ChatGPTWeb/Resources/Info.plist`：

```xml
<key>CFBundleDisplayName</key>
<string>ChatGPT Web</string>
```

修改该字符串不会改变 Target、Scheme 或 `.app` 文件名。

## 替换 App Icon

将以下文件替换为无透明通道的 1024×1024 PNG：

```text
ChatGPTWeb/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

不要使用 OpenAI 官方 App 图标，除非你已获得相应授权。仓库中的 `Artwork/AppIcon.svg` 是占位图标源文件。在 Windows 上可运行以下命令重新生成 PNG：

```powershell
./scripts/Generate-AppIcon.ps1
```

## 使用 Codemagic 云端构建

仓库根目录提供了 `codemagic.yaml`，Codemagic 导入仓库后会自动识别。该工作流直接生成 TrollStore 使用的无签名 Release IPA，不需要 Apple Developer 账号、签名证书、Provisioning Profile 或 Codemagic Secret。

首次配置：

1. 登录 [Codemagic](https://codemagic.io/) 并选择 `Add application`。
2. 连接 GitHub，选择公开仓库 `tt-P607/ChatGPT_Web`。
3. 项目类型选择 `Other`，构建配置选择 `Codemagic YAML`。
4. 保存应用后选择 `Start new build`。
5. Branch 选择 `main`，Workflow 选择 `iOS TrollStore IPA`（ID 为 `ios-trollstore`）。
6. 启动构建，不需要填写证书或环境变量。

构建完成后，在该次 Build 的 `Artifacts` 区域下载：

```text
ChatGPTWeb-unsigned.ipa
```

Codemagic 同时保留 `ChatGPTWeb.app` 和 Xcode 工程清单 `xcode-project.json` 作为辅助产物。工作流使用 `mac_mini_m2` 和 Codemagic 当前最新 Xcode，执行以下三项检查：

- Xcode 能识别工程和共享 Scheme。
- Release `iphoneos` 无签名构建成功。
- IPA ZIP 完整，且包含 `Payload/ChatGPTWeb.app/Info.plist`。

当前没有配置自动触发，因此推送代码不会消耗 Codemagic 构建分钟。需要构建时在 Codemagic 中手动点击 `Start new build`。如需自动构建，可在 `codemagic.yaml` 的 workflow 中增加 `triggering` 配置并为仓库创建 webhook。

底层 Xcode 配置为：

- Target：`ChatGPTWeb`
- Scheme：`ChatGPTWeb`
- Configuration：`Release`
- Destination：`Any iOS Device (arm64)` 或实际连接的 iPhone

Deployment Target 位于 `TARGETS > ChatGPTWeb > General > Minimum Deployments`，当前为 iOS 16.0。不要将其提高到 iOS 17，否则 iOS 16.5 无法安装。

仓库中的 GitHub Actions 工作流作为备用构建入口，不影响 Codemagic。

## 生成有签名 Release

有 Apple 开发者签名时：

1. 在 `Signing & Capabilities` 中选择 Team，并确认 Bundle ID 唯一。
2. 选择 `Any iOS Device (arm64)`。
3. 执行 `Product > Archive`。
4. 在 Organizer 中按证书类型导出 `.ipa`。

工程未写死 Team 或 Provisioning Profile，便于不同云编译环境注入自己的签名配置。TrollStore 的 Codemagic 工作流不执行这一有签名流程。

## 生成无签名 IPA

Codemagic 会自动执行以下脚本；在其他 macOS/Xcode 环境也可手动运行：

```bash
bash scripts/build-unsigned-ipa.sh
```

脚本执行 Release `iphoneos` 构建，关闭代码签名，并将 `.app` 按标准 `Payload/ChatGPTWeb.app` 结构打包。输出位置：

```text
build/ChatGPTWeb-unsigned.ipa
```

等价的核心构建命令为：

```bash
xcodebuild \
  -project ChatGPTWeb.xcodeproj \
  -scheme ChatGPTWeb \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  clean build
```

## TrollStore 安装

1. 将生成的 IPA 传到 iPhone。
2. 在系统分享菜单中选择 TrollStore，或在 TrollStore 中选择 IPA。
3. 安装后从桌面启动 `ChatGPT Web`。

注意事项：

- 仅从自己信任的源码和构建环境获取 IPA。
- Bundle ID 与设备中现有 App 冲突时，需要先修改 Bundle ID 或移除冲突 App。
- 本项目不需要额外 entitlement、私有 API 或 TrollStore 专用能力。
- 不同 TrollStore 版本对签名状态的处理可能不同；无签名 IPA 被拒绝时，请使用云环境的有效证书签名后再安装。
- 更新 App 前建议保留相同 Bundle ID，避免被系统视为另一个 App。网站登录数据能否保留还取决于安装方式和系统容器处理。

## 登录与 OAuth 限制

邮箱和 OpenAI 自有登录页面通常可以直接在主 WebView 中完成。第三方登录跳转会进入一个共享 `WKWebsiteDataStore` 的受控 WebView，因此兼容 embedded browser 的 Google、Apple、Microsoft 等 Provider 可以把 Cookie 留在同一网站数据存储中。

部分 OAuth Provider 会明确禁止 embedded WKWebView。认证窗口提供“在 Safari 中打开”的安全降级，但存在无法由本项目消除的限制：

- Safari 与 WKWebView 不共享 Cookie。
- OpenAI 的 OAuth Client、`redirect_uri` 和 HTTPS 回调域由 OpenAI 控制。
- 本 App 不拥有 OpenAI 域名，不能注册其 Universal Link 或修改 OAuth callback。
- 在 Safari 完成登录后，登录状态不保证能够传回 WKWebView。
- `ASWebAuthenticationSession` 同样需要 App 可控制的 callback scheme 或关联域。当前网页认证架构不提供这一条件，因此项目没有伪造一个无法安全衔接会话的实现。

项目不会伪装 User-Agent、复制 Cookie、截获 Token、绕过 Provider 限制或使用中间服务器。第三方登录被拒绝时，优先尝试邮箱登录通常更可靠。

## 文件上传

上传由 iOS 16 WKWebView 对 `<input type="file">` 的原生实现提供。网页可调用：

- iOS Files 文件选择器。
- Photos 图片选择器。
- 在网页正确声明 `accept` 和 `capture` 时调用相机。

`Info.plist` 已包含 Camera、Microphone 和 Photo Library 权限说明。App 不会在启动时主动请求权限，只有网页实际使用对应能力时才由系统询问。

实际入口由 ChatGPT 当前网页代码和 iOS 16.5 WebKit 决定。若网页改用只在较新 WebKit 中存在的文件 API，本 Wrapper 无法补齐浏览器引擎能力。

## 文件下载

下载流程为：

```text
ChatGPT / 附件 CDN → WKDownload → 独立临时目录 → Share Sheet → 存储到文件或分享
```

实现同时识别 WebKit 的 `shouldPerformDownload`、无法展示的 MIME Type 和 `Content-Disposition: attachment`。普通第三方网页仍会交给系统打开；第三方附件响应会在判断 MIME 后留在 App 内下载。

Share Sheet 关闭后会删除临时文件。App 再次启动时也会清理上次异常退出遗留的下载目录。Blob、Service Worker 或纯 JavaScript 生成的特殊下载是否触发 `WKDownload`，取决于 iOS 16.5 WebKit；项目不会注入 JavaScript 读取 Blob。

## 语音、相机和媒体限制

项目允许 OpenAI 第一方 HTTPS Origin 请求 WebKit 的麦克风和相机权限，并拒绝第三方 iframe 直接索取媒体权限。已启用 inline media playback 和无需预先强制用户操作的媒体播放配置。

iOS 16.5 使用系统自带 WebKit。ChatGPT 新版 Voice 或录音功能如果依赖新版 WebRTC、WebCodecs、AudioWorklet、MediaRecorder 行为或 iOS 17+ 修复，可能不可用、降级或不稳定。Wrapper 无法升级系统 WebKit，也不会显示虚假的原生语音按钮。

## 导航和安全策略

- 仅严格匹配 `chatgpt.com`、`openai.com` 及其真实子域，避免把 `openai.com.example.org` 当作官方域名。
- OAuth Provider 不使用固定域名白名单；是否进入认证窗口由 OpenAI 登录上下文和弹窗关系判断。
- 用户点击的普通第三方 HTTP(S) 页面直接使用系统默认处理，可触发对应 Universal Link。
- 脚本或重定向产生的未知第三方 HTTPS 响应会先判断是否为附件；可展示网页随后交给系统打开。
- `mailto:`、`tel:`、`sms:` 等系统支持的 Scheme 交给 iOS 打开。
- `data:`、`file:` 和 `javascript:` 顶层导航不会发送给外部 App。
- 不接管 HTTPS、不做 MITM、不使用代理、不修改请求或响应。

## iOS 16.5 已知限制

- 网页能力受 iOS 16.5 内置 WebKit 限制，无法通过 App 更新浏览器引擎。
- ChatGPT 网站、Cloudflare 风控、OAuth Provider 策略随时可能改变。
- 系统可能在内存压力下终止 Web Content Process；App 会尝试重载当前页面，但未提交的输入可能丢失。
- 后台停留过久后，网页会话是否继续有效由 iOS 和 ChatGPT 服务端决定。
- iOS 原生 WKWebView 负责键盘避让、复制粘贴、长按菜单和响应式布局；网站前端更新仍可能引入 iOS 16 专属兼容问题。
- Universal Link 的归属由目标域的 AASA 文件控制，本 App 无法声明 OpenAI 域名归属。
- 第三方 OAuth、Voice、Blob 下载和文件选择必须在 iOS 16.5 真机上结合当时的 ChatGPT 网页版本验证。

## 静态验证

Windows 环境可运行：

```powershell
./scripts/Verify-Project.ps1
```

脚本检查工程关键文件、XML/JSON 格式、iOS 16.0 Deployment Target、权限说明、占位图标尺寸与透明通道，并扫描非持久数据存储、`UIWebView`、KVC 私有配置和页面 JavaScript 注入。

Windows 没有 Xcode 和 iOS SDK，无法执行 `xcodebuild`、`actool`、签名、Archive 或真机测试。首次 macOS 云构建仍需验证：

- Swift、WebKit 委托和 Asset Catalog 的实际编译结果。
- Release device build 与 IPA 包结构。
- iPhone 14 / iOS 16.5 上的登录、上传、下载、相机、麦克风、媒体、键盘和横竖屏行为。
- 当前 ChatGPT 网站和 OAuth Provider 的实际兼容性。

## 许可证

本项目使用 [GNU Affero General Public License v3.0](LICENSE)。
