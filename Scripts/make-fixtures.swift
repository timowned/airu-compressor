import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func save(_ image: CGImage, _ name: String, type: UTType = .png, properties: [CFString: Any] = [:]) {
    let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent(name) as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    precondition(CGImageDestinationFinalize(destination))
}
let source = CGImageSourceCreateWithURL(root.appendingPathComponent("photo.png") as CFURL, nil)!
let photo = CGImageSourceCreateImageAtIndex(source, 0, nil)!
save(photo, "photo.jpg", type: .jpeg, properties: [kCGImageDestinationLossyCompressionQuality: 0.98])
save(photo, "oriented.jpg", type: .jpeg, properties: [kCGImagePropertyOrientation: 6, kCGImageDestinationLossyCompressionQuality: 0.98])
let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
let color = CGContext(data: nil, width: photo.width, height: photo.height, bitsPerComponent: 8, bytesPerRow: 0,
                      space: p3, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
color.draw(photo, in: CGRect(x: 0, y: 0, width: photo.width, height: photo.height))
color.setFillColor(CGColor(colorSpace: p3, components: [1, 0, 0.2, 1])!)
color.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
save(color.makeImage()!, "profile-p3.png")
let transparent = CGContext(data: nil, width: 192, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
transparent.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.7))
transparent.fillEllipse(in: CGRect(x: 12.3, y: 12.3, width: 100, height: 100))
transparent.setFillColor(CGColor(red: 1, green: 0.1, blue: 0.2, alpha: 1))
transparent.fill(CGRect(x: 90, y: 30, width: 90, height: 48))
save(transparent.makeImage()!, "transparent.png")
let tiny = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
tiny.setFillColor(CGColor(gray: 0.5, alpha: 1)); tiny.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
save(tiny.makeImage()!, "tiny.png")
// A deterministic, lightly textured gradient exercises palette quantization,
// wide-gamut metadata, and binary transparency without storing private screenshots.
var seed: UInt32 = 42
for alpha in [false, true] {
    var pixels = [UInt8](repeating: 255, count: 256 * 128 * 4)
    for y in 0..<128 { for x in 0..<256 {
        let i = (y * 256 + x) * 4
        seed = seed &* 1664525 &+ 1013904223
        let noise = Int(seed >> 24) % 7 - 3
        let visible = !alpha || x < 224
        pixels[i] = visible ? UInt8(64 + x / 2 + noise) : 0
        pixels[i + 1] = visible ? UInt8(64 + y / 2 + noise) : 0
        pixels[i + 2] = visible ? UInt8(200 - x / 4 + noise) : 0
        pixels[i + 3] = visible ? 255 : 0
    } }
    let image = CGImage(width: 256, height: 128, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024,
                        space: p3, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                        provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil,
                        shouldInterpolate: false, intent: .defaultIntent)!
    save(image, alpha ? "palette-alpha.png" : "palette-graphic.png")
}
print("Generated JPEG, EXIF rotation, Display P3 ICC, alpha-edge, and tiny fixtures")
