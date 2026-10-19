import Foundation
import Darwin

public actor ExportManager {
    public let cache: CompressionCache
    public init(cache: CompressionCache) { self.cache = cache }
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/Airu Compressed", isDirectory: true)
    }
    /// Stage 2 should respond to authorizationRequired with NSOpenPanel and a security-scoped bookmark.
    public func export(cacheKey: String, to directory: URL = ExportManager.defaultDirectory) async throws -> URL {
        let result = try await cache.require(cacheKey)
        try Task.checkCancellation()
        do { try Files.directory(directory) }
        catch { throw AiruError("authorizationRequired", "Select a writable export folder: \(error.localizedDescription)") }
        let stem = result.source.sourceURL.deletingPathExtension().lastPathComponent + "-comp"
        var index = 1
        func folded(_ name: String) -> String {
            name.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        }
        // Cooperative processes lock the directory; O_EXCL also protects against other writers.
        let lockURL = directory.appendingPathComponent(".airu-export.lock")
        let lockFD = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard lockFD >= 0 else { throw AiruError("authorizationRequired", "Select a writable export folder") }
        defer { close(lockFD) }
        while flock(lockFD, LOCK_EX | LOCK_NB) != 0 { try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(20)) }
        defer { flock(lockFD, LOCK_UN) }
        let existing = Set(try Files.fm.contentsOfDirectory(atPath: directory.path).map(folded))
        while true {
            try Task.checkCancellation()
            let name = stem + (index == 1 ? "" : "-\(index)") + "." + result.selectedFormat.fileExtension
            index += 1
            if existing.contains(folded(name)) { continue }
            let destination = directory.appendingPathComponent(name)
            if destination.standardizedFileURL == result.source.sourceURL.standardizedFileURL { continue }
            let fd = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
            if fd < 0 {
                if errno == EEXIST { continue }
                throw AiruError("authorizationRequired", "Cannot create export file; select a writable folder")
            }
            let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            do {
                let input = try FileHandle(forReadingFrom: result.cachedFileURL)
                defer { try? input.close() }
                while let data = try input.read(upToCount: 1 << 20), !data.isEmpty {
                    try Task.checkCancellation(); try output.write(contentsOf: data)
                }
                try output.synchronize(); try output.close()
                guard try Files.digest(destination) == result.outputSHA256 else { throw AiruError("exportFailed", "Export checksum mismatch") }
                guard try Files.digest(result.source.sourceURL) == result.source.contentSHA256 else {
                    throw AiruError("sourceChanged", "Source changed during export; prepare it again")
                }
                return destination
            } catch { try? output.close(); Files.remove(destination); throw error }
        }
    }
}
