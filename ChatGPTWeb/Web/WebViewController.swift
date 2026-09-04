import UIKit
import WebKit

final class WebViewController: UIViewController {
    private static let homeURL = URL(string: "https://chatgpt.com/")!

    private let webView = WebViewFactory.makeWebView()
    private let errorView = WebErrorView()
    private lazy var navigationCoordinator = NavigationCoordinator(
        presentingViewController: self,
        webView: webView,
        errorView: errorView
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        navigationCoordinator.start()
        loadHomePage()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        webView.translatesAutoresizingMaskIntoConstraints = false
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(errorView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorView.topAnchor.constraint(equalTo: webView.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: webView.bottomAnchor)
        ])

        errorView.isHidden = true
        errorView.onRetry = { [weak self] in
            self?.navigationCoordinator.retryAfterFailure()
        }

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshPage(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }

    private func loadHomePage() {
        var request = URLRequest(url: Self.homeURL)
        // 允许优先使用本地协议缓存（HTML/CSS/JS/字体等离线快速复用）
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = 30.0
        webView.load(request)
    }

    @objc private func refreshPage(_ sender: UIRefreshControl) {
        webView.reload()
    }
}
