# 技术发现

- 当前仓库仅有 GitHub 生成的 AGPL-3.0 `LICENSE`。
- 当前环境为 Windows，不具备 Xcode 与 iOS SDK；可做结构和文本静态检查，真正的 Swift 编译需在云端 macOS 环境完成。
- iOS 16 可使用 `WKDownload`、WebKit 媒体捕获权限委托和持久化网站数据。
- Safari、`ASWebAuthenticationSession` 与 `WKWebView` 不共享 Cookie；OpenAI 未提供本 App 可控制的 OAuth 回调时，无法安全地把系统认证会话强制迁回 WKWebView。
- 第三方附件 URL 必须先允许 WebKit 获取响应，才能根据 MIME Type 或 `Content-Disposition` 区分下载与普通外链。
- iOS App Icon 已使用无透明通道的 1024×1024 PNG；Asset Catalog 引用完整。
