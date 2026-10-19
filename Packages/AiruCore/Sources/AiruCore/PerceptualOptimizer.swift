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
        if info.hasAlpha && options.format == .jpeg { throw AiruError("transparencyUnsupported", "JPEG cannot preserve transparency") }
        let original = try await ImageDecoder.decode(info.sourceURL, format: info.format, tools: tools, workspace: workspace, deadline: deadline)
        guard original.width == info.width, original.height == info.height else { throw AiruError("dimensionMismatch", "Orientation normalization changed dimensions") }
        let input = workspace.appendingPathComponent("normalized.png")
        try Raster.writePNG(original, to: input)
        let profileURL = workspace.appendingPathComponent("profile.icc")
        let profile = original.colorSpace?.copyICCData() as Data?
        if let profile { try profile.write(to: profileURL) }
        let evaluator = PerceptualEvaluator(tools: tools)
        let references = try evaluator.referenceImages(original, alpha: info.hasAlpha, directory: workspace)
        let formats: [ImageFormat]
        if let forced = options.format.imageFormat { formats = [forced] }
        else if info.hasAlpha { formats = [.png, .avif, .webp] }
        else if info.format == .png { formats = [.png, .avif, .webp, .jpeg] }
        else { formats = [.avif, .webp, .jpeg] }
        let searchable = formats.filter { $0 != .png }.count
        let slots = max(1, (options.maxCandidates - (formats.contains(.png) ? 1 : 0)) / max(1, searchable))
        var records: [CandidateRecord] = []
        var best: OptimizedCandidate?
        let adapter = NativeEncoderAdapter(tools: tools)
        for format in formats {
            // Each codec has its own search state and initial probe. Scores are never compared on encoder quality scales.
            var low = 0, high = 100
            var quality = 100
            var tried = Set<Int>()
            let budget = format == .png ? 1 : slots
            for index in 0..<budget {
                try Task.checkCancellation()
                if records.count >= options.maxCandidates || Date() >= deadline { break }
                // WebP 100 remains lossy. Include a real lossless fallback in its first slot.
                let lossless = format == .png || (index == 0 && (format == .webp || format == .avif || (format == .jpeg && info.format == .jpeg)))
                let output = workspace.appendingPathComponent("candidate-\(records.count).\(format.fileExtension)")
                let request = EncoderRequest(format: format, quality: quality, lossless: lossless,
                    inputPNG: input, originalJPEG: info.format == .jpeg ? info.sourceURL : nil,
                    iccProfile: profile == nil ? nil : profileURL, output: output, threads: options.encoderThreads)
                try await adapter.encode(request, timeout: deadline.timeIntervalSinceNow)
                let decoded = try await ImageDecoder.decode(output, format: format, tools: tools, workspace: workspace, deadline: deadline)
                // Encoders explicitly copy the ICC payload. ColorSync may canonicalize equivalent
                // standard profiles differently on decode; compare color-managed pixels, not ICC byte identity.
                if info.hasAlpha && !ImageAnalyzer.hasAlpha(decoded) { throw AiruError("alphaMismatch", "Output discarded its alpha channel") }
                let score = try await evaluator.evaluate(original: original, candidate: decoded, references: references,
                    alpha: info.hasAlpha, directory: workspace, deadline: deadline)
                let record = CandidateRecord(format: format, quality: format == .png ? nil : quality,
                    lossless: lossless, bytes: try Files.size(output), score: score)
                records.append(record)
                let accepted = score >= options.minimumScore
                if accepted && (best == nil || record.bytes < best!.record.bytes) {
                    if let old = best { Files.remove(old.url) }
                    best = OptimizedCandidate(url: output, record: record)
                } else { Files.remove(output) }
                await progress?(ProgressUpdate(.optimizing, 0.1 + 0.8 * Double(records.count) / Double(options.maxCandidates),
                    "Evaluated \(format.rawValue)\(lossless ? " lossless" : " quality \(quality)"): \(score)", candidate: record))
                if format == .png { break }
                if !lossless { tried.insert(quality); if accepted { high = quality - 1 } else { low = quality + 1 } }
                if index == 0 {
                    quality = switch format { case .avif: 65; case .webp: 85; default: 88 }
                } else {
                    if low > high { break }
                    quality = (low + high) / 2
                    if tried.contains(quality) { break }
                }
            }
        }
        return (best, records)
    }
}
public typealias PerceptualOptimizer = PerceptualCompressionOptimizer
