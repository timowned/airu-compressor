import Foundation

public struct CompressionEngine: Sendable {
    public let tools: Toolchain
    public let cache: CompressionCache
    public init(tools: Toolchain, cache: CompressionCache = CompressionCache()) { self.tools = tools; self.cache = cache }
    public func prepare(_ source: URL, options: OptimizationOptions = .init(), progress: ProgressHandler? = nil) async throws -> CompressionResult {
        try options.validate()
        try Task.checkCancellation()
        await progress?(ProgressUpdate(.analyzing, 0, "Reading and validating image"))
        let info = try ImageAnalyzer().analyze(source)
        let key = try CompressionCache.key(source: info, options: options, toolchainFingerprint: tools.fingerprint())
        if let existing = try await cache.lookup(key) {
            await progress?(ProgressUpdate(.ready, 1, "Reused verified cached output")); return existing
        }
        let work = Files.fm.temporaryDirectory.appendingPathComponent("airu-job-\(UUID())", isDirectory: true)
        try Files.directory(work)
        defer { Files.remove(work) }
        var referenceInfo = info
        if let resize = options.resize {
            let target = try resize.dimensions(width: info.width, height: info.height)
            if target.width != info.width || target.height != info.height {
                let decoded = try await ImageDecoder.decode(source, format: info.format, tools: tools, workspace: work,
                                                           deadline: Date().addingTimeInterval(options.timeoutSeconds))
                let reference = try ImageResizer.resize(decoded, options: resize)
                let url = work.appendingPathComponent("resized-reference.png")
                try Raster.writePNG(reference, to: url)
                referenceInfo = try ImageAnalyzer().analyze(url)
            }
        }
        if referenceInfo.width < 8 || referenceInfo.height < 8, referenceInfo.sourceURL != info.sourceURL {
            throw AiruError("comparisonImageTooSmall", "Resized quality evaluation requires at least 8×8 pixels")
        }
        // The upstream metric explicitly rejects images smaller than 8x8. Never invent a score.
        if referenceInfo.width < 8 || referenceInfo.height < 8 {
            guard options.format == .auto || options.format.imageFormat == info.format else {
                throw AiruError("comparisonImageTooSmall", "SSIMULACRA2 requires at least 8×8 pixels; use Auto to keep an unchanged copy")
            }
            let result = try await cache.store(key: key, info: info, options: options, candidate: nil, records: [], original: true)
            await progress?(ProgressUpdate(.ready, 1, "Kept original: image is smaller than SSIMULACRA2's 8×8 minimum"))
            return result
        }
        await progress?(ProgressUpdate(.optimizing, 0, "Normalizing image for comparison"))
        let (best, records) = try await PerceptualCompressionOptimizer(tools: tools).optimize(info: referenceInfo, options: options, workspace: work, progress: progress)
        try Task.checkCancellation()
        let transformed = referenceInfo.sourceURL != info.sourceURL
        if transformed && options.format == .auto && (best == nil || best!.record.bytes >= info.fileSize) {
            throw AiruError("noSmallerResizedOutput", "No verified resized output is smaller than the original. Select an explicit format to allow a larger file.")
        }
        let unchanged = !transformed && options.format == .auto && (best == nil || best!.record.bytes >= info.fileSize)
        guard best != nil || unchanged else { throw AiruError("qualityThresholdUnmet", "No evaluated candidate met SSIMULACRA2 \(options.minimumScore)") }
        let result = try await cache.store(key: key, info: info, options: options, candidate: best, records: records, original: unchanged, referenceHasTransparency: referenceInfo.hasTransparency)
        await progress?(ProgressUpdate(.ready, 1, unchanged ? "Already optimized" : "Verified output ready"))
        return result
    }
}
