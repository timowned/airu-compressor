import Foundation
import Testing
import CoreGraphics
import ImageIO
import Darwin
@testable import AiruCore

private struct Context: Sendable {
    let root: URL
    let tools: Toolchain
    let cache: CompressionCache
    var engine: CompressionEngine { CompressionEngine(tools: tools, cache: cache) }
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("airu-test-\(UUID())")
        try Files.directory(root)
        var project = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { project.deleteLastPathComponent() }
        tools = Toolchain(directory: ProcessInfo.processInfo.environment["AIRU_ENCODER_DIR"].map { URL(fileURLWithPath: $0) } ?? project.appendingPathComponent("Resources/Encoders"))
        cache = CompressionCache(root: root.appendingPathComponent("cache"))
    }
    func fixture(_ name: String) -> URL { Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(name)") }
    func options(_ format: OutputFormat = .avif, candidates: Int = 6, score: Double = 90) -> OptimizationOptions {
        .init(format: format, minimumScore: score, maxCandidates: candidates, timeoutSeconds: 90, encoderThreads: 1)
    }
    func widePhoto(width: Int, height: Int) throws -> URL {
        let original = try Raster.decode(fixture("photo.png"))
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        for x in stride(from: 0, to: width, by: 128) {
            context.draw(original, in: CGRect(x: x, y: 0, width: 128, height: 85))
        }
        let url = root.appendingPathComponent("wide-\(width).png")
        try Raster.writePNG(#require(context.makeImage()), to: url)
        return url
    }
    func verify(_ result: CompressionResult) throws {
        #expect(try Files.size(result.cachedFileURL) == result.outputSize)
        let info = try ImageAnalyzer().analyze(result.cachedFileURL)
        #expect(info.width == result.source.width)
        #expect(info.height == result.source.height)
        #expect(result.perceptualScore! >= result.options.minimumScore)
        #expect(result.outputSize == result.candidates.filter { $0.score >= result.options.minimumScore }.map(\.bytes).min())
    }
}

private actor CapturedProgress {
    private var updates: [ProgressUpdate] = []
    func append(_ update: ProgressUpdate) { updates.append(update) }
    func snapshot() -> [ProgressUpdate] { updates }
}

@Suite(.serialized) struct EngineTests {
    @Test(arguments: [16_400, 65_501])
    func autoSkipsIncompatibleCodecDimensions(_ width: Int) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let source = try c.widePhoto(width: width, height: 16)
        let result = try await c.engine.prepare(source, options: c.options(.auto, candidates: 4))
        #expect(result.outputSize <= result.source.fileSize)
        #expect(!result.candidates.contains { $0.format == .webp })
        if width > 65_500 {
            #expect(result.candidates.allSatisfy { $0.format == .png })
        }
        if !result.alreadyOptimized { try c.verify(result) }
        let exported = try await ExportManager(cache: c.cache).export(cacheKey: result.cacheKey, to: c.root.appendingPathComponent("output"))
        let decoded = try ImageAnalyzer().analyze(exported)
        #expect(decoded.width == width && decoded.height == 16)
        for format in [OutputFormat.webp, .avif, .jpeg] where width > (format.imageFormat!.encodingDimensionLimit ?? Int.max) {
            do {
                _ = try await c.engine.prepare(source, options: c.options(format))
                Issue.record("Forced unsupported dimensions must fail before encoding")
            } catch let error as AiruError { #expect(error.code == "codecDimensionLimit") }
        }
    }

    @Test(arguments: ["Encoded avif candidate", "Decoded avif candidate for quality evaluation"])
    func deadlineKeepsOnlyEarlierVerifiedCandidate(_ phase: String) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        var options = c.options(.auto, candidates: 4)
        options.timeoutSeconds = 3
        let capture = CapturedProgress()
        let result = try await c.engine.prepare(c.fixture("photo.png"), options: options) { update in
            await capture.append(update)
            if update.message == phase { try? await Task.sleep(for: .seconds(3)) }
        }
        try c.verify(result)
        #expect(result.selectedFormat == .png)
        #expect(result.candidates.count == 1 && result.perceptualScore == 100)
        #expect(await capture.snapshot().contains { $0.message.contains("budget exhausted") })
        let exported = try await ExportManager(cache: c.cache).export(cacheKey: result.cacheKey, to: c.root.appendingPathComponent("output"))
        #expect(try Files.digest(exported) == result.outputSHA256)
    }

    @Test func deadlineWithoutVerifiedCandidateFails() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        var options = c.options(.avif, candidates: 4)
        options.timeoutSeconds = 3
        do {
            _ = try await c.engine.prepare(c.fixture("photo.png"), options: options) { update in
                if update.message == "Encoded avif candidate" { try? await Task.sleep(for: .seconds(3)) }
            }
            Issue.record("An interrupted, unverified candidate cannot be accepted")
        } catch let error as AiruError { #expect(error.code == "timeout") }
    }

    @Test func evaluatorFailureStillFailsAfterVerifiedCandidate() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let directory = c.root.appendingPathComponent("toolchain")
        let bin = directory.appendingPathComponent("bin")
        try Files.directory(bin)
        for tool in EncoderTool.allCases {
            try Files.fm.createSymbolicLink(at: bin.appendingPathComponent(tool.rawValue), withDestinationURL: c.tools.executable(tool))
        }
        let evaluator = bin.appendingPathComponent("ssimulacra2")
        let engine = CompressionEngine(tools: Toolchain(directory: directory), cache: c.cache)
        do {
            _ = try await engine.prepare(c.fixture("photo.png"), options: c.options(.auto, candidates: 4)) { update in
                if update.candidate?.format == .png {
                    do {
                        try Files.fm.removeItem(at: evaluator)
                        try Files.fm.createSymbolicLink(at: evaluator, withDestinationURL: URL(fileURLWithPath: "/usr/bin/false"))
                    } catch { Issue.record("Could not inject evaluator failure: \(error)") }
                }
            }
            Issue.record("Evaluator failure must not be hidden by a previous successful candidate")
        } catch let error as AiruError { #expect(error.code == "qualityEvaluationFailed") }
    }

    @Test(arguments: [String(repeating: "a", count: 250), String(repeating: "👩🏽‍💻", count: 35)])
    func longFilenamesExportUniquelyWithoutSplittingUnicode(_ stem: String) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let source = c.root.appendingPathComponent(stem + ".png")
        try Files.fm.copyItem(at: c.fixture("photo.png"), to: source)
        let result = try await c.engine.prepare(source, options: c.options(.png))
        let exporter = ExportManager(cache: c.cache)
        let folder = c.root.appendingPathComponent("output")
        let first = try await exporter.export(cacheKey: result.cacheKey, to: folder)
        let second = try await exporter.export(cacheKey: result.cacheKey, to: folder)
        for (url, suffix) in [(first, "-comp.png"), (second, "-comp-2.png")] {
            #expect(url.lastPathComponent.hasSuffix(suffix))
            let retainedStem = String(url.lastPathComponent.dropLast(suffix.count))
            #expect(!retainedStem.isEmpty && stem.hasPrefix(retainedStem))
            #expect(Array(retainedStem).allSatisfy { $0 == stem.first! })
            #expect(try Files.size(url) == result.outputSize)
            #expect(try Files.digest(url) == result.outputSHA256)
        }
        #expect(first != second)
        #expect(try Files.digest(source) == result.source.contentSHA256)
    }

    @Test(arguments: ["photo.png", "transparent.png", "profile-p3.png", "palette-graphic.png", "palette-alpha.png"])
    func pngAiryPreservesPixels(_ name: String) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let source = c.fixture(name)
        let result = try await c.engine.prepare(source, options: c.options(.png))
        try c.verify(result)
        #expect(result.options.pngMode == .airy)
        #expect(result.candidates.count == 1); #expect(result.candidates[0].lossless)
        let original = try Raster.decode(source), output = try Raster.decode(result.cachedFileURL)
        let space = original.colorSpace?.model == .rgb ? original.colorSpace : nil
        let a = try Raster.rgba(original, colorSpace: space), b = try Raster.rgba(output, colorSpace: space)
        #expect(a.dataProvider?.data as Data? == b.dataProvider?.data as Data?)
        #expect(try ImageAnalyzer().analyze(result.cachedFileURL).colorProfileSHA256 == result.source.colorProfileSHA256)
    }
    @Test(arguments: ["photo.png", "transparent.png", "profile-p3.png", "palette-graphic.png", "palette-alpha.png"])
    func pngSuperlightSearchesVerifiedPalette(_ name: String) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        var options = c.options(.png, candidates: 10, score: 80)
        options.pngMode = .superlight
        let source = c.fixture(name)
        let result = try await c.engine.prepare(source, options: options)
        try c.verify(result)
        #expect(result.candidates.count <= options.maxCandidates)
        #expect(result.candidates.contains { $0.lossless })
        if name != "transparent.png" {
            #expect(result.candidates.contains { !$0.lossless && $0.quality != nil })
            #expect(result.outputSize < result.source.fileSize)
            #expect(result.outputSize <= result.candidates.first!.bytes)
        }
        if name.hasPrefix("palette-") {
            #expect(result.outputSize < result.candidates.first!.bytes)
            #expect(result.candidates.contains { !$0.lossless && $0.bytes == result.outputSize && $0.score >= 80 })
        }
        #expect(try Raster.alphaMatches(Raster.decode(source), Raster.decode(result.cachedFileURL)))
        #expect(try ImageAnalyzer().analyze(result.cachedFileURL).colorProfileSHA256 == result.source.colorProfileSHA256)
        let cached = try await c.engine.prepare(source, options: options)
        #expect(cached.cacheKey == result.cacheKey)
        var airy = options; airy.pngMode = .airy
        let other = try await c.engine.prepare(source, options: airy)
        #expect(other.cacheKey != result.cacheKey)
        if name == "palette-graphic.png" {
            // Palette PNGs expose their ICC profile through an indexed base color space.
            let reimported = try await c.engine.prepare(result.cachedFileURL, options: airy)
            #expect(reimported.source.colorProfileSHA256 == result.source.colorProfileSHA256)
            #expect(reimported.perceptualScore == 100)
        }
        let exported = try await ExportManager(cache: c.cache).export(cacheKey: result.cacheKey, to: c.root.appendingPathComponent("export"))
        #expect(try Files.size(exported) == result.outputSize)
    }
    @Test func pngSuperlightAutoNeverGrowsAndRejectsLowTarget() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        var options = c.options(.auto, candidates: 12, score: 80); options.pngMode = .superlight
        let result = try await c.engine.prepare(c.fixture("photo.png"), options: options)
        #expect(result.outputSize <= result.source.fileSize)
        #expect(result.candidates.contains { $0.format == .png && !$0.lossless })
        let tiny = try await c.engine.prepare(c.fixture("tiny.png"), options: options)
        #expect(tiny.outputSize <= tiny.source.fileSize)
        options.minimumScore = 79
        #expect(throws: AiruError.self) { try options.validate() }
    }
    @Test func pngColorMetadataRejectsTruncatedData() throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let input = c.root.appendingPathComponent("broken.png")
        try Data([137, 80, 78, 71, 13, 10, 26, 10, 255, 255, 255, 255, 73, 72, 68, 82]).write(to: input)
        #expect(throws: AiruError.self) { try PNGColorMetadata.removingColor(from: input, to: c.root.appendingPathComponent("out.png")) }
    }

    @Test(arguments: [OutputFormat.avif, .webp, .jpeg, .png, .auto])
    func opaqueAlphaChannelCanBeCompressed(_ format: OutputFormat) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let source = c.root.appendingPathComponent("opaque alpha screenshot.png")
        let image = try Raster.rgba(Raster.decode(c.fixture("photo.png")), background: 1)
        try Raster.writePNG(image, to: source)
        let info = try ImageAnalyzer().analyze(source)
        #expect(info.hasAlpha)
        #expect(!info.hasTransparency)
        let result = try await c.engine.prepare(source, options: c.options(format, candidates: 12))
        if !result.alreadyOptimized { try c.verify(result) }
        let exported = try await ExportManager(cache: c.cache).export(cacheKey: result.cacheKey, to: c.root.appendingPathComponent("exports"))
        #expect(try Files.size(exported) == result.outputSize)
        #expect(!(try ImageAnalyzer().analyze(exported)).hasTransparency)
        let reused = try await c.engine.prepare(source, options: c.options(format, candidates: 12))
        #expect(reused.outputSHA256 == result.outputSHA256)
    }

    @Test func progressTracksCompletedWorkAndEndsAtOne() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let log = CapturedProgress()
        let result = try await c.engine.prepare(c.fixture("photo.png"), options: c.options(.png)) {
            await log.append($0)
        }
        try c.verify(result)
        let updates = await log.snapshot()
        #expect(updates.first?.fraction == 0)
        #expect(updates.first { $0.message == "Comparison images normalized" }?.fraction == 0)
        #expect(updates.last?.status == .ready); #expect(updates.last?.fraction == 1)
        #expect(updates.allSatisfy { $0.fraction.isFinite && (0...1).contains($0.fraction) })
        #expect(zip(updates, updates.dropFirst()).allSatisfy { $0.fraction <= $1.fraction + 0.000001 })
        #expect(updates.contains { $0.message.hasPrefix("Encoded ") })
        #expect(updates.contains { $0.message.hasPrefix("Decoded ") })
        #expect(updates.contains { $0.fraction >= 0.89 && $0.status == .optimizing })
    }

    @Test func analyzeContentsAndCorruption() throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let disguised = c.root.appendingPathComponent("not really a jpeg.jpg")
        try Files.fm.copyItem(at: c.fixture("photo.png"), to: disguised)
        #expect(try ImageAnalyzer().analyze(disguised).format == .png)
        let corrupt = c.root.appendingPathComponent("broken.png")
        try Data("this is not an image".utf8).write(to: corrupt)
        #expect(throws: AiruError.self) { try ImageAnalyzer().analyze(corrupt) }
    }
    @Test func metadataOrientationAndProfile() throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let rotated = try ImageAnalyzer().analyze(c.fixture("oriented.jpg"))
        #expect(rotated.orientation == 6); #expect(rotated.width == 368); #expect(rotated.height == 550)
        let image = try Raster.decode(c.fixture("oriented.jpg"))
        #expect(image.width == 368); #expect(image.height == 550)
        let p3 = try ImageAnalyzer().analyze(c.fixture("profile-p3.png"))
        #expect(p3.colorProfileSHA256 != nil); #expect(p3.colorProfile?.contains("P3") == true)
    }
    @Test func jpegCompression() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("photo.jpg"), options: c.options(.jpeg))
        try c.verify(result); #expect(result.selectedFormat == .jpeg)
        #expect(result.candidates.contains { $0.lossless })
    }
    @Test func pngCompression() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("photo.png"), options: c.options(.png))
        try c.verify(result); #expect(result.selectedFormat == .png)
        #expect(result.candidates.count == 1)
    }
    @Test func avifExport() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("photo.jpg"), options: c.options(.avif))
        try c.verify(result)
        let output = try await ExportManager(cache: c.cache).export(cacheKey: result.cacheKey, to: c.root.appendingPathComponent("custom folder"))
        #expect(output.lastPathComponent == "photo-comp.avif")
        #expect(try ImageAnalyzer().analyze(output).format == .avif)
        #expect(try Files.digest(output) == result.outputSHA256)
    }
    @Test func webpExport() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("photo.png"), options: c.options(.webp))
        try c.verify(result)
        let url = try await ExportManager(cache: c.cache).export(cacheKey: result.cacheKey, to: c.root)
        #expect(url.pathExtension == "webp"); #expect(try ImageAnalyzer().analyze(url).format == .webp)
    }
    @Test(arguments: [OutputFormat.avif, .webp, .png]) func transparency(_ format: OutputFormat) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let source = c.fixture("transparent.png")
        let result = try await c.engine.prepare(source, options: c.options(format))
        try c.verify(result)
        let decoded = try await ImageDecoder.decode(result.cachedFileURL, format: result.selectedFormat, tools: c.tools,
            workspace: c.root, deadline: Date().addingTimeInterval(5))
        #expect(try Raster.alphaMatches(Raster.decode(source), decoded))
        #expect(try ImageAnalyzer().analyze(result.cachedFileURL).hasAlpha)
    }
    @Test func transparentJPEGRejected() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        do {
            _ = try await c.engine.prepare(c.fixture("transparent.png"), options: c.options(.jpeg))
            Issue.record("JPEG should reject alpha")
        } catch let error as AiruError { #expect(error.code == "transparencyUnsupported") }
    }
    @Test func autoSmallFileAndMeasuredMinimum() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        // Add a minimal PNG without an ICC header so no encoder can beat its original size.
        let tiny = c.root.appendingPathComponent("tiny.png")
        let raw = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        try Data(base64Encoded: raw)!.write(to: tiny)
        let result = try await c.engine.prepare(tiny, options: c.options(.auto, candidates: 8))
        #expect(result.alreadyOptimized); #expect(result.verification == .unchangedOriginal)
        #expect(result.perceptualScore == nil); #expect(result.outputSize == result.source.fileSize)
        #expect(result.outputSHA256 == result.source.contentSHA256)
        let output = try await ExportManager(cache: c.cache).export(cacheKey: result.cacheKey, to: c.root.appendingPathComponent("exports"))
        #expect(output.lastPathComponent == "tiny-comp.png")
    }
    @Test func autoPhotograph() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("photo.jpg"), options: c.options(.auto, candidates: 18))
        #expect(result.outputSize <= result.source.fileSize)
        #expect(result.candidates.contains { $0.format == .avif }); #expect(result.candidates.contains { $0.format == .webp })
        if !result.alreadyOptimized { try c.verify(result) }
    }
    @Test func rotatedCompression() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("oriented.jpg"), options: c.options(.avif))
        try c.verify(result); #expect(result.source.width == 368)
    }
    @Test(arguments: [OutputFormat.avif, .webp, .jpeg, .png]) func iccPreserved(_ format: OutputFormat) async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("profile-p3.png"), options: c.options(format))
        try c.verify(result)
        let info = try ImageAnalyzer().analyze(result.cachedFileURL)
        #expect(info.colorProfileSHA256 == result.source.colorProfileSHA256)
    }
    @Test func unicodeSpacesAndCollisions() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let source = c.root.appendingPathComponent("Дубай house.final.jpeg")
        try Files.fm.copyItem(at: c.fixture("photo.jpg"), to: source)
        let result = try await c.engine.prepare(source, options: c.options(.jpeg, candidates: 4))
        let destination = c.root.appendingPathComponent("output")
        try Files.directory(destination)
        try Data().write(to: destination.appendingPathComponent("ДУБАЙ HOUSE.FINAL-COMP.JPG"))
        let exporter = ExportManager(cache: c.cache)
        let a = try await exporter.export(cacheKey: result.cacheKey, to: destination)
        let b = try await exporter.export(cacheKey: result.cacheKey, to: destination)
        #expect(a.lastPathComponent == "Дубай house.final-comp-2.jpg")
        #expect(b.lastPathComponent == "Дубай house.final-comp-3.jpg")
        #expect(try Files.digest(source) == result.source.contentSHA256)
    }
    @Test func cacheReuseInvalidationAndTampering() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let file = c.root.appendingPathComponent("photo.png")
        try Files.fm.copyItem(at: c.fixture("photo.png"), to: file)
        let a = try await c.engine.prepare(file, options: c.options(.png))
        let before = try Files.fm.attributesOfItem(atPath: a.cachedFileURL.path)[.modificationDate] as? Date
        let b = try await c.engine.prepare(file, options: c.options(.png))
        #expect(a.cacheKey == b.cacheKey)
        #expect(try Files.fm.attributesOfItem(atPath: b.cachedFileURL.path)[.modificationDate] as? Date == before)
        let handle = try FileHandle(forWritingTo: file); try handle.seekToEnd(); try handle.write(contentsOf: Data([0])); try handle.close()
        #expect(try await c.cache.lookup(a.cacheKey) == nil)
        let changed = try await c.engine.prepare(file, options: c.options(.png))
        #expect(changed.cacheKey != a.cacheKey)
        try Data([1, 2, 3]).write(to: changed.cachedFileURL)
        #expect(try await c.cache.lookup(changed.cacheKey) == nil)
    }
    @Test func optionsAffectCacheAndForcedLargerFormat() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("photo.jpg"), options: c.options(.png))
        #expect(result.outputSize > result.source.fileSize); #expect(!result.alreadyOptimized)
        let a = try CompressionCache.key(source: result.source, options: c.options(.png), toolchainFingerprint: "test")
        let b = try CompressionCache.key(source: result.source, options: c.options(.avif), toolchainFingerprint: "test")
        #expect(a != b)
    }
    @Test func batchErrorsIdenticalNamesAndRemoval() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let processor = BatchProcessor(engine: c.engine, concurrencyLimit: 2)
        let other = c.root.appendingPathComponent("other/photo.png")
        try Files.directory(other.deletingLastPathComponent()); try Files.fm.copyItem(at: c.fixture("photo.png"), to: other)
        await processor.add(c.fixture("photo.png"), options: c.options(.png))
        await processor.add(other, options: c.options(.png))
        await processor.add(c.root.appendingPathComponent("missing.png"), options: c.options(.png))
        let removed = await processor.add(c.fixture("photo.jpg"), options: c.options(.avif))
        await processor.remove(removed)
        let snapshot = try await processor.waitUntilFinished()
        #expect(snapshot.jobs.count == 3); #expect(snapshot.jobs.filter { $0.status == .ready }.count == 2)
        #expect(snapshot.jobs.filter { $0.status == .failed }.count == 1); #expect(snapshot.progress == 1)
        var outputs: [URL] = []
        for job in snapshot.jobs where job.status == .ready {
            outputs.append(try await processor.export(job.id, to: c.root.appendingPathComponent("exports")))
        }
        #expect(Set(outputs).count == 2)
    }
    @Test func cancellationAndCleanup() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let task = Task { try await c.engine.prepare(c.fixture("photo.png"), options: c.options(.avif, candidates: 24)) }
        try await Task.sleep(for: .milliseconds(60)); task.cancel()
        do { _ = try await task.value; Issue.record("Expected cancellation") } catch { #expect(error is CancellationError) }
        if Files.fm.fileExists(atPath: c.cache.root.path) {
            #expect(try Files.fm.contentsOfDirectory(atPath: c.cache.root.path).isEmpty)
        }
        let processor = BatchProcessor(engine: c.engine, concurrencyLimit: 1)
        let id = await processor.add(c.fixture("photo.jpg"), options: c.options())
        await processor.cancel(id)
        #expect(try await processor.waitUntilFinished().jobs.first?.status == .cancelled)
    }
    @Test func missingToolsAndNoFakeScore() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let engine = CompressionEngine(tools: Toolchain(directory: c.root), cache: c.cache)
        do { _ = try await engine.prepare(c.fixture("photo.png")); Issue.record("Missing tools must fail") }
        catch let error as AiruError { #expect(error.code == "missingEncoder") }
        let original = try Raster.decode(c.fixture("photo.png"))
        let evaluator = PerceptualEvaluator(tools: Toolchain(directory: c.root))
        let refs = try evaluator.referenceImages(original, alpha: false, directory: c.root)
        do {
            _ = try await evaluator.evaluate(original: original, candidate: original, references: refs, alpha: false,
                                            directory: c.root, deadline: Date().addingTimeInterval(5))
            Issue.record("Missing evaluator must fail")
        } catch let error as AiruError { #expect(error.code == "missingEncoder") }
    }
    @Test func batchExportCancellation() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let batch = BatchProcessor(engine: c.engine)
        let id = await batch.add(c.fixture("photo.png"), options: c.options(.png))
        _ = try await batch.waitUntilFinished()
        let destination = c.root.appendingPathComponent("exports")
        try Files.directory(destination)
        let lock = open(destination.appendingPathComponent(".airu-export.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        #expect(lock >= 0)
        defer { flock(lock, LOCK_UN); close(lock) }
        #expect(flock(lock, LOCK_EX | LOCK_NB) == 0)
        let task = Task { try await batch.export(id, to: destination) }
        try await Task.sleep(for: .milliseconds(40))
        await batch.cancel(id)
        do { _ = try await task.value; Issue.record("Blocked export must cancel") }
        catch { #expect(error is CancellationError) }
        #expect(await batch.snapshot().jobs.first?.status == .cancelled)
        #expect(try Files.fm.contentsOfDirectory(atPath: destination.path).filter { !$0.hasPrefix(".") }.isEmpty)
    }
    @Test func strictQualityThreshold() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let result = try await c.engine.prepare(c.fixture("photo.png"), options: c.options(.avif, score: 98))
        try c.verify(result); #expect(result.perceptualScore! >= 98)
        #expect(result.candidates.contains { $0.score < 98 })
    }
    @Test func failingEvaluatorCannotAcceptCandidate() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let bin = c.root.appendingPathComponent("bin")
        try Files.directory(bin)
        try Files.fm.createSymbolicLink(at: bin.appendingPathComponent("ssimulacra2"), withDestinationURL: URL(fileURLWithPath: "/usr/bin/false"))
        let original = try Raster.decode(c.fixture("photo.png"))
        let evaluator = PerceptualEvaluator(tools: Toolchain(directory: c.root))
        let refs = try evaluator.referenceImages(original, alpha: false, directory: c.root)
        do {
            _ = try await evaluator.evaluate(original: original, candidate: original, references: refs, alpha: false,
                directory: c.root, deadline: Date().addingTimeInterval(5))
            Issue.record("A failing evaluator must never accept even a visually identical candidate")
        } catch let error as AiruError { #expect(error.code == "qualityEvaluationFailed") }
    }
    @Test func smallForcedConversionReturnsExplicitError() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        do {
            _ = try await c.engine.prepare(c.fixture("tiny.png"), options: c.options(.avif))
            Issue.record("A tiny forced conversion cannot be scored")
        } catch let error as AiruError { #expect(error.code == "comparisonImageTooSmall") }
    }
    @Test func processTimeoutAndArguments() async throws {
        let c = try Context(); defer { Files.remove(c.root) }
        let out = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: ["$(touch unwanted)", "Unicode 空間"], timeout: 1)
        #expect(out.stdout.contains("$(touch unwanted)"))
        do {
            _ = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], timeout: 0.05)
            Issue.record("Process must time out")
        } catch let error as AiruError { #expect(error.code == "timeout") }
    }
    @Test func optionAndCacheKeyValidation() throws {
        #expect(throws: AiruError.self) { try OptimizationOptions(minimumScore: .nan).validate() }
        #expect(throws: AiruError.self) { try OptimizationOptions(maxCandidates: 0).validate() }
    }
}
