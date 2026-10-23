import Foundation
import CoreGraphics
import Accelerate

/// Visual crop anchors; vertical fractions follow vImage's bottom-left origin.
public enum CropAlignment: String, Codable, Sendable, CaseIterable {
    case topLeft = "top-left", top, topRight = "top-right"
    case left, center, right
    case bottomLeft = "bottom-left", bottom, bottomRight = "bottom-right"
    public var horizontal: Double {
        switch self { case .topLeft, .left, .bottomLeft: 0; case .topRight, .right, .bottomRight: 1; default: 0.5 }
    }
    public var vertical: Double {
        switch self { case .topLeft, .top, .topRight: 1; case .bottomLeft, .bottom, .bottomRight: 0; default: 0.5 }
    }
    public var label: String { rawValue.replacingOccurrences(of: "-", with: " ").capitalized }
}

/// Percentage is relative to the oriented original; exact dimensions use centered aspect fill.
public enum ResizeOptions: Codable, Sendable, Equatable {
    case scale(Double)
    case resolution(width: Int, height: Int, alignment: CropAlignment = .center)

    public var alignment: CropAlignment {
        if case .resolution(_, _, let alignment) = self { return alignment }
        return .center
    }
    public var isCustomResolution: Bool {
        if case .resolution = self { return true }
        return false
    }
    public func aligned(_ alignment: CropAlignment) -> Self {
        if case .resolution(let width, let height, _) = self {
            return .resolution(width: width, height: height, alignment: alignment)
        }
        return self
    }
    public func validate() throws {
        switch self {
        case .scale(let percent):
            guard percent.isFinite, percent > 0, percent <= 10000 else {
                throw AiruError("invalidDimensions", "Scale must be greater than 0 and at most 10000 percent")
            }
        case .resolution(let width, let height, _): try Self.check(width, height)
        }
    }
    private static func check(_ width: Int, _ height: Int) throws {
        guard width > 0, height > 0, width <= 65500, height <= 65500,
              Int64(width) * Int64(height) <= 100_000_000 else {
            throw AiruError("invalidDimensions", "Dimensions must be positive, at most 65500 per side and 100 megapixels")
        }
    }
    public func dimensions(width: Int, height: Int) throws -> (width: Int, height: Int) {
        try validate()
        let target: (Int, Int)
        switch self {
        case .scale(let percent):
            let w = (Double(width) * percent / 100).rounded()
            let h = (Double(height) * percent / 100).rounded()
            guard w <= 65500, h <= 65500 else { throw AiruError("invalidDimensions", "Scaled dimensions exceed 65500 pixels") }
            target = (max(1, Int(w)), max(1, Int(h)))
        case .resolution(let w, let h, _): target = (w, h)
        }
        try Self.check(target.0, target.1)
        return target
    }
    public func percentage(width: Int, height: Int) throws -> Double? {
        let target = try dimensions(width: width, height: height)
        switch self {
        case .scale(let value): return value
        case .resolution:
            let percent = Double(target.width) / Double(width) * 100
            let proportionalHeight = Int((Double(height) * percent / 100).rounded())
            return proportionalHeight == target.height ? percent : nil
        }
    }
}

public enum ImageResizer {
    public static func resize(_ image: CGImage, options: ResizeOptions) throws -> CGImage {
        let target = try options.dimensions(width: image.width, height: image.height)
        if target.width == image.width && target.height == image.height { return image }
        try Task.checkCancellation()
        let factor = max(Double(target.width) / Double(image.width), Double(target.height) / Double(image.height))
        let width = target.width, height = target.height
        let raster = try Raster.rgba(image, colorSpace: ImageAnalyzer.rgbColorSpace(image))
        guard let data = raster.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            throw AiruError("resizeFailed", "Cannot access source pixels")
        }
        var source = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: bytes), height: vImagePixelCount(raster.height),
                                   width: vImagePixelCount(raster.width), rowBytes: raster.bytesPerRow)
        var output = vImage_Buffer()
        guard vImageBuffer_Init(&output, vImagePixelCount(height), vImagePixelCount(width), 32, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            throw AiruError("resizeFailed", "Cannot allocate resized pixels")
        }
        defer { free(output.data) }
        // vImage's default geometry filter is Lanczos-3. HighQualityResampling selects Lanczos-5 instead.
        // Fuse proportional scaling and centered cropping in one transform. Independent
        // integer-rounded scale dimensions would introduce a small aspect-ratio distortion.
        var transform = vImage_AffineTransform(a: Float(factor), b: 0, c: 0, d: Float(factor),
            tx: Float((Double(width) - Double(image.width) * factor) * options.alignment.horizontal),
            ty: Float((Double(height) - Double(image.height) * factor) * options.alignment.vertical))
        let status = vImageAffineWarp_ARGB8888(&source, &output, nil, &transform, nil, vImage_Flags(kvImageEdgeExtend))
        guard status == kvImageNoError else { throw AiruError("resizeFailed", "vImage returned \(status)") }
        try Task.checkCancellation()
        // Clamp ringing to valid premultiplied RGBA, avoiding colored transparent fringes.
        let pixels = output.data.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * output.rowBytes + x * 4
                for channel in 0..<3 { pixels[i + channel] = min(pixels[i + channel], pixels[i + 3]) }
            }
        }
        let copied = Data(bytes: output.data, count: output.rowBytes * height)
        guard let provider = CGDataProvider(data: copied as CFData),
              let scaled = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: output.rowBytes, space: raster.colorSpace!, bitmapInfo: raster.bitmapInfo,
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw AiruError("resizeFailed", "Cannot create center-cropped image")
        }
        return scaled
    }
}
