import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

public struct ImageAnalyzer: Sendable {
    public let maximumPixels: Int
    public init(maximumPixels: Int = 80_000_000) { self.maximumPixels = maximumPixels }
    public func analyze(_ url: URL) throws -> ImageInfo {
        try Task.checkCancellation()
        guard url.isFileURL, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String?,
              let format = Self.format(type),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else {
            throw AiruError("unsupportedImage", "Unsupported or corrupt image: \(url.lastPathComponent)")
        }
        guard w <= maximumPixels / h else { throw AiruError("imageTooLarge", "Image exceeds \(maximumPixels) pixels") }
        let frames = CGImageSourceGetCount(source)
        guard frames == 1 else { throw AiruError("animatedImage", "Animated or multi-frame images are not supported") }
        guard CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeHDRGainMap) == nil else {
            throw AiruError("unsupportedColor", "HDR gain maps are not supported in Stage 1; refusing to discard HDR appearance")
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw AiruError("decodeFailed", "ImageIO could not fully decode \(url.lastPathComponent)")
        }
        guard image.bitsPerComponent <= 8, image.colorSpace?.model != .cmyk else {
            throw AiruError("unsupportedColor", "Stage 1 supports SDR RGB/grayscale images up to 8 bits per channel; refusing a lossy color conversion")
        }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        let swap = (5...8).contains(orientation)
        let icc = image.colorSpace?.copyICCData() as Data?
        return ImageInfo(sourceURL: url.standardizedFileURL, originalFilename: url.lastPathComponent, format: format,
                         fileSize: try Files.size(url), width: swap ? h : w, height: swap ? w : h,
                         storedWidth: w, storedHeight: h,
                         colorProfile: image.colorSpace?.name as String? ?? props[kCGImagePropertyProfileName] as? String,
                         colorProfileSHA256: icc.map(Files.hash), hasAlpha: Self.hasAlpha(image), orientation: orientation,
                         bitsPerComponent: image.bitsPerComponent, canDecode: true, frameCount: frames,
                         contentSHA256: try Files.digest(url))
    }
    static func format(_ type: String) -> ImageFormat? {
        switch type {
        case UTType.jpeg.identifier: .jpeg
        case UTType.png.identifier: .png
        case "public.avif": .avif
        case "org.webmproject.webp": .webp
        case "public.heic", "public.heif": .heic
        default: nil
        }
    }
    static func hasAlpha(_ image: CGImage) -> Bool {
        [.first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly].contains(image.alphaInfo)
    }
}

/// Each job retains its full-resolution raster only while encoding/evaluating it.
enum Raster {
    static func materialize(_ image: CGImage) throws -> CGImage {
        let space = image.colorSpace?.model == .rgb ? image.colorSpace! : CGColorSpace(name: CGColorSpace.sRGB)!
        let alpha = ImageAnalyzer.hasAlpha(image)
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: space,
            bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw AiruError("decodeFailed", "Cannot allocate decoded raster")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let result = context.makeImage() else { throw AiruError("decodeFailed", "Cannot materialize decoded image") }
        return result
    }
    static func decode(_ url: URL, oriented: Bool = true) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw AiruError("decodeFailed", url.path) }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        if !oriented || orientation == 1 {
            if let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) { return image }
        }
        if oriented {
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
            let side = max(props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0)
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: side,
                kCGImageSourceShouldCacheImmediately: true]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) { return image }
        } else if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) { return image }
        throw AiruError("decodeFailed", "Could not decode \(url.lastPathComponent)")
    }
    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw AiruError("encodeFailed", "Cannot write PNG")
        }
        CGImageDestinationAddImage(dest, image, [kCGImagePropertyOrientation: 1] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw AiruError("encodeFailed", "PNG finalization failed") }
    }
    static func rgba(_ image: CGImage, background: CGFloat? = nil, colorSpace: CGColorSpace? = nil) throws -> CGImage {
        guard let space = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB), let ctx = CGContext(data: nil, width: image.width,
            height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw AiruError("decodeFailed", "Could not allocate comparison raster")
        }
        if let background {
            ctx.setFillColor(CGColor(gray: background, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let output = ctx.makeImage() else { throw AiruError("decodeFailed", "Comparison raster unavailable") }
        return output
    }
    static func alphaMatches(_ lhs: CGImage, _ rhs: CGImage) throws -> Bool {
        let a = try rgba(lhs), b = try rgba(rhs)
        guard let ad = a.dataProvider?.data as Data?, let bd = b.dataProvider?.data as Data? else { return false }
        return stride(from: 3, to: ad.count, by: 4).allSatisfy { ad[$0] == bd[$0] }
    }
}

enum ImageDecoder {
    /// AVIF's system thumbnail decoder can yield a blank raster on some macOS builds.
    /// Decode AVIF with the bundled reference decoder, then use ImageIO for its PNG output.
    static func decode(_ url: URL, format: ImageFormat, tools: Toolchain, workspace: URL, deadline: Date) async throws -> CGImage {
        if format == .avif {
            let decoded = workspace.appendingPathComponent("decoded-\(UUID()).png")
            defer { Files.remove(decoded) }
            _ = try await ProcessRunner().run(executable: tools.executable(.avifdec),
                arguments: ["--jobs", "2", url.path, decoded.path], timeout: deadline.timeIntervalSinceNow)
            // ImageIO may retain a lazy file-backed provider even with immediate caching enabled.
            return try Raster.materialize(Raster.decode(decoded))
        }
        return try Raster.decode(url)
    }
}
