import SwiftUI
import WebKit
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

// MARK: - ScreenshotDestination

#if canImport(AppKit)
/// Destination for screenshot capture output.
public enum ScreenshotDestination: Sendable {
    /// Copy the screenshot to the system clipboard.
    case clipboard
    /// Prompt for a location and save as PNG.
    case file
    /// Send the screenshot to host-app clipboard integration.
    case hostClipboard
}

@MainActor
/// Delivers a captured image to the selected destination.
///
/// - Parameters:
///   - image: Captured screenshot image.
///   - destination: Output destination for the image.
public func deliverScreenshot(_ image: NSImage, to destination: ScreenshotDestination) {
    switch destination {
    case .clipboard:
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    case .file:
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "screenshot.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    case .hostClipboard:
        break
    }
}
#endif

// MARK: - WebViewThemeOverride

/// Theme override modes supported by AiBrowserKit web views.
public enum WebViewThemeOverride: String, Sendable {
    case system
    case light
    case dark

    /// Next theme mode in the user-facing cycle.
    public var next: WebViewThemeOverride {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    /// SF Symbol used for the mode toggle button.
    public var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// User-facing label for the current mode.
    public var label: String {
        switch self {
        case .system: "Follow system"
        case .light: "Light mode"
        case .dark: "Dark mode"
        }
    }

    #if canImport(AppKit)
    /// AppKit appearance mapped from the selected override.
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    #endif
}

// MARK: - WebViewState

/// Observable state for a single WKWebView instance.
@MainActor
@Observable
public final class WebViewState {
    /// Current top-level page URL.
    public var currentURL: URL?
    /// Current page title as reported by WebKit.
    public var pageTitle: String = ""
    /// Indicates whether navigation is in progress.
    public var isLoading: Bool = false
    /// Estimated load progress in the range `0...1`.
    public var estimatedProgress: Double = 0
    /// Whether back navigation is currently possible.
    public var canGoBack: Bool = false
    /// Whether forward navigation is currently possible.
    public var canGoForward: Bool = false
    /// Whether the current top-level URL uses HTTPS.
    public var isSecure: Bool = false
    /// Whether all loaded resources are secure.
    public var hasOnlySecureContent: Bool = false
    /// Last navigation error message, when present.
    public var error: String?
    /// Theme override currently selected for the web view.
    public var themeOverride: WebViewThemeOverride = .system

    /// Creates empty web view state.
    public init() {}
}

// MARK: - WebViewStore

/// Shared WebKit configuration for all in-app web views.
@MainActor
public enum WebViewStore {
    /// Shared website data store used by all web views.
    public static let dataStore = WKWebsiteDataStore.default()

    #if canImport(AppKit)
    /// Matches Safari on macOS 15.5. No longer applied by default (see
    /// `WebViewFactory.makeWebView`) — a hand-maintained UA string drifts out of date and can
    /// misrepresent the actual CPU architecture (this one claims Intel on Apple Silicon
    /// hardware), which is itself a signal bot-detection services check for. Kept only for
    /// `BrowserTab.setDeviceMode(.desktop)`, which explicitly wants a *forced* value distinct
    /// from `customUserAgent == nil` (WKWebView's own, always-accurate default).
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"
    /// Used by `BrowserTab.setDeviceMode(.mobile)` to preview a page's phone rendition from
    /// a macOS host. There's no built-in equivalent on macOS (unlike an iOS build of this
    /// package, which already reports a real iPhone UA natively).
    public static let iPhoneUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
    #else
    /// Matches Safari on iOS 18.5.
    public static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
    #endif

    /// Injects `StealthScript` into every page when `true`. Defaults to `false`: overriding
    /// `navigator.webdriver`, WebGL vendor strings, canvas readback, and similar signals is
    /// itself a well-known automation-toolkit fingerprint that bot-management services (e.g.
    /// Cloudflare) actively check for — several of the script's overrides replace native
    /// functions with JS closures without also patching `Function.prototype.toString`, so
    /// `navigator.permissions.query.toString()` no longer reports `[native code]` the way a
    /// real, untouched browser does. A plain, unmodified WKWebView reads as more "normal" to
    /// these services than one running this script. Opt in only if you have a specific reason
    /// (e.g. scraping a site that fingerprints WKWebView itself) to accept that trade-off.
    public static var stealthModeEnabled: Bool = false

    /// Creates the canonical WebKit configuration for AiBrowserKit web views.
    ///
    /// - Returns: A configured `WKWebViewConfiguration`.
    public static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop

        return config
    }
}

// MARK: - WebViewRepresentable

#if canImport(AppKit)
/// SwiftUI bridge for embedding a `WKWebView` on AppKit platforms.
public struct WebViewRepresentable: NSViewRepresentable {
    /// Backing web view instance to present.
    public let webView: WKWebView

    /// Creates a representable wrapper for a specific web view.
    ///
    /// - Parameter webView: Web view to expose to SwiftUI.
    public init(webView: WKWebView) {
        self.webView = webView
    }

    /// Returns the existing `WKWebView` for SwiftUI.
    public func makeNSView(context: Context) -> WKWebView { webView }
    /// No-op update; state is driven directly by the shared `WKWebView`.
    public func updateNSView(_ nsView: WKWebView, context: Context) {}

    /// Forces this view to exactly the size SwiftUI proposes, instead of falling back to
    /// `WKWebView`'s own intrinsic/fitting size.
    ///
    /// `WKWebView` hosts a deep internal AppKit/Auto Layout hierarchy (content view, scroll
    /// view, and — with `isElementFullscreenEnabled` on — its own fullscreen presentation
    /// machinery), any of which can assert a size preference of its own. Without this
    /// override, SwiftUI may consult that preference when computing this view's size, and a
    /// host that doesn't clip aggressively (an `NSSplitView`-backed container, for instance)
    /// can end up growing to accommodate it — visible as the enclosing window repeatedly
    /// resizing/widening on its own. Returning the proposal verbatim makes this view starve
    /// any such upstream size assertion at the source, without disabling fullscreen support.
    public func sizeThatFits(
        _ proposal: ProposedViewSize, nsView: WKWebView, context: Context
    ) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}
#else
/// SwiftUI bridge for embedding a `WKWebView` on UIKit platforms.
public struct WebViewRepresentable: UIViewRepresentable {
    /// Backing web view instance to present.
    public let webView: WKWebView

    /// Creates a representable wrapper for a specific web view.
    ///
    /// - Parameter webView: Web view to expose to SwiftUI.
    public init(webView: WKWebView) {
        self.webView = webView
    }

    /// Returns the existing `WKWebView` for SwiftUI.
    public func makeUIView(context: Context) -> WKWebView { webView }
    /// No-op update; state is driven directly by the shared `WKWebView`.
    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// See the AppKit `sizeThatFits` override above — same rationale, same fix.
    public func sizeThatFits(
        _ proposal: ProposedViewSize, uiView: WKWebView, context: Context
    ) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}
#endif

// MARK: - WebViewFactory

private let consoleInterceptScript = """
(function() {
    var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.aiBrowserConsole;
    if (!h) return;
    ['log','info','warn','error','debug'].forEach(function(lvl) {
        var orig = console[lvl];
        console[lvl] = function() {
            var msg = Array.prototype.slice.call(arguments).map(function(a) {
                try { return typeof a === 'object' ? JSON.stringify(a) : String(a); } catch(e) { return String(a); }
            }).join(' ');
            try { h.postMessage({ level: lvl, message: msg }); } catch(_) {}
            if (orig) orig.apply(console, arguments);
        };
    });
})();
"""

@MainActor
public enum WebViewFactory {
    /// Builds and wires a `WKWebView` with shared configuration and delegates.
    ///
    /// - Parameters:
    ///   - state: Observable state sink for navigation updates.
    ///   - consoleStore: Optional sink for intercepted JavaScript console events.
    /// - Returns: A fully configured `WKWebView`.
    public static func makeWebView(state: WebViewState, consoleStore: ConsoleLogStore? = nil) -> WKWebView {
        let config = WebViewStore.makeConfiguration()

        let coordinator = WebViewCoordinator(state: state, consoleStore: consoleStore)

        if WebViewStore.stealthModeEnabled {
            let stealthScript = WKUserScript(
                source: StealthScript.source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(stealthScript)
        }

        if consoleStore != nil {
            let script = WKUserScript(source: consoleInterceptScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(script)
            config.userContentController.add(coordinator, name: "aiBrowserConsole")
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        // No customUserAgent assignment here: leaving it nil means WKWebView reports its own
        // real, always-accurate UA (correct OS version and CPU architecture) rather than a
        // hand-maintained constant that can drift out of date. See setDeviceMode(_:) for
        // explicit UA overrides (device-mode preview).
        webView.allowsBackForwardNavigationGestures = true
        #if canImport(AppKit)
        webView.allowsMagnification = true
        #endif

        coordinator.webView = webView
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator

        objc_setAssociatedObject(webView, &WebViewCoordinator.associatedKey, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        coordinator.observeWebView(webView)

        return webView
    }
}

// MARK: - WebViewCoordinator

@MainActor
/// Adapts WebKit delegate callbacks into observable `WebViewState` updates.
public final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    /// Runtime key for associating the coordinator with a web view instance.
    nonisolated(unsafe) public static var associatedKey: UInt8 = 0

    private let state: WebViewState
    private let consoleStore: ConsoleLogStore?
    weak var webView: WKWebView?
    private var observations: [NSKeyValueObservation] = []

    init(state: WebViewState, consoleStore: ConsoleLogStore? = nil) {
        self.state = state
        self.consoleStore = consoleStore
    }

    func observeWebView(_ webView: WKWebView) {
        observations = [
            webView.observe(\.isLoading) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.isLoading = wv.isLoading }
            },
            webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.estimatedProgress = wv.estimatedProgress }
            },
            webView.observe(\.canGoBack) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.canGoBack = wv.canGoBack }
            },
            webView.observe(\.canGoForward) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.canGoForward = wv.canGoForward }
            },
            webView.observe(\.title) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.pageTitle = wv.title ?? "" }
            },
            webView.observe(\.url) { [weak self] wv, _ in
                MainActor.assumeIsolated {
                    self?.state.currentURL = wv.url
                    self?.state.isSecure = wv.url?.scheme == "https"
                }
            },
            webView.observe(\.hasOnlySecureContent) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.hasOnlySecureContent = wv.hasOnlySecureContent }
            },
        ]
    }

    // MARK: - WKScriptMessageHandler

    /// Receives JavaScript console messages bridged from injected page scripts.
    nonisolated public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // WKScriptMessage properties are @MainActor in the new SDK; WKWebView always
        // calls this on the main thread, so assumeIsolated is safe here.
        MainActor.assumeIsolated {
            guard message.name == "aiBrowserConsole",
                  let body = message.body as? [String: Any],
                  let levelRaw = body["level"] as? String,
                  let text = body["message"] as? String
            else { return }
            let level = ConsoleLevel(rawValue: levelRaw) ?? .log
            let source = message.frameInfo.request.url?.absoluteString
            consoleStore?.append(ConsoleEntry(level: level, message: text, source: source))
        }
    }

    // MARK: - WKNavigationDelegate

    /// Handles popup/tab navigation actions by redirecting into the same view.
    nonisolated public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        let url = await MainActor.run { navigationAction.request.url }
        let hasTarget = await MainActor.run { navigationAction.targetFrame != nil }
        guard let url else { return .allow }

        if !hasTarget {
            _ = await MainActor.run { webView.load(URLRequest(url: url)) }
            return .cancel
        }
        return .allow
    }

    /// Persists navigation errors into observable web view state.
    nonisolated public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let message = error.localizedDescription
        MainActor.assumeIsolated { self.state.error = message }
    }

    /// Persists provisional navigation errors except expected cancellation noise.
    nonisolated public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        let message = error.localizedDescription
        MainActor.assumeIsolated { self.state.error = message }
    }

    /// Clears error state once navigation succeeds.
    nonisolated public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { self.state.error = nil }
    }

    // MARK: - WKUIDelegate

    /// Handles requests to open a new window by loading the URL in-place.
    nonisolated public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        MainActor.assumeIsolated {
            if let url = navigationAction.request.url {
                _ = webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    /// Presents a native alert UI for `window.alert`.
    nonisolated public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        #if canImport(AppKit)
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        #else
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                guard let vc = self.rootViewController() else { cont.resume(); return }
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in cont.resume() })
                vc.present(alert, animated: true)
            }
        }
        #endif
    }

    /// Presents a native confirmation UI for `window.confirm`.
    nonisolated public func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
        #if canImport(AppKit)
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            return alert.runModal() == .alertFirstButtonReturn
        }
        #else
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            Task { @MainActor in
                guard let vc = self.rootViewController() else { cont.resume(returning: false); return }
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in cont.resume(returning: true) })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in cont.resume(returning: false) })
                vc.present(alert, animated: true)
            }
        }
        #endif
    }

    /// Presents a native text prompt UI for `window.prompt`.
    nonisolated public func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
        #if canImport(AppKit)
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            input.stringValue = defaultText ?? ""
            alert.accessoryView = input
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? input.stringValue : nil
        }
        #else
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            Task { @MainActor in
                guard let vc = self.rootViewController() else { cont.resume(returning: nil); return }
                let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
                alert.addTextField { tf in tf.text = defaultText }
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    cont.resume(returning: alert.textFields?.first?.text)
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    cont.resume(returning: nil)
                })
                vc.present(alert, animated: true)
            }
        }
        #endif
    }

    // MARK: - iOS helpers

    #if !canImport(AppKit)
    @MainActor
    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
    #endif
}
