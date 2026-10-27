import Foundation
import Testing
import CoreGraphics
@testable import AiruCore

@Suite(.serialized) struct UpscaleTests {
    private func project() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }
    @Test(arguments: [2, 4]) func realNeuralUpscalePreservesAlphaAndMetadata(_ factor: Int) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let tools = Toolchain(directory: project().appendingPathComponent("Resources/Encoders"))
        let engine = CompressionEngine(tools: tools, cache: CompressionCache(root: root.appendingPathComponent("cache")))
        for name in ["photo.jpg", "transparent.png", "profile-p3.png", "oriented.jpg"] {
            let original = try Raster.decode(Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(name)"))
            let small = try ImageResizer.resize(original, options: .resolution(width: 24, height: 32))
            let source = root.appendingPathComponent(name + ".png")
            try Raster.writePNG(small, to: source)
            var options = OptimizationOptions(format: .png, maxCandidates: 4, timeoutSeconds: 120)
            options.upscale = factor
            let result = try await engine.prepare(source, options: options)
            let image = try Raster.decode(result.cachedFileURL)
            #expect(image.width == 24 * factor && image.height == 32 * factor)
            let resized = try ImageResizer.resize(small, options: .scale(Double(factor) * 100))
            #expect(try Raster.alphaMatches(image, resized))
            let info = try ImageAnalyzer().analyze(result.cachedFileURL)
            #expect(info.fileSize == result.outputSize)
            #expect(info.colorProfileSHA256 == result.source.colorProfileSHA256)
            #expect(result.perceptualScore! >= 90 && result.verification == .ssimulacra2)
            let space = ImageAnalyzer.rgbColorSpace(image)
            let a = try Raster.rgba(image, colorSpace: space), b = try Raster.rgba(resized, colorSpace: space)
            #expect(a.dataProvider?.data as Data? != b.dataProvider?.data as Data?)
            let reused = try await engine.prepare(source, options: options)
            #expect(reused.cacheKey == result.cacheKey && reused.outputSHA256 == result.outputSHA256)
            let destination = try await ExportManager(cache: engine.cache).export(cacheKey: result.cacheKey, to: root.appendingPathComponent("export"))
            #expect(destination.lastPathComponent.contains("-upscaled-\(factor)x"))
            #expect(try Data(contentsOf: destination) == Data(contentsOf: result.cachedFileURL))
        }
    }
    @Test func cancellationStopsActiveNeuralPreparation() async throws {
        actor Started {
            var value = false
            func mark() { value = true }
        }
        let started = Started()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = CompressionEngine(tools: Toolchain(directory: project().appendingPathComponent("Resources/Encoders")),
                                       cache: CompressionCache(root: root))
        let source = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/photo.png")
        var options = OptimizationOptions(format: .png)
        options.upscale = 4
        let task = Task {
            try await engine.prepare(source, options: options) { update in
                if update.message.contains("reconstructing") { await started.mark() }
            }
        }
        let deadline = Date().addingTimeInterval(10)
        while !(await started.value) {
            if Date() > deadline {
                task.cancel(); _ = try? await task.value
                Issue.record("Neural preparation did not start within 10 seconds")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled upscale unexpectedly succeeded") }
        catch { #expect(AiruError.wrapping(error).code == "cancelled") }
    }
    @Test func upscaleValidationMissingModelsAndCancellation() async throws {
        var options = OptimizationOptions()
        options.upscale = 3
        #expect(throws: AiruError.self) { try options.validate() }
        options.upscale = 2; options.resize = .scale(50)
        #expect(throws: AiruError.self) { try options.validate() }
        let missing = RealESRGANUpscaler(directory: URL(fileURLWithPath: "/nonexistent-airu-upscaler"))
        #expect(throws: AiruError.self) { try missing.fingerprint() }
        options.resize = nil
        let engine = CompressionEngine(tools: Toolchain(directory: project().appendingPathComponent("Resources/Encoders")))
        let source = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/photo.png")
        let task = Task { try await engine.prepare(source, options: options) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
