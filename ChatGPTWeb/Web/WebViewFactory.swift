import WebKit

enum WebViewFactory {
    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // 硬件加速与图层渲染优化
        configuration.suppressesIncrementalRendering = false
        
        let preferences = WKPreferences()
        preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.preferences = preferences

        return configuration
    }

    static func makeWebView(configuration: WKWebViewConfiguration? = nil) -> WKWebView {
        let webView = WKWebView(
            frame: .zero,
            configuration: configuration ?? makeConfiguration()
        )
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.keyboardDismissMode = .interactive
        
        // 渲染与滑动优化：开启减速惯性与平滑滚动
        webView.scrollView.decelerationRate = .normal
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        
        // 避免透明图层混合带来的 GPU 渲染负担
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        // 默认不自定义 UA，保持与系统 Safari WebKit 一致的高性能渲染管线
        return webView
    }
}
