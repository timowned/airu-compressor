import Foundation
import AiruCore

/// The same command contract drives discovery and preflight argument validation.
struct CommandContract: Codable, Sendable {
    let name: String
    let summary: String
    let minimumFiles: Int
    let maximumFiles: Int?
    let options: [String]
    let requiredOptions: [String]
    let terminalEvents: [String]
    let writes: [String]

    static let processingOptions = ["--upscale", "--alignment", "--scale", "--width", "--height", "--format", "--mode", "--score", "--candidates", "--timeout", "--threads"]
    static let all: [Self] = [
        .init(name: "capabilities", summary: "Discover commands without tools or image access", minimumFiles: 0, maximumFiles: 0,
              options: [], requiredOptions: [], terminalEvents: ["capabilities"], writes: []),
        .init(name: "analyze", summary: "Validate image contents and read metadata; no compression", minimumFiles: 1, maximumFiles: nil,
              options: [], requiredOptions: [], terminalEvents: ["analysis", "error"], writes: []),
        .init(name: "prepare", summary: "Optimize into the cache without exporting", minimumFiles: 1, maximumFiles: 1,
              options: processingOptions, requiredOptions: [], terminalEvents: ["ready"], writes: ["cache", "temporary workspace"]),
        .init(name: "optimize", summary: "Prepare and export; an omitted destination uses the Desktop", minimumFiles: 1, maximumFiles: 1,
              options: processingOptions + ["--destination"], requiredOptions: [], terminalEvents: ["ready", "exported"], writes: ["cache", "temporary workspace", "destination"]),
        .init(name: "batch", summary: "Prepare multiple files; export only with an explicit destination", minimumFiles: 1, maximumFiles: nil,
              options: processingOptions + ["--destination", "--concurrency"], requiredOptions: [], terminalEvents: ["batchCompleted"], writes: ["cache", "temporary workspace", "destination when supplied"]),
        .init(name: "export", summary: "Validate and copy a prepared artifact without recompressing", minimumFiles: 0, maximumFiles: 0,
              options: ["--key", "--destination"], requiredOptions: ["--key"], terminalEvents: ["exported"], writes: ["destination", "invalid cache entry cleanup"]),
        .init(name: "doctor", summary: "Report tool executable availability and fingerprint; does not run encoders", minimumFiles: 0, maximumFiles: 0,
              options: [], requiredOptions: [], terminalEvents: ["toolchain"], writes: []),
        .init(name: "help", summary: "Human-readable usage", minimumFiles: 0, maximumFiles: 0,
              options: [], requiredOptions: [], terminalEvents: [], writes: [])
    ]
}

struct OptionContract: Codable, Sendable {
    let name: String
    let valueType: String
    var allowedValues: [String]? = nil
    var defaultValue: String? = nil
    var minimum: Double? = nil
    var maximum: Double? = nil
    let summary: String
}

struct AgentCapabilities: Encodable, Sendable {
    let contractVersion = 1
    let eventProtocolVersion = 1
    let transport = "ndjson"
    let processing = "offline"
    let globalOptions = ["--json", "--request-id", "--tools", "--cache", "--help"]
    let commands = CommandContract.all
    let outputFormats = OutputFormat.allCases.map(\.rawValue)
    let pngModes = PNGCompressionMode.allCases.map(\.rawValue)
    let defaultOptimizationOptions = OptimizationOptions()
    let modeScoreDefaults = ["airy": 90, "superlight": 80]
    let qualityMetric = "SSIMULACRA2"
    let exitCodes = ["0": "success", "1": "usage, processing, or export failure; a batch can partially succeed", "130": "cancelled"]
    let options: [OptionContract] = [
        .init(name: "--json", valueType: "flag", defaultValue: "false", summary: "Suppress progress only; terminal records remain NDJSON, not a JSON array"),
        .init(name: "--request-id", valueType: "string", summary: "Caller correlation ID, 1...128 UTF-8 bytes with no control characters; echoed on events after argument parsing"),
        .init(name: "--tools", valueType: "directory", summary: "Explicit Encoders directory; otherwise AIRU_ENCODER_DIR then bundled tools; never PATH"),
        .init(name: "--cache", valueType: "directory", summary: "Cache root; use the same root for prepare and export"),
        .init(name: "--help", valueType: "flag", summary: "Show human-readable help without processing"),
        .init(name: "--format", valueType: "enum", allowedValues: OutputFormat.allCases.map(\.rawValue) + ["jpg"], defaultValue: "auto", summary: "Auto never selects a larger output; forced formats may be larger"),
        .init(name: "--mode", valueType: "enum", allowedValues: PNGCompressionMode.allCases.map(\.rawValue), defaultValue: "airy", summary: "Airy uses lossless PNG; Superlight uses palette PNG with score >=80"),
        .init(name: "--upscale", valueType: "integer", allowedValues: ["2", "4"], summary: "Real-ESRGAN offline super-resolution; exclusive with resize; encoding score compares to AI reference"),
        .init(name: "--alignment", valueType: "enum", allowedValues: CropAlignment.allCases.map(\.rawValue), defaultValue: "center", summary: "Crop anchor; requires exact width and height"),
        .init(name: "--scale", valueType: "number", defaultValue: "100", minimum: 0, maximum: 10000, summary: "Positive percentage of each oriented original; exclusive with exact resolution"),
        .init(name: "--width", valueType: "integer", minimum: 1, maximum: 65500, summary: "Exact centered aspect-fill width; requires --height; maximum 100 megapixels"),
        .init(name: "--height", valueType: "integer", minimum: 1, maximum: 65500, summary: "Exact centered aspect-fill height; requires --width"),
        .init(name: "--score", valueType: "number", defaultValue: "90 (Airy), 80 (Superlight)", minimum: 0, maximum: 100, summary: "SSIMULACRA2 minimum; Superlight minimum is 80"),
        .init(name: "--candidates", valueType: "integer", defaultValue: "24", minimum: 4, maximum: 64, summary: "Maximum evaluated candidates per file"),
        .init(name: "--timeout", valueType: "number", defaultValue: "180", minimum: 1, maximum: 3600, summary: "Per-file optimization budget in seconds; allow extra time for analysis, hashing and export"),
        .init(name: "--threads", valueType: "integer", defaultValue: "2", minimum: 1, maximum: 8, summary: "Encoder threads per file"),
        .init(name: "--concurrency", valueType: "integer", defaultValue: "2", minimum: 1, maximum: 8, summary: "Concurrent batch jobs"),
        .init(name: "--key", valueType: "sha256", summary: "Lowercase 64-character cache key returned by ready"),
        .init(name: "--destination", valueType: "directory", summary: "Export directory; unique names prevent overwriting; optimize/export default to ~/Desktop/Airu Compressed/")
    ]
}

struct ToolAvailability: Codable, Sendable {
    let name: EncoderTool
    let executableURL: URL
    let executable: Bool
}

struct ToolchainReport: Codable, Sendable {
    let directoryURL: URL
    let tools: [ToolAvailability]
    let allExecutable: Bool
    let fingerprint: String?
}
