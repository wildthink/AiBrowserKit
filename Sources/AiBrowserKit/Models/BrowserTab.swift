#if canImport(AppKit)
import Foundation
import WebKit

/// Which device rendition a tab requests from the page — affects both the reported
/// user agent and WebKit's own content-mode negotiation, which sites can key off
/// independently of the UA string. Change together via `setDeviceMode(_:)`, not by
/// setting `webView.customUserAgent` directly, or the two can disagree.
public enum DeviceMode: String, Sendable {
    case desktop
    case mobile
}

/// Model for a single browser tab.
@MainActor
@Observable
public final class BrowserTab: Identifiable {
    /// Stable tab identifier used for UI selection.
    public let id: String
    /// Observable page state mirrored from the underlying web view.
    public let state: WebViewState
    /// Backing WebKit view for this tab.
    public let webView: WKWebView

    /// True until the user navigates — used to show the new tab landing page.
    public var isBlank: Bool = true

    /// Device rendition this tab currently requests. Defaults to `.desktop`, which means
    /// `customUserAgent` is left `nil` — WKWebView's own real UA — rather than a forced
    /// constant.
    public var deviceMode: DeviceMode = .desktop

    /// User-facing tab title derived from the current page.
    public var title: String { state.pageTitle.isEmpty ? "New Tab" : state.pageTitle }
    /// URL string shown in browser controls.
    public var displayURL: String { state.currentURL?.absoluteString ?? "" }
    /// Indicates whether the tab is currently loading content.
    public var isLoading: Bool { state.isLoading }

    /// Creates a browser tab and optionally loads an initial URL.
    ///
    /// - Parameters:
    ///   - url: Optional URL to load after creation.
    ///   - consoleStore: Optional console store for JavaScript log interception.
    public init(url: URL? = nil, consoleStore: ConsoleLogStore? = nil) {
        self.id = UUID().uuidString
        self.state = WebViewState()
        self.webView = WebViewFactory.makeWebView(state: state, consoleStore: consoleStore)
        if let url {
            isBlank = false
            webView.load(URLRequest(url: url))
        }
    }

    /// Resolves user input and navigates the web view.
    ///
    /// - Parameter urlString: Raw address-bar input or search text.
    public func navigate(to urlString: String) {
        guard let url = BrowserURLResolver.resolve(input: urlString) else { return }
        isBlank = false
        webView.load(URLRequest(url: url))
    }

    /// Navigates to the previous history item when available.
    public func goBack() { webView.goBack() }
    /// Navigates to the next history item when available.
    public func goForward() { webView.goForward() }
    /// Reloads the current page.
    public func reload() { webView.reload() }
    /// Stops the current navigation.
    public func stopLoading() { webView.stopLoading() }

    /// Cycles through system, light, and dark appearance overrides.
    public func cycleTheme() {
        state.themeOverride = state.themeOverride.next
        applyTheme()
    }

    /// Applies the selected appearance override to the web view and reloads.
    public func applyTheme() {
        webView.appearance = state.themeOverride.nsAppearance
        webView.reload()
    }

    /// Switches this tab's requested device rendition and reloads to apply it.
    ///
    /// Sets `customUserAgent` and `preferredContentMode` together, since sites can key off
    /// either independently — changing only one gives an inconsistent (and easier to detect
    /// as spoofed) combination.
    public func setDeviceMode(_ mode: DeviceMode) {
        deviceMode = mode
        switch mode {
        case .desktop:
            webView.customUserAgent = nil
            webView.configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        case .mobile:
            webView.customUserAgent = WebViewStore.iPhoneUserAgent
            webView.configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        webView.reload()
    }
}
#endif
