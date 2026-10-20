import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Retain the unpadded master and apply consistent Dock-sized artwork at every resolution.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("App/IconSource.png")
let catalog = root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")
let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog.appendingPathComponent("Contents.json"))) as! [String: Any]
for item in contents["images"] as! [[String: String]] {
    let points = Int(item["size"]!.split(separator: "x")[0])!
    let pixels = points * (item["scale"] == "2x" ? 2 : 1)
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
        bytesPerRow: pixels * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    let side = Double(pixels) * 0.8
    let inset = (Double(pixels) - side) / 2
    context.draw(image, in: CGRect(x: inset, y: inset, width: side, height: side))
    let output = catalog.appendingPathComponent(item["filename"]!)
    let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Failed to write \(output.path)") }
}
print("Generated 10 app icon sizes with centered 80% artwork and transparent padding")
