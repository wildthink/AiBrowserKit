#if canImport(AppKit)
import SwiftUI
import WebKit

public struct BrowserNavigationBar: View {
    let tab: BrowserTab
    var onAddToPinned: (() -> Void)?
    var onToggleBookmarks: (() -> Void)?
    var onToggleConsole: (() -> Void)?
    var onStartSelection: ((ScreenshotDestination) -> Void)?
    var showingBookmarks: Bool = false
    var showingConsole: Bool = false

    @Environment(BrowserEnvironment.self) private var browserEnv
    @State private var urlText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var urlFieldFocused: Bool

    /// Creates the browser navigation bar for a specific tab.
    ///
    /// - Parameters:
    ///   - tab: Active tab model to control.
    ///   - onAddToPinned: Optional callback for pinning the current page.
    ///   - onToggleBookmarks: Optional callback for bookmark panel visibility.
    ///   - onToggleConsole: Optional callback for console panel visibility.
    ///   - onStartSelection: Optional callback to start area screenshot selection.
    ///   - showingBookmarks: Whether bookmarks panel is currently visible.
    ///   - showingConsole: Whether console panel is currently visible.
    public init(
        tab: BrowserTab,
        onAddToPinned: (() -> Void)? = nil,
        onToggleBookmarks: (() -> Void)? = nil,
        onToggleConsole: (() -> Void)? = nil,
        onStartSelection: ((ScreenshotDestination) -> Void)? = nil,
        showingBookmarks: Bool = false,
        showingConsole: Bool = false
    ) {
        self.tab = tab
        self.onAddToPinned = onAddToPinned
        self.onToggleBookmarks = onToggleBookmarks
        self.onToggleConsole = onToggleConsole
        self.onStartSelection = onStartSelection
        self.showingBookmarks = showingBookmarks
        self.showingConsole = showingConsole
    }

    private var isBookmarked: Bool {
        if let override = browserEnv.isBookmarkedOverride {
            return override(tab.state.currentURL)
        }
        return browserEnv.bookmarks.isBookmarked(url: tab.state.currentURL)
    }

    /// Renders navigation controls, address field, and page action buttons.
    public var body: some View {
        HStack(spacing: 8) {
            // Back / Forward
            HStack(spacing: 2) {
                navButton("chevron.left", enabled: tab.state.canGoBack) { tab.goBack() }
                navButton("chevron.right", enabled: tab.state.canGoForward) { tab.goForward() }
            }

            // Reload / Stop
            if tab.state.isLoading {
                navButton("xmark", enabled: true) { tab.stopLoading() }
            } else {
                navButton("arrow.clockwise", enabled: true) { tab.reload() }
            }

            // URL bar
            HStack(spacing: 6) {
                if !isEditing {
                    if tab.state.isSecure {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.green)
                    } else if tab.state.currentURL?.scheme == "http" {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.yellow)
                    }
                }

                TextField("Search or enter URL", text: $urlText, onEditingChanged: { editing in
                    isEditing = editing
                    if editing {
                        urlText = tab.state.currentURL?.absoluteString ?? ""
                    }
                })
                .textFieldStyle(.plain)
                .font(.body)
                .focused($urlFieldFocused)
                .onSubmit {
                    tab.navigate(to: urlText)
                    urlFieldFocused = false
                    isEditing = false
                }

                if tab.state.currentURL != nil {
                    Button {
                        let title = tab.state.pageTitle.isEmpty
                            ? (tab.state.currentURL?.host() ?? "Bookmark")
                            : tab.state.pageTitle
                        // Host apps may claim the star for their own store (returns true);
                        // otherwise fall through to the built-in bookmarks.jsonl.
                        if let url = tab.state.currentURL,
                           browserEnv.onToggleBookmark?(title, url) == true
                        {
                            // consumed by host
                        } else {
                            browserEnv.bookmarks.toggleBookmark(
                                title: title,
                                url: tab.state.currentURL
                            )
                        }
                    } label: {
                        Image(systemName: isBookmarked ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isBookmarked ? Color.yellow : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isBookmarked ? "Remove bookmark" : "Bookmark this page")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isEditing ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08),
                        lineWidth: isEditing ? 1.5 : 0.5
                    )
            )

            // Action buttons
            HStack(spacing: 2) {
                navButton(tab.state.themeOverride.icon, enabled: true) { tab.cycleTheme() }
                    .help(tab.state.themeOverride.label)

                screenshotMenu

                navButton("safari", enabled: tab.state.currentURL != nil) {
                    if let url = tab.state.currentURL { NSWorkspace.shared.open(url) }
                }
                .help("Open in Safari")

                navButton("doc.on.doc", enabled: tab.state.currentURL != nil) {
                    if let url = tab.state.currentURL {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                }
                .help("Copy URL")

                if browserEnv.onAddToClipboard != nil {
                    navButton("text.badge.plus", enabled: tab.state.currentURL != nil) {
                        copySelectedTextToHost()
                    }
                    .help("Copy selected text to app clipboard")
                }

                if let onAddToPinned {
                    navButton("pin", enabled: tab.state.currentURL != nil) { onAddToPinned() }
                        .help("Pin to sidebar")
                }

                if let onToggleBookmarks {
                    navButton("book", enabled: true, highlighted: showingBookmarks) { onToggleBookmarks() }
                        .help(showingBookmarks ? "Hide bookmarks" : "Show bookmarks")
                }

                if let onToggleConsole {
                    navButton("terminal", enabled: true, highlighted: showingConsole) { onToggleConsole() }
                        .help(showingConsole ? "Hide console" : "Show console")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: tab.state.currentURL) { _, newURL in
            if !isEditing { urlText = displayString(for: newURL) }
        }
        .onChange(of: tab.id) { _, _ in
            urlText = displayString(for: tab.state.currentURL)
            isEditing = false
        }
        .onAppear {
            urlText = displayString(for: tab.state.currentURL)
        }
    }

    private var screenshotMenu: some View {
        Menu {
            Section("Visible Area") {
                Button {
                    captureVisible(tab.webView, to: .clipboard)
                } label: {
                    Label("Copy to clipboard", systemImage: "doc.on.clipboard")
                }
                Button {
                    captureVisible(tab.webView, to: .file)
                } label: {
                    Label("Save to file", systemImage: "square.and.arrow.down")
                }
                if browserEnv.onAddToClipboard != nil {
                    Button {
                        captureVisibleToHost()
                    } label: {
                        Label("Add to app clipboard", systemImage: "doc.on.clipboard.fill")
                    }
                }
            }
            if let onStartSelection {
                Section("Selection") {
                    Button {
                        onStartSelection(.clipboard)
                    } label: {
                        Label("Select & copy", systemImage: "rectangle.dashed.badge.record")
                    }
                    Button {
                        onStartSelection(.file)
                    } label: {
                        Label("Select & save", systemImage: "rectangle.dashed")
                    }
                    if browserEnv.onAddToClipboard != nil {
                        Button {
                            onStartSelection(.hostClipboard)
                        } label: {
                            Label("Select & add to app clipboard", systemImage: "doc.badge.plus")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "camera")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tab.state.currentURL != nil ? Color.primary : Color.primary.opacity(0.25))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
        .disabled(tab.state.currentURL == nil)
        .help("Screenshot")
    }

    private func captureVisibleToHost() {
        let sourceURL = tab.state.currentURL?.absoluteString
        Task {
            let config = WKSnapshotConfiguration()
            guard let image = try? await tab.webView.takeSnapshot(configuration: config) else { return }
            browserEnv.onAddToClipboard?(.init(kind: .image(image), sourceURL: sourceURL))
        }
    }

    private func copySelectedTextToHost() {
        let sourceURL = tab.state.currentURL?.absoluteString
        tab.webView.evaluateJavaScript("window.getSelection().toString()") { result, _ in
            MainActor.assumeIsolated {
                guard let text = result as? String, !text.isEmpty else { return }
                self.browserEnv.onAddToClipboard?(.init(kind: .text(text), sourceURL: sourceURL))
            }
        }
    }

    private func displayString(for url: URL?) -> String {
        guard let url else { return "" }
        var str = url.absoluteString
        if str.hasPrefix("https://") { str = String(str.dropFirst(8)) }
        if str.hasPrefix("http://") { str = String(str.dropFirst(7)) }
        if str.hasSuffix("/") { str = String(str.dropLast()) }
        return str
    }

    private func navButton(_ icon: String, enabled: Bool, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(highlighted ? Color.accentColor : (enabled ? Color.primary : Color.primary.opacity(0.25)))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Visible area capture

@MainActor
private func captureVisible(_ webView: WKWebView, to destination: ScreenshotDestination) {
    Task {
        let config = WKSnapshotConfiguration()
        guard let image = try? await webView.takeSnapshot(configuration: config) else { return }
        deliverScreenshot(image, to: destination)
    }
}
#endif
