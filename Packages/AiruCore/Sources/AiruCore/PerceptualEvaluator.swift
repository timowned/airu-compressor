import Foundation
import CoreGraphics

public struct PerceptualEvaluator: Sendable {
    public let tools: Toolchain
    public init(tools: Toolchain) { self.tools = tools }
    func referenceImages(_ original: CGImage, alpha: Bool, directory: URL) throws -> [URL] {
        try (alpha ? [CGFloat(0), CGFloat(1)] : [CGFloat(1)]).enumerated().map { index, background in
            let url = directory.appendingPathComponent("reference-\(index).png")
            let space = ImageAnalyzer.rgbColorSpace(original)
            try Raster.writePNG(Raster.rgba(original, background: background, colorSpace: space), to: url)
            return url
        }
    }
    func evaluate(original: CGImage, candidate: CGImage, references: [URL], alpha: Bool,
                  directory: URL, deadline: Date) async throws -> Double {
        guard original.width == candidate.width, original.height == candidate.height else {
            throw AiruError("dimensionMismatch", "Encoder changed the image dimensions")
        }
        if try alpha && !Raster.alphaMatches(original, candidate) {
            throw AiruError("alphaMismatch", "Encoder changed transparency")
        }
        let executable = try tools.executable(.ssimulacra2)
        var scores: [Double] = []
        for (index, reference) in references.enumerated() {
            try Task.checkCancellation()
            let file = directory.appendingPathComponent("comparison-\(index).png")
            defer { Files.remove(file) }
            let space = ImageAnalyzer.rgbColorSpace(original)
            try Raster.writePNG(Raster.rgba(candidate, background: alpha && index == 0 ? 0 : 1, colorSpace: space), to: file)
            let output: ProcessOutput
            do {
                output = try await ProcessRunner().run(executable: executable, arguments: [reference.path, file.path],
                                                      timeout: deadline.timeIntervalSinceNow)
            } catch is CancellationError { throw CancellationError() }
            catch { throw AiruError("qualityEvaluationFailed", AiruError.wrapping(error).message) }
            guard let score = Double(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)), score.isFinite, score <= 100.0001 else {
                throw AiruError("qualityEvaluationFailed", "SSIMULACRA2 returned an invalid score: \(output.stdout.prefix(200))")
            }
            scores.append(score)
        }
        guard let score = scores.min() else { throw AiruError("qualityEvaluationFailed", "No comparison images") }
        return score
    }
}
