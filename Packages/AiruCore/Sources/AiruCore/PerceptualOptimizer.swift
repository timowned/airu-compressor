import Foundation
import CoreGraphics

struct OptimizedCandidate {
    let url: URL
    let record: CandidateRecord
}
public struct PerceptualCompressionOptimizer: Sendable {
    public let tools: Toolchain
    public init(tools: Toolchain) { self.tools = tools }
    func optimize(info: ImageInfo, options: OptimizationOptions, workspace: URL,
                  progress: ProgressHandler?) async throws -> (OptimizedCandidate?, [CandidateRecord]) {
        let deadline = Date().addingTimeInterval(options.timeoutSeconds)
        _ = try tools.executable(.ssimulacra2)
        if info.hasTransparency && options.format == .jpeg { throw AiruError("transparencyUnsupported", "JPEG cannot preserve transparency") }
        let original = try await ImageDecoder.decode(info.sourceURL, format: info.format, tools: tools, workspace: workspace, deadline: deadline)
        guard original.width == info.width, original.height == info.height else { throw AiruError("dimensionMismatch", "Orientation normalization changed dimensions") }
        let input = workspace.appendingPathComponent("normalized.png")
        try Raster.writePNG(original, to: input)
        let profileURL = workspace.appendingPathComponent("profile.icc")
        let profile = ImageAnalyzer.rgbColorSpace(original)?.copyICCData() as Data?
        if let profile { try profile.write(to: profileURL) }
        let evaluator = PerceptualEvaluator(tools: tools)
        let references = try evaluator.referenceImages(original, alpha: info.hasTransparency, directory: workspace)
        await progress?(ProgressUpdate(.optimizing, 0, "Comparison images normalized"))
        let formats: [ImageFormat]
        if let forced = options.format.imageFormat { formats = [forced] }
        else if info.hasTransparency { formats = [.png, .avif, .webp] }
        else if info.format == .png { formats = [.png, .avif, .webp, .jpeg] }
        else { formats = [.avif, .webp, .jpeg] }
        let palettePNG = options.pngMode == .superlight
        let searchable = formats.filter { $0 != .png || palettePNG }.count
        let slots = max(1, (options.maxCandidates - (formats.contains(.png) && !palettePNG ? 1 : 0)) / max(1, searchable))
        func budget(for format: ImageFormat) -> Int {
            format == .png ? (palettePNG ? max(2, slots) : 1) : slots
        }
        var plannedCandidates = min(options.maxCandidates, formats.reduce(0) { $0 + budget(for: $1) })
        var attempted = 0
        var records: [CandidateRecord] = []
        var best: OptimizedCandidate?
        let adapter = NativeEncoderAdapter(tools: tools)
        for format in formats {
            // Each codec has its own search state and initial probe. Scores are never compared on encoder quality scales.
            var low = 0, high = 100
            var quality = 100
            var tried = Set<Int>()
            let budget = budget(for: format)
            let startingCount = attempted
            for index in 0..<budget {
                try Task.checkCancellation()
                if attempted >= options.maxCandidates || Date() >= deadline { break }
                // WebP 100 remains lossy. Include a real lossless fallback in its first slot.
                let lossless = (format == .png && (!palettePNG || index == 0)) || (index == 0 && (format == .webp || format == .avif || (format == .jpeg && info.format == .jpeg)))
                let output = workspace.appendingPathComponent("candidate-\(attempted).\(format.fileExtension)")
                let request = EncoderRequest(format: format, quality: quality, lossless: lossless,
                    inputPNG: format == .png && info.format == .png && info.orientation == 1 ? info.sourceURL : input, originalJPEG: info.format == .jpeg ? info.sourceURL : nil,
                    iccProfile: profile == nil ? nil : profileURL, output: output, threads: options.encoderThreads)
                try await adapter.encode(request, timeout: deadline.timeIntervalSinceNow)
                await progress?(ProgressUpdate(.optimizing,
                    0.9 * (Double(attempted) + 0.35) / Double(max(1, plannedCandidates)),
                    "Encoded \(format.rawValue) candidate"))
                let decoded = try await ImageDecoder.decode(output, format: format, tools: tools, workspace: workspace, deadline: deadline)
                await progress?(ProgressUpdate(.optimizing,
                    0.9 * (Double(attempted) + 0.5) / Double(max(1, plannedCandidates)),
                    "Decoded \(format.rawValue) candidate for quality evaluation"))
                let alphaPreserved = try !info.hasTransparency || (ImageAnalyzer.hasAlpha(decoded) && Raster.alphaMatches(original, decoded))
                var accepted = false
                if !alphaPreserved && format == .png && !lossless {
                    // Palette entries may merge alpha levels. Reject the probe, retain the
                    // lossless fallback, and search toward higher palette quality.
                    Files.remove(output)
                    await progress?(ProgressUpdate(.optimizing, 0.9 * Double(attempted + 1) / Double(max(1, plannedCandidates)),
                        "Rejected PNG palette quality \(quality): transparency changed"))
                } else {
                    guard alphaPreserved else { throw AiruError("alphaMismatch", "Encoder changed transparency") }
                    if format == .png && lossless {
                        let space = ImageAnalyzer.rgbColorSpace(original)
                        let a = try Raster.rgba(original, colorSpace: space)
                        let b = try Raster.rgba(decoded, colorSpace: space)
                        guard a.width == b.width, a.height == b.height,
                              let ad = a.dataProvider?.data as Data?, let bd = b.dataProvider?.data as Data?, ad == bd else {
                            throw AiruError("losslessMismatch", "Lossless PNG optimization changed pixel data")
                        }
                    }
                    let score = try await evaluator.evaluate(original: original, candidate: decoded, references: references,
                        alpha: info.hasTransparency, directory: workspace, deadline: deadline)
                    let record = CandidateRecord(format: format, quality: format == .png && lossless ? nil : quality,
                        lossless: lossless, bytes: try Files.size(output), score: score)
                    records.append(record)
                    accepted = score >= options.minimumScore
                    if accepted && (best == nil || record.bytes < best!.record.bytes) {
                        if let old = best { Files.remove(old.url) }
                        best = OptimizedCandidate(url: output, record: record)
                    } else { Files.remove(output) }
                    await progress?(ProgressUpdate(.optimizing, 0.9 * Double(attempted + 1) / Double(max(1, plannedCandidates)),
                        "Evaluated \(format.rawValue)\(lossless ? " lossless" : " quality \(quality)"): \(score)", candidate: record))
                }
                attempted += 1
                if format == .png && !palettePNG { break }
                if !lossless { tried.insert(quality); if accepted { high = quality - 1 } else { low = quality + 1 } }
                if index == 0 {
                    quality = switch format { case .avif: 65; case .webp: 85; default: 88 }
                } else {
                    if low > high { break }
                    quality = (low + high) / 2
                    if tried.contains(quality) { break }
                }
            }
            // Remove probes skipped after quality convergence from the remaining work budget.
            plannedCandidates = max(attempted, plannedCandidates - max(0, budget - (attempted - startingCount)))
            await progress?(ProgressUpdate(.optimizing,
                0.9 * Double(attempted) / Double(max(1, plannedCandidates)),
                "Finished \(format.rawValue) quality search"))
        }
        return (best, records)
    }
}
public typealias PerceptualOptimizer = PerceptualCompressionOptimizer
