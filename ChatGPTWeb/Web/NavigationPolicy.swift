import Foundation
import WebKit

enum NavigationDecision {
    case allow
    case authenticate
    case inspectResponse
    case openExternally
    case block
}

struct NavigationPolicy {
    private let officialDomainRoots = ["chatgpt.com", "openai.com"]
    private let authenticationTerms = [
        "auth", "authorize", "login", "oauth", "signin", "sign-in", "sso"
    ]

    func decision(
        for url: URL,
        sourceURL: URL?,
        isMainFrame: Bool,
        navigationType: WKNavigationType
    ) -> NavigationDecision {
        guard isMainFrame else { return .allow }

        switch url.scheme?.lowercased() {
        case "https":
            if isOfficialOpenAIURL(url) {
                return .allow
            }
            if isAuthenticationTransition(from: sourceURL, to: url) {
                return .authenticate
            }
            if navigationType == .linkActivated {
                return .openExternally
            }
            return .inspectResponse
        case "http":
            return .openExternally
        case "about", "blob":
            return .allow
        case "data", "file", "javascript":
            return .block
        case .none:
            return .block
        default:
            return .openExternally
        }
    }

    func popupDecision(for url: URL, sourceURL: URL?) -> NavigationDecision {
        if isOfficialOpenAIURL(url) {
            return .allow
        }
        if isAuthenticationTransition(from: sourceURL, to: url) {
            return .authenticate
        }
        return decision(
            for: url,
            sourceURL: sourceURL,
            isMainFrame: true,
            navigationType: .linkActivated
        )
    }

    func isOfficialOpenAIURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        guard let host = normalizedHost(of: url) else { return false }
        return officialDomainRoots.contains { root in
            host == root || host.hasSuffix("." + root)
        }
    }

    func isChatGPTURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = normalizedHost(of: url) else {
            return false
        }
        return host == "chatgpt.com" || host.hasSuffix(".chatgpt.com")
    }

    func isAuthenticationTransition(from sourceURL: URL?, to destinationURL: URL) -> Bool {
        guard let sourceURL, isOfficialOpenAIURL(sourceURL) else { return false }
        return isAuthenticationContext(sourceURL) || isAuthenticationContext(destinationURL)
    }

    func isAuthenticationContext(_ url: URL) -> Bool {
        let host = normalizedHost(of: url) ?? ""
        let searchableValue = ([host, url.path, url.query ?? ""]).joined(separator: " ").lowercased()
        return authenticationTerms.contains { searchableValue.contains($0) }
    }

    private func normalizedHost(of url: URL) -> String? {
        url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
