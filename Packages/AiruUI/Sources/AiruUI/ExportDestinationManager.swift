import AppKit
import Observation
import AiruCore

/// Keeps source/folder access alive while asynchronous helper processes need it.
final class ScopedURL: @unchecked Sendable {
    let url: URL
    private let accessed: Bool
    init(_ url: URL) { self.url = url; accessed = url.startAccessingSecurityScopedResource() }
    deinit { if accessed { url.stopAccessingSecurityScopedResource() } }
}

@MainActor @Observable public final class ExportDestinationManager {
    public private(set) var defaultURL: URL
    private var defaultAccess: ScopedURL
    private let preferences: UserDefaults
    private let bookmarkKey = "Airu.authorizedExportFolder"
    public init(preferences: UserDefaults = .standard, initialURL: URL? = nil) {
        self.preferences = preferences
        var selected = initialURL ?? ExportManager.defaultDirectory
        if initialURL == nil, let data = preferences.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil,
                                  bookmarkDataIsStale: &stale), !stale { selected = url }
        }
        defaultURL = selected; defaultAccess = ScopedURL(selected)
    }
    public func setDefault(_ url: URL, persist: Bool = true) throws {
        let access = ScopedURL(url)
        if persist {
            let data: Data
            do { data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) }
            catch { data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) }
            preferences.set(data, forKey: bookmarkKey)
        }
        defaultURL = url; defaultAccess = access
    }
    public func chooseFolder(startingAt url: URL? = nil) async throws -> URL {
        let panel = NSOpenPanel()
        panel.title = "Choose export folder"; panel.prompt = "Choose Folder"
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.canCreateDirectories = true
        panel.directoryURL = url ?? defaultURL
        let response = await withCheckedContinuation { continuation in panel.begin { continuation.resume(returning: $0) } }
        guard response == .OK, let selected = panel.url else { throw AiruError("userCancelled", "Folder selection cancelled") }
        return selected
    }
}
