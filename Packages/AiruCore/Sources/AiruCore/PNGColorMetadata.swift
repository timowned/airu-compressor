import Foundation

/// Copies existing PNG color-description chunks without touching compressed pixel data.
/// pngquant otherwise converts ICC-tagged input to sRGB. Quantize numerical channels
/// untagged, then restore their original interpretation before color-managed evaluation.
enum PNGColorMetadata {
    private static let signature = Data([137, 80, 78, 71, 13, 10, 26, 10])
    private static let colorTypes: Set<String> = ["iCCP", "sRGB", "gAMA", "cHRM", "cICP", "mDCv", "cLLi"]
    private struct Chunk { let type: String; let bytes: Data }
    private static func chunks(_ data: Data) throws -> [Chunk] {
        guard data.starts(with: signature) else { throw AiruError("invalidPNG", "Invalid PNG signature") }
        var offset = 8
        var result: [Chunk] = []
        while offset < data.count {
            guard data.count - offset >= 12 else { throw AiruError("invalidPNG", "Truncated PNG chunk") }
            let length = data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            guard length <= data.count - offset - 12,
                  let type = String(data: data[(offset + 4)..<(offset + 8)], encoding: .ascii) else {
                throw AiruError("invalidPNG", "Invalid PNG chunk length or type")
            }
            result.append(Chunk(type: type, bytes: Data(data[offset..<(offset + length + 12)])))
            offset += length + 12
        }
        guard result.first?.type == "IHDR", result.last?.type == "IEND" else {
            throw AiruError("invalidPNG", "PNG is missing its header or end chunk")
        }
        return result
    }
    static func removingColor(from input: URL, to output: URL) throws {
        let content = try chunks(Data(contentsOf: input))
        var data = signature
        for chunk in content where !colorTypes.contains(chunk.type) { data.append(chunk.bytes) }
        try data.write(to: output)
    }
    static func restoringColor(from original: URL, in output: URL) throws {
        let color = try chunks(Data(contentsOf: original)).filter { colorTypes.contains($0.type) }
        let content = try chunks(Data(contentsOf: output)).filter { !colorTypes.contains($0.type) }
        var data = signature
        for chunk in content {
            data.append(chunk.bytes)
            if chunk.type == "IHDR" { for profile in color { data.append(profile.bytes) } }
        }
        try data.write(to: output, options: .atomic)
    }
}
