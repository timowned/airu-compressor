import Foundation

public actor CompressionCache {
    public nonisolated let root: URL
    public init(root: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Airu/v1")) {
        self.root = root.standardizedFileURL
    }
    public static func key(source: ImageInfo, options: OptimizationOptions, toolchainFingerprint: String) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(options)
        data.append(contentsOf: "airu-engine-v3|\(source.sourceURL.path)|\(source.contentSHA256)|\(toolchainFingerprint)".utf8)
        return Files.hash(data)
    }
    private func directory(_ key: String) throws -> URL {
        guard key.count == 64, key.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else { throw AiruError("invalidCacheKey", "Cache keys must be lowercase SHA-256 values") }
        return root.appendingPathComponent(key, isDirectory: true)
    }
    public func lookup(_ key: String, validateSource: Bool = true) throws -> CompressionResult? {
        let directory = try directory(key)
        guard Files.fm.fileExists(atPath: directory.path) else { return nil }
        do {
            let result = try JSONDecoder().decode(CompressionResult.self, from: Data(contentsOf: directory.appendingPathComponent("result.json")))
            try validate(result, expectedDirectory: directory, validateSource: validateSource)
            return result
        } catch is CancellationError { throw CancellationError() }
        catch { Files.remove(directory); return nil }
    }
    public func require(_ key: String) throws -> CompressionResult {
        guard let result = try lookup(key) else { throw AiruError("cacheInvalid", "Cached output is missing, damaged, or the source changed; prepare it again") }
        return result
    }
    func validate(_ result: CompressionResult, expectedDirectory: URL, validateSource: Bool) throws {
        let url = expectedDirectory.appendingPathComponent("output.\(result.selectedFormat.fileExtension)")
        guard result.cachedFileURL.standardizedFileURL == url.standardizedFileURL,
              try Files.size(url) == result.outputSize, try Files.digest(url) == result.outputSHA256 else {
            throw AiruError("cacheInvalid", "Cached output checksum mismatch")
        }
        if try validateSource && Files.digest(result.source.sourceURL) != result.source.contentSHA256 {
            throw AiruError("sourceChanged", "Source changed after preparation")
        }
        let info = try ImageAnalyzer().analyze(url)
        let resize = result.options.upscale.map { ResizeOptions.scale(Double($0) * 100) } ?? result.options.resize
        let target = try resize?.dimensions(width: result.source.width, height: result.source.height)
        guard info.width == (target?.width ?? result.source.width), info.height == (target?.height ?? result.source.height), info.format == result.selectedFormat,
              !(result.referenceHasTransparency ?? result.source.hasTransparency) || info.hasTransparency else { throw AiruError("cacheInvalid", "Cached image validation failed") }
        guard (result.verification == .unchangedOriginal && result.outputSHA256 == result.source.contentSHA256) ||
              (result.verification == .ssimulacra2 && (result.perceptualScore ?? -.infinity) >= result.options.minimumScore) else {
            throw AiruError("cacheInvalid", "Cached result has no valid quality verification")
        }
    }
    func store(key: String, info: ImageInfo, options: OptimizationOptions, candidate: OptimizedCandidate?,
               records: [CandidateRecord], original: Bool, referenceHasTransparency: Bool? = nil) throws -> CompressionResult {
        if let existing = try lookup(key) { return existing }
        let final = try directory(key)
        try Files.directory(root)
        let staging = root.appendingPathComponent(".staging-\(UUID())")
        try Files.directory(staging)
        defer { Files.remove(staging) }
        let format = original ? info.format : candidate!.record.format
        let file = staging.appendingPathComponent("output.\(format.fileExtension)")
        try Files.fm.copyItem(at: original ? info.sourceURL : candidate!.url, to: file)
        try Task.checkCancellation()
        guard try Files.digest(info.sourceURL) == info.contentSHA256 else { throw AiruError("sourceChanged", "Source changed during preparation") }
        let result = CompressionResult(cacheKey: key, source: info, options: options, selectedFormat: format,
            outputSize: try Files.size(file), perceptualScore: original ? nil : candidate!.record.score,
            verification: original ? .unchangedOriginal : .ssimulacra2, alreadyOptimized: original,
            cachedFileURL: final.appendingPathComponent(file.lastPathComponent), outputSHA256: try Files.digest(file), candidates: records,
            savingsPercentage: 100 * (1 - Double(try Files.size(file)) / Double(max(1, info.fileSize))), referenceHasTransparency: referenceHasTransparency)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(result).write(to: staging.appendingPathComponent("result.json"), options: .atomic)
        do { try Files.fm.moveItem(at: staging, to: final) }
        catch {
            // Another process can have prepared the same deterministic entry.
            if let existing = try lookup(key) { return existing }
            throw error
        }
        return result
    }
    public func remove(_ key: String) throws { Files.remove(try directory(key)) }
    public func purge(olderThan date: Date) throws {
        guard Files.fm.fileExists(atPath: root.path) else { return }
        for url in try Files.fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) {
            if let modified = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, modified < date { Files.remove(url) }
        }
    }
}
