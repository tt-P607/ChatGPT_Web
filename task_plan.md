# ChatGPT Web iOS 项目计划

## 目标

创建可由常规云端 Xcode 环境构建、面向 iPhone 14 / iOS 16.5 / TrollStore 的原生 WKWebView Wrapper。

## 阶段

- [完成] 1. 建立标准 Xcode 工程与基础 App 生命周期
- [完成] 2. 实现 WebView、导航、认证与外部链接策略
- [完成] 3. 实现下载、分享、错误恢复与媒体权限
- [完成] 4. 添加资源、构建脚本和中文 README
- [完成] 5. 执行静态检查与可用验证
- [完成] 6. 接入 Codemagic 云端 IPA 构建

## 关键决策

- 使用 UIKit 生命周期，Deployment Target 为 iOS 16.0。
- 仅使用系统框架，不注入读取页面内容的 JavaScript。
- 主 WebView 使用 `WKWebsiteDataStore.default()` 保持网站数据。
- 第三方 OAuth 使用共享网站数据的受控认证 WebView；系统浏览器只作为安全降级，不承诺 Cookie 回传。
- 下载由 `WKDownload` 接管，完成后打开系统分享表，并在分享结束后清理临时文件。
- Codemagic 复用无签名 Release 脚本，手动触发并导出 IPA 与 `.app` 构建产物。

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|---|---:|---|
| PowerShell 5.1 按 ANSI 读取无 BOM 的 UTF-8 plist，导致 XML 误报损坏 | 1 | 静态检查显式指定 `-Encoding UTF8` |
| Codemagic（Xcode 16 / Swift 6）报告 `URLRequest.init(url:)` 推断失败，以及未弱捕获 `self` 时 `guard let self` 报非可选绑定错误 | 1 | 将构造器/方法引用改为显式闭包，并在闭包捕获列表中补齐 `weak self` |

## 最终验证

- Windows 静态验证脚本通过。
- Bash IPA 构建脚本语法检查通过。
- VS Code 未报告 Swift、YAML、Markdown 或 PowerShell 诊断。
- 当前环境没有 Xcode/iOS SDK，真实编译、签名和真机测试待 macOS 云构建验证。
