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
        let stem = result.source.sourceURL.deletingPathExtension().lastPathComponent
        var index = 1
        var shortenNames = false
        let reportedLimit = pathconf(directory.path, _PC_NAME_MAX)
        let nameByteLimit = reportedLimit > 0 ? Int(reportedLimit) : 255
        func folded(_ name: String) -> String {
            name.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        }
        // Cooperative processes lock the directory; O_EXCL also protects against other writers.
        let lockURL = directory.appendingPathComponent(".airu-export.lock")
        let lockFD = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard lockFD >= 0 else { throw Self.creationError(errno) }
        defer { close(lockFD) }
        while flock(lockFD, LOCK_EX | LOCK_NB) != 0 { try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(20)) }
        defer { flock(lockFD, LOCK_UN) }
        let existing = Set(try Files.fm.contentsOfDirectory(atPath: directory.path).map(folded))
        while true {
            try Task.checkCancellation()
            let suffix = (result.options.upscale.map { "-upscaled-\($0)x" } ?? "-comp") + (index == 1 ? "" : "-\(index)") + "." + result.selectedFormat.fileExtension
            let name = try Self.filename(stem: stem, suffix: suffix, byteLimit: shortenNames ? nameByteLimit : nil)
            if existing.contains(folded(name)) { index += 1; continue }
            let destination = directory.appendingPathComponent(name)
            if destination.standardizedFileURL == result.source.sourceURL.standardizedFileURL { index += 1; continue }
            let fd = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
            if fd < 0 {
                let reason = errno
                if reason == EEXIST { index += 1; continue }
                // Try the complete Unicode name first: APFS may permit more UTF-8
                // bytes than NAME_MAX. Shorten only when this filesystem rejects it.
                if reason == ENAMETOOLONG && !shortenNames { shortenNames = true; continue }
                throw Self.creationError(reason)
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
    private static func filename(stem: String, suffix: String, byteLimit: Int?) throws -> String {
        guard let byteLimit else { return stem + suffix }
        let budget = byteLimit - suffix.utf8.count
        guard budget > 0 else { throw AiruError("filenameTooLong", "Export suffix exceeds the destination's filename limit") }
        var shortened = ""
        var bytes = 0
        // Normalize and keep entire grapheme clusters; never split an emoji or accent.
        for character in stem.precomposedStringWithCanonicalMapping {
            let count = String(character).utf8.count
            if bytes + count > budget { break }
            shortened.append(character); bytes += count
        }
        if shortened.isEmpty {
            guard budget >= 5 else { throw AiruError("filenameTooLong", "No filename fits the destination's limit") }
            shortened = "image"
        }
        return shortened + suffix
    }
    private static func creationError(_ reason: Int32) -> AiruError {
        if [EACCES, EPERM, EROFS].contains(reason) {
            return AiruError("authorizationRequired", "Cannot create export file; select a writable folder")
        }
        if reason == ENAMETOOLONG {
            return AiruError("filenameTooLong", "Export filename or destination path exceeds the filesystem limit")
        }
        return AiruError("exportFailed", "Cannot create export file: \(String(cString: strerror(reason)))")
    }
}
