import Foundation

extension ImageFormat {
    /// Limits of the bundled encode/decode pipeline, independent of the source pixel budget.
    var encodingDimensionLimit: Int? {
        switch self {
        case .webp: 16_383
        case .jpeg: 65_500
        case .avif: 32_768 // avifdec's default --dimension-limit must also accept the output.
        case .png, .heic: nil
        }
    }
}

public struct EncoderRequest: Sendable {
    public let format: ImageFormat
    public let quality: Int
    public let lossless: Bool
    public let inputPNG: URL
    public let originalJPEG: URL?
    public let iccProfile: URL?
    public let output: URL
    public let threads: Int
}
public protocol EncoderAdapter: Sendable {
    func encode(_ request: EncoderRequest, timeout: Double) async throws
}
public struct NativeEncoderAdapter: EncoderAdapter {
    public let tools: Toolchain
    public init(tools: Toolchain) { self.tools = tools }
    public func encode(_ r: EncoderRequest, timeout: Double) async throws {
        let tool: EncoderTool
        var args: [String]
        switch r.format {
        case .avif:
            tool = .avifenc
            args = ["--jobs", String(r.threads), "--speed", "6", "--yuv", "444", "--qcolor", String(r.quality), "--qalpha", "100"]
            if r.lossless { args += ["--lossless"] }
            if let profile = r.iccProfile { args += ["--icc", profile.path] }
            args += [r.inputPNG.path, r.output.path]
        case .webp:
            tool = .cwebp
            args = ["-quiet", "-m", "6", "-q", String(r.quality), "-alpha_q", "100", "-exact", "-metadata", "icc"]
            if r.lossless { args += ["-lossless"] } else { args += ["-sharp_yuv"] }
            args += ["-o", r.output.path, "--", r.inputPNG.path]
        case .jpeg:
            if let original = r.originalJPEG, r.lossless {
                tool = .jpegtran
                args = ["-copy", "all", "-optimize", "-progressive", "-outfile", r.output.path, original.path]
            } else {
                tool = .cjpeg
                args = ["-quality", String(r.quality), "-sample", "1x1", "-optimize", "-progressive"]
                if let profile = r.iccProfile { args += ["-icc", profile.path] }
                args += ["-outfile", r.output.path, r.inputPNG.path]
            }
        case .png:
            tool = .oxipng
            let deadline = Date().addingTimeInterval(timeout)
            let untagged = r.output.deletingLastPathComponent().appendingPathComponent("untagged-\(UUID()).png")
            let palette = r.output.deletingLastPathComponent().appendingPathComponent("palette-\(UUID()).png")
            defer { Files.remove(untagged); Files.remove(palette) }
            if !r.lossless {
                try PNGColorMetadata.removingColor(from: r.inputPNG, to: untagged)
                // This quality scale controls libimagequant's palette search, not SSIMULACRA2.
                // min=0 ensures poor probes are returned for our independent metric to reject.
                _ = try await ProcessRunner().run(executable: tools.executable(.pngquant),
                    arguments: ["--speed", "4", "--quality", "0-\(r.quality)", "--output", palette.path, "--", untagged.path],
                    timeout: deadline.timeIntervalSinceNow)
                try PNGColorMetadata.restoringColor(from: r.inputPNG, in: palette)
            }
            // Keep color profile chunks and hidden RGB. Do not use --alpha or --strip all.
            args = ["-o", "3", "--nc", "--threads", String(r.threads), "--out", r.output.path,
                    r.lossless ? r.inputPNG.path : palette.path]
            _ = try await ProcessRunner().run(executable: tools.executable(tool), arguments: args, timeout: deadline.timeIntervalSinceNow)
            guard try Files.size(r.output) > 0 else { throw AiruError("encodeFailed", "PNG pipeline returned an empty file") }
            return
        case .heic: throw AiruError("unsupportedOutput", "HEIC is input-only")
        }
        _ = try await ProcessRunner().run(executable: tools.executable(tool), arguments: args, timeout: timeout)
        guard try Files.size(r.output) > 0 else { throw AiruError("encodeFailed", "Encoder returned an empty file") }
    }
}
