import Foundation
import CryptoKit

enum Files {
    static var fm: FileManager { FileManager.default }
    static func size(_ url: URL) throws -> Int64 {
        let attrs = try fm.attributesOfItem(atPath: url.path)
        guard let size = attrs[.size] as? NSNumber else { throw AiruError("io", "Cannot read size: \(url.path)") }
        return size.int64Value
    }
    static func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1 << 20), !data.isEmpty {
            try Task.checkCancellation(); hash.update(data: data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func directory(_ url: URL) throws { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
    static func remove(_ url: URL) { try? fm.removeItem(at: url) }
}
