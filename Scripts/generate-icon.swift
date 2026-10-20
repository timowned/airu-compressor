import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

// Apple's bitmap macOS family: five point sizes, each with standard and Retina art.
// Airu's existing 80% optical footprint is a design choice, not an Apple requirement.
struct IconSlot: Decodable {
    let filename: String
    let idiom: String
    let scale: String
    let size: String
    var points: Int { Int(size.split(separator: "x")[0]) ?? 0 }
    var pixels: Int { points * (scale == "2x" ? 2 : 1) }
}
struct Catalog: Decodable { let images: [IconSlot] }
struct IconError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")
let slots = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalog.appendingPathComponent("Contents.json"))).images
let expectedNames = Set([16, 32, 128, 256, 512].flatMap { points in
    ["icon_\(points)x\(points).png", "icon_\(points)x\(points)@2x.png"]
})
guard slots.count == 10, Set(slots.map(\.filename)) == expectedNames,
      slots.allSatisfy({ $0.idiom == "mac" && ["1x", "2x"].contains($0.scale)
          && $0.size == "\($0.points)x\($0.points)"
          && $0.filename == "icon_\($0.points)x\($0.points)\($0.scale == "2x" ? "@2x" : "").png" }) else {
    throw IconError("AppIcon must contain all ten correctly named macOS 1x/2x slots")
}

func readImage(_ url: URL, pixels: Int) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == pixels, image.height == pixels else {
        throw IconError("Expected a decodable \(pixels)×\(pixels) icon at \(url.path)")
    }
    return image
}

func validateIcons(in directory: URL) throws {
    for slot in slots {
        let image = try readImage(directory.appendingPathComponent(slot.filename), pixels: slot.pixels)
        guard [.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo) else {
            throw IconError("Missing transparency in \(slot.filename)")
        }
    }
}

func runIconutil(_ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
        throw IconError("iconutil failed with status \(process.terminationStatus)")
    }
}

func verifyBundle(_ app: URL) throws {
    let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any]
    guard info?["CFBundleIconName"] as? String == "AppIcon",
          info?["CFBundleIconFile"] as? String == "AiruIcon" else {
        throw IconError("App bundle must declare both the AppIcon asset and ICNS resource")
    }
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("airu-icon-check-\(UUID())")
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let extracted = temporary.appendingPathComponent("AppIcon.iconset")
    let resource = app.appendingPathComponent("Contents/Resources/AiruIcon.icns")
    try runIconutil(["-c", "iconset", resource.path, "-o", extracted.path])
    try validateIcons(in: extracted)
    guard let nativeImage = NSImage(contentsOf: resource),
          Set([16, 32, 64, 128, 256, 512, 1024]).isSubset(of: Set(nativeImage.representations.map(\.pixelsWide))) else {
        throw IconError("AppKit could not load the complete icon family for system drawing")
    }
    print("Verified packaged app icon: 10 standard/Retina representations, 16–1024px, declared bundle identity")
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first ?? "--generate" {
case "--generate":
    guard arguments.count <= 1 else { throw IconError("Usage: generate-icon.swift [--generate | --package APP | --verify APP]") }
    let source = try readImage(root.appendingPathComponent("App/IconSource.png"), pixels: 1024)
    for slot in slots {
        let pixels = slot.pixels
        guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                bytesPerRow: pixels * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw IconError("Cannot allocate icon raster") }
        context.interpolationQuality = .high
        let side = Double(pixels) * 0.8
        let inset = (Double(pixels) - side) / 2
        context.draw(source, in: CGRect(x: inset, y: inset, width: side, height: side))
        let output = catalog.appendingPathComponent(slot.filename)
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw IconError("Cannot create \(output.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw IconError("Failed to write \(output.path)") }
    }
    try validateIcons(in: catalog)
    print("Generated 10 macOS app icon slots from the 1024px master with consistent transparent padding")
case "--package":
    guard arguments.count == 2 else { throw IconError("--package requires an app bundle path") }
    try validateIcons(in: catalog)
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("airu-icon-build-\(UUID()).iconset")
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    for slot in slots {
        try FileManager.default.copyItem(at: catalog.appendingPathComponent(slot.filename), to: temporary.appendingPathComponent(slot.filename))
    }
    let app = URL(fileURLWithPath: arguments[1], isDirectory: true)
    // actool can emit a reduced compatibility ICNS. Keep the full family for system
    // surfaces and the explicit running Dock icon loaded by AppDelegate.
    try runIconutil(["-c", "icns", temporary.path, "-o", app.appendingPathComponent("Contents/Resources/AiruIcon.icns").path])
    try verifyBundle(app)
case "--verify":
    guard arguments.count == 2 else { throw IconError("--verify requires an app bundle path") }
    try verifyBundle(URL(fileURLWithPath: arguments[1], isDirectory: true))
default:
    throw IconError("Usage: generate-icon.swift [--generate | --package APP | --verify APP]")
}
