import Foundation
import CoreGraphics

/// Real learned super-resolution, using the bundled official ncnn/MoltenVK arm64 helper.
public struct RealESRGANUpscaler: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func fingerprint() throws -> String {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hashes = manifest["sha256"] as? [String: String] else {
            throw AiruError("missingUpscaler", "Bundled Real-ESRGAN is missing. Run Scripts/bundle-upscaler.py during development.")
        }
        let names = ["bin/realesrgan-ncnn-vulkan", "models/realesrgan-x4plus.bin", "models/realesrgan-x4plus.param"]
        for name in names {
            guard let expected = hashes[name], try Files.digest(directory.appendingPathComponent(name)) == expected else {
                throw AiruError("invalidUpscaler", "Real-ESRGAN helper or model checksum mismatch: \(name)")
            }
        }
        return Files.hash(data)
    }
    func upscale(_ original: CGImage, factor: Int, workspace: URL, timeout: Double) async throws -> CGImage {
        guard [2, 4].contains(factor) else { throw AiruError("invalidOptions", "Real-ESRGAN supports 2× or 4× output") }
        // x4plus always infers at 4×; cap the real allocation, including intermediate output.
        _ = try ResizeOptions.scale(400).dimensions(width: original.width, height: original.height)
        let space = ImageAnalyzer.rgbColorSpace(original) ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let rgba = try Raster.rgba(original, colorSpace: space)
        guard let raw = rgba.dataProvider?.data as Data? else { throw AiruError("decodeFailed", "Cannot read upscale input pixels") }
        var bytes = [UInt8](raw)
        // Upscale RGB independently, avoiding model-generated alpha and dark premultiplied fringes.
        for y in 0..<rgba.height {
            if y % 64 == 0 { try Task.checkCancellation() }
            for x in 0..<rgba.width {
            let i = y * rgba.bytesPerRow + x * 4, alpha = Int(bytes[i + 3])
            for c in 0..<3 { bytes[i + c] = alpha == 0 ? 0 : UInt8(min(255, (Int(bytes[i + c]) * 255 + alpha / 2) / alpha)) }
            bytes[i + 3] = 255
        } }
        let input = workspace.appendingPathComponent("esrgan-input.png")
        let output = workspace.appendingPathComponent("esrgan-output.png")
        try Raster.writePNG(try Self.image(bytes, width: rgba.width, height: rgba.height, rowBytes: rgba.bytesPerRow, space: space), to: input)
        _ = try await ProcessRunner().run(executable: directory.appendingPathComponent("bin/realesrgan-ncnn-vulkan"),
            arguments: ["-i", input.path, "-o", output.path, "-m", directory.appendingPathComponent("models").path,
                        "-n", "realesrgan-x4plus", "-s", "4", "-t", "128", "-j", "1:1:1", "-f", "png"], timeout: timeout)
        try Task.checkCancellation()
        let decoded = try Raster.decode(output)
        guard decoded.width == original.width * 4, decoded.height == original.height * 4 else {
            throw AiruError("dimensionMismatch", "Real-ESRGAN did not produce the expected 4× raster")
        }
        let decodedRGB = try Raster.rgba(decoded)
        guard let decodedBytes = decodedRGB.dataProvider?.data as Data? else { throw AiruError("decodeFailed", "Cannot read neural output") }
        let taggedRGB = try Self.image([UInt8](decodedBytes), width: decodedRGB.width, height: decodedRGB.height,
                                       rowBytes: decodedRGB.bytesPerRow, space: space)
        let neural = try Raster.rgba(factor == 4 ? taggedRGB : ImageResizer.resize(taggedRGB, options: .scale(50)), colorSpace: space)
        let alpha = try Raster.rgba(ImageResizer.resize(original, options: .scale(Double(factor) * 100)), colorSpace: space)
        guard let rgb = neural.dataProvider?.data as Data?, let alphaData = alpha.dataProvider?.data as Data? else {
            throw AiruError("decodeFailed", "Cannot read upscaled pixels")
        }
        bytes = [UInt8](rgb)
        for y in 0..<neural.height {
            if y % 64 == 0 { try Task.checkCancellation() }
            for x in 0..<neural.width {
                let i = y * neural.bytesPerRow + x * 4, a = alphaData[y * alpha.bytesPerRow + x * 4 + 3]
                for c in 0..<3 { bytes[i + c] = UInt8((Int(bytes[i + c]) * Int(a) + 127) / 255) }
                bytes[i + 3] = a
            }
        }
        let restored = try Self.image(bytes, width: neural.width, height: neural.height, rowBytes: neural.bytesPerRow, space: space)
        return restored
    }
    private static func image(_ bytes: [UInt8], width: Int, height: Int, rowBytes: Int, space: CGColorSpace) throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes,
                space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw AiruError("upscaleFailed", "Cannot create upscaled raster")
        }
        return image
    }
}
