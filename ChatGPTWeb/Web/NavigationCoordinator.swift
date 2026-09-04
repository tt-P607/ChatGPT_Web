import UIKit
import WebKit

final class NavigationCoordinator: NSObject {
    private weak var presentingViewController: UIViewController?
    private weak var webView: WKWebView?
    private weak var errorView: WebErrorView?
    private let navigationPolicy = NavigationPolicy()
    private let recoveryURL = URL(string: "https://chatgpt.com/")!
    private var failedRequest: URLRequest?
    private lazy var downloadCoordinator = DownloadCoordinator(
        presentingViewController: presentingViewController!
    )
    private lazy var authenticationCoordinator = AuthenticationCoordinator(
        presentingViewController: presentingViewController!,
        navigationPolicy: navigationPolicy,
        downloadCoordinator: downloadCoordinator
    ) { [weak self] request in
        self?.webView?.load(request)
    }

    init(
        presentingViewController: UIViewController,
        webView: WKWebView,
        errorView: WebErrorView
    ) {
        self.presentingViewController = presentingViewController
        self.webView = webView
        self.errorView = errorView
    }

    func start() {
        webView?.navigationDelegate = self
        webView?.uiDelegate = self
    }

    func retryAfterFailure() {
        errorView?.isHidden = true
        if let failedRequest {
            webView?.load(failedRequest)
        } else if let url = webView?.url {
            webView?.load(URLRequest(url: url))
        } else {
            webView?.load(URLRequest(url: recoveryURL))
        }
    }

    private func openExternally(_ url: URL) {
        UIApplication.shared.open(url, options: [:]) { [weak self] succeeded in
            guard !succeeded else { return }
            self?.showAlert(title: "无法打开链接", message: url.absoluteString)
        }
    }

    private func showAlert(title: String, message: String?) {
        guard let presenter = presentingViewController, presenter.presentedViewController == nil else {
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        presenter.present(alert, animated: true)
    }

    private func showLoadError(_ error: Error) {
        let urlError = error as? URLError
        guard urlError?.code != .cancelled else { return }
        failedRequest = failedRequest ?? webView?.url.map { URLRequest(url: $0) }
        webView?.scrollView.refreshControl?.endRefreshing()
        errorView?.show(
            title: urlError?.code == .notConnectedToInternet ? "网络连接已断开" : "页面加载失败",
            message: "请检查网络连接后重试。"
        )
    }

    private func presentPrompt(
        title: String?,
        message: String?,
        defaultText: String?,
        completion: @escaping (String?) -> Void
    ) {
        guard let presenter = presentingViewController else {
            completion(nil)
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completion(nil) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion(alert.textFields?.first?.text)
        })
        presenter.present(alert, animated: true)
    }
}

extension NavigationCoordinator: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        let decision = navigationPolicy.decision(
            for: url,
            sourceURL: webView.url,
            isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true,
            navigationType: navigationAction.navigationType
        )
        switch decision {
        case .allow:
            if navigationAction.targetFrame?.isMainFrame != false {
                failedRequest = navigationAction.request
            }
            decisionHandler(.allow)
        case .authenticate:
            decisionHandler(.cancel)
            authenticationCoordinator.start(request: navigationAction.request)
        case .inspectResponse:
            decisionHandler(.allow)
        case .openExternally:
            decisionHandler(.cancel)
            openExternally(url)
        case .block:
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !navigationResponse.canShowMIMEType || navigationResponse.isAttachment {
            decisionHandler(.download)
        } else if navigationResponse.isForMainFrame,
                  let url = navigationResponse.response.url,
                  !navigationPolicy.isOfficialOpenAIURL(url),
                  !navigationPolicy.isAuthenticationTransition(from: webView.url, to: url) {
            decisionHandler(.cancel)
            openExternally(url)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        downloadCoordinator.handle(download)
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        downloadCoordinator.handle(download)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        failedRequest = nil
        webView.scrollView.refreshControl?.endRefreshing()
        errorView?.isHidden = true
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorView?.isHidden = true
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        showLoadError(error)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        showLoadError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView.url != nil {
            webView.reload()
        } else {
            webView.load(URLRequest(url: recoveryURL))
        }
    }
}

extension NavigationCoordinator: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else {
            return nil
        }

        switch navigationPolicy.popupDecision(for: url, sourceURL: webView.url) {
        case .allow:
            if url.scheme?.lowercased() == "about" {
                return authenticationCoordinator.openPopup(
                    configuration: configuration,
                    sourceURL: webView.url
                )
            }
            webView.load(navigationAction.request)
            return nil
        case .authenticate, .inspectResponse:
            // 登录弹窗或弹出的第三方认证页面在受控认证 WebView 中打开
            return authenticationCoordinator.openPopup(
                configuration: configuration,
                sourceURL: webView.url
            )
        case .openExternally:
            // 严防误伤认证 URL：如果涉及 auth/login/openai，仍在内部打开
            if navigationPolicy.isOfficialOpenAIURL(url) || navigationPolicy.isAuthenticationContext(url) {
                webView.load(navigationAction.request)
                return nil
            }
            openExternally(url)
            return nil
        case .block:
            return nil
        }
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        var components = URLComponents()
        components.scheme = origin.protocol
        components.host = origin.host
        components.port = origin.port == 0 ? nil : origin.port
        if let url = components.url, navigationPolicy.isOfficialOpenAIURL(url) {
            decisionHandler(.prompt)
        } else {
            decisionHandler(.deny)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        guard let presenter = presentingViewController else {
            completionHandler()
            return
        }
        let alert = UIAlertController(title: webView.url?.host, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler() })
        presenter.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let presenter = presentingViewController else {
            completionHandler(false)
            return
        }
        let alert = UIAlertController(title: webView.url?.host, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        presenter.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        presentPrompt(
            title: webView.url?.host,
            message: prompt,
            defaultText: defaultText,
            completion: completionHandler
        )
    }
}

private extension WKNavigationResponse {
    var isAttachment: Bool {
        guard let response = response as? HTTPURLResponse else { return false }
        return response.allHeaderFields.contains { key, value in
            String(describing: key).caseInsensitiveCompare("Content-Disposition") == .orderedSame
                && String(describing: value).lowercased().contains("attachment")
        }
    }
}
