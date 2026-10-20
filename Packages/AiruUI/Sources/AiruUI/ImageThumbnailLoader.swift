import Foundation
import CoreGraphics
import ImageIO

/// Small, oriented previews decoded off the main thread. Serial decoding bounds
/// memory use when a batch of large PNGs enters the visible list at once.
final class ImageThumbnailLoader: @unchecked Sendable {
    static let shared = ImageThumbnailLoader()
    private let queue = DispatchQueue(label: "com.airu.thumbnails", qos: .utility)
    private let cache = NSCache<NSString, CGImage>()
    private init() {
        cache.countLimit = 128
        cache.totalCostLimit = 4 * 1024 * 1024
    }
    func image(at url: URL, contentIdentity: String, maximumPixels: Int = 88) async -> CGImage? {
        guard !Task.isCancelled, maximumPixels > 0 else { return nil }
        let key = "\(url.standardizedFileURL.path)|\(contentIdentity)|\(maximumPixels)"
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                let cacheKey = key as NSString
                if let image = cache.object(forKey: cacheKey) {
                    continuation.resume(returning: image)
                    return
                }
                let access = ScopedURL(url)
                defer { withExtendedLifetime(access) {} }
                guard let source = CGImageSourceCreateWithURL(url as CFURL,
                    [kCGImageSourceShouldCache: false] as CFDictionary) else {
                    continuation.resume(returning: nil)
                    return
                }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
                    kCGImageSourceShouldCacheImmediately: true
                ]
                let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                if let image { cache.setObject(image, forKey: cacheKey, cost: image.bytesPerRow * image.height) }
                continuation.resume(returning: image)
            }
        }
    }
}
