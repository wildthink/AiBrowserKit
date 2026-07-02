#if canImport(AppKit)
import Foundation
import AppKit

// MARK: - AiBrowserClipboardContent

/// Content delivered to the host app's clipboard handler from AiBrowserKit.
public struct AiBrowserClipboardContent: Sendable {
    /// Describes the clipboard payload type.
    public enum Kind: @unchecked Sendable {
        /// Plain text extracted from the current web view selection.
        case text(String)
        /// Raster image captured from the web view.
        case image(NSImage)
    }
    /// Content payload to be passed back to the host app.
    public let kind: Kind
    /// Optional URL string where the copied content originated.
    public let sourceURL: String?

    /// Creates a clipboard payload for host integration.
    ///
    /// - Parameters:
    ///   - kind: The payload kind and value.
    ///   - sourceURL: The page URL associated with the copied data.
    public init(kind: Kind, sourceURL: String?) {
        self.kind = kind
        self.sourceURL = sourceURL
    }
}

// MARK: - BrowserEnvironment

/// Shared browser environment injected at app root.
/// Holds all browser-related state managers.
@MainActor
@Observable
public final class BrowserEnvironment {
    /// Shared multi-tab browser state and tab lifecycle manager.
    public let browserVM: BrowserViewModel
    /// Bookmark and folder persistence service.
    public let bookmarks: BookmarkService
    /// Favicon fetching and caching service.
    public let favicons: FaviconService
    /// Pinned-site persistence and ordering service.
    public let pinnedSites: PinnedSiteStore
    /// Reusable web view cache for pinned sites.
    public let webViewCache: PinnedSiteWebViewCache
    /// In-memory JavaScript console message store.
    public let consoleStore: ConsoleLogStore

    /// Optional callback wired up by the host app to receive content that
    /// should be added to the app-wide clipboard store.
    public var onAddToClipboard: ((AiBrowserClipboardContent) -> Void)? = nil

    /// Optional host-app hook intercepting the navigation bar's bookmark star.
    /// Return `true` to consume the toggle (the built-in `BookmarkService` is skipped),
    /// `false` to fall through to the default bookmarks.jsonl behavior.
    public var onToggleBookmark: ((_ title: String, _ url: URL) -> Bool)? = nil

    /// Optional host-app hook overriding the star's filled state. When set, it fully
    /// replaces the `BookmarkService` lookup — pair it with `onToggleBookmark`.
    public var isBookmarkedOverride: ((URL?) -> Bool)? = nil

    /// Creates the browser environment and wires all shared services.
    ///
    /// - Parameter storageDirectory: Optional base directory for persisted data.
    ///   When omitted, the package default Application Support location is used.
    public init(storageDirectory: URL? = nil) {
        let dir = AiBrowserStorage.directory(custom: storageDirectory)
        let console = ConsoleLogStore()
        self.consoleStore = console
        self.browserVM   = BrowserViewModel(consoleStore: console)
        self.bookmarks   = BookmarkService(storageDirectory: dir)
        self.favicons    = FaviconService(storageDirectory: dir)
        self.pinnedSites = PinnedSiteStore(storageDirectory: dir)
        self.webViewCache = PinnedSiteWebViewCache()
    }
}
#endif
