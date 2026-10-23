import Foundation
import Testing
import CoreGraphics
@testable import AiruCore

struct ResizeTests {
    @Test func proportionalAndCustomDimensions() throws {
        let half = try ResizeOptions.scale(50).dimensions(width: 3000, height: 2000)
        #expect(half.width == 1500 && half.height == 1000)
        let batch = try ResizeOptions.scale(50).dimensions(width: 1000, height: 3000)
        #expect(batch.width == 500 && batch.height == 1500)
        #expect(try ResizeOptions.resolution(width: 2000, height: 2000).percentage(width: 3000, height: 2000) == nil)
        #expect(try ResizeOptions.resolution(width: 1500, height: 1000).percentage(width: 3000, height: 2000) == 50)
        let restored = try ResizeOptions.scale(100).dimensions(width: 3000, height: 2000)
        #expect(restored.width == 3000 && restored.height == 2000)
        for invalid in [ResizeOptions.scale(0), .scale(-1), .scale(.nan), .resolution(width: 0, height: 10), .resolution(width: -1, height: 10), .resolution(width: 65500, height: 65500)] {
            #expect(throws: AiruError.self) { try invalid.validate() }
        }
    }
    @Test func centerCropAndPortraitLandscapeConversion() throws {
        let width = 120, height = 80
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            bytes[(y * width + x) * 4] = UInt8(x)
            bytes[(y * width + x) * 4 + 1] = UInt8(y)
        } }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        #expect(try ImageResizer.resize(image, options: .scale(100)) === image)
        for (w, h) in [(80,80), (40,80), (120,40)] {
            let crop = try ImageResizer.resize(image, options: .resolution(width: w, height: h))
            #expect(crop.width == w && crop.height == h)
            let rgba = try Raster.rgba(crop)
            let data = try #require(rgba.dataProvider?.data as Data?)
            #expect(data[0] == UInt8((width - w) / 2))
            #expect(data[1] == UInt8((height - h) / 2))
        }
        for alignment in CropAlignment.allCases {
            for (w, h) in [(40,80), (120,40)] {
                let crop = try ImageResizer.resize(image, options: .resolution(width: w, height: h, alignment: alignment))
                let rgba = try Raster.rgba(crop)
                let data = try #require(rgba.dataProvider?.data as Data?)
                #expect(data[0] == UInt8(Double(width - w) * alignment.horizontal))
                #expect(data[1] == UInt8(Double(height - h) * (1 - alignment.vertical)))
            }
        }
        let up = try ImageResizer.resize(image, options: .scale(200))
        #expect(up.width == 240 && up.height == 160)
    }
    @Test(arguments: [OutputFormat.jpeg, .webp, .avif, .png])
    func resizedFormatsAreVerified(_ format: OutputFormat) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var project = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { project.deleteLastPathComponent() }
        let engine = CompressionEngine(tools: Toolchain(directory: project.appendingPathComponent("Resources/Encoders")),
                                       cache: CompressionCache(root: root))
        let source = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/photo.jpg")
        var options = OptimizationOptions(format: format, maxCandidates: 4, pngMode: .superlight)
        options.resize = .resolution(width: 96, height: 96)
        let result = try await engine.prepare(source, options: options)
        let output = try ImageAnalyzer().analyze(result.cachedFileURL)
        #expect(output.width == 96 && output.height == 96)
        #expect(result.selectedFormat == format.imageFormat && result.perceptualScore! >= 90)
        #expect(try await engine.cache.require(result.cacheKey).cacheKey == result.cacheKey)
    }
    @Test func alignmentChangesCacheAndPreservesExactDimensions() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var project = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { project.deleteLastPathComponent() }
        let engine = CompressionEngine(tools: Toolchain(directory: project.appendingPathComponent("Resources/Encoders")),
                                       cache: CompressionCache(root: root))
        let source = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/photo.jpg")
        var options = OptimizationOptions(format: .png, maxCandidates: 4)
        options.resize = .resolution(width: 80, height: 120, alignment: .left)
        let left = try await engine.prepare(source, options: options)
        options.resize = options.resize?.aligned(.right)
        let right = try await engine.prepare(source, options: options)
        #expect(left.cacheKey != right.cacheKey && left.outputSHA256 != right.outputSHA256)
        let output = try ImageAnalyzer().analyze(right.cachedFileURL)
        #expect(output.width == 80 && output.height == 120)
        #expect(try await engine.cache.require(right.cacheKey).outputSHA256 == right.outputSHA256)
        #expect(!ResizeOptions.scale(50).isCustomResolution)
        #expect(ResizeOptions.scale(50).aligned(.top) == .scale(50))
    }
    @Test func realResizeQualityCacheOrientationAndTransparency() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var project = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { project.deleteLastPathComponent() }
        let cache = CompressionCache(root: root)
        let engine = CompressionEngine(tools: Toolchain(directory: project.appendingPathComponent("Resources/Encoders")), cache: cache)
        for fixture in ["photo.png", "oriented.jpg", "transparent.png", "profile-p3.png"] {
            let source = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(fixture)")
            let info = try ImageAnalyzer().analyze(source)
            var options = OptimizationOptions(format: .png, maxCandidates: 4)
            options.resize = .resolution(width: 96, height: 128)
            let result = try await engine.prepare(source, options: options)
            let output = try ImageAnalyzer().analyze(result.cachedFileURL)
            #expect(output.width == 96 && output.height == 128)
            #expect(result.source == info)
            #expect(result.perceptualScore! >= 90)
            #expect(output.fileSize == result.outputSize)
            #expect(!info.hasTransparency || output.hasTransparency)
            #expect(output.colorProfileSHA256 == info.colorProfileSHA256)
            #expect(try await cache.require(result.cacheKey).outputSHA256 == result.outputSHA256)
            let reused = try await engine.prepare(source, options: options)
            #expect(reused.cacheKey == result.cacheKey)
            options.resize = .scale(50)
            let scaled = try await engine.prepare(source, options: options)
            #expect(scaled.cacheKey != result.cacheKey)
            let scaledInfo = try ImageAnalyzer().analyze(scaled.cachedFileURL)
            let expected = try options.resize!.dimensions(width: info.width, height: info.height)
            #expect(scaledInfo.width == expected.width && scaledInfo.height == expected.height)
            options.resize = .scale(100)
            let restored = try await engine.prepare(source, options: options)
            let restoredInfo = try ImageAnalyzer().analyze(restored.cachedFileURL)
            #expect(restoredInfo.width == info.width && restoredInfo.height == info.height)
        }
    }
}
