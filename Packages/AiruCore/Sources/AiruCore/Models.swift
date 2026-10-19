import Foundation

public enum ImageFormat: String, Codable, Sendable, CaseIterable {
    case jpeg, png, avif, webp, heic
    public var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
}
public enum OutputFormat: String, Codable, Sendable, CaseIterable {
    case auto, avif, webp, jpeg, png
    public var imageFormat: ImageFormat? { ImageFormat(rawValue: rawValue) }
}
public enum ProcessingStatus: String, Codable, Sendable {
    case queued, analyzing, optimizing, ready, exporting, completed, failed, cancelled
}
public struct AiruError: Error, Codable, Sendable, LocalizedError, Equatable {
    public let code: String
    public let message: String
    public var errorDescription: String? { message }
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
    public static func wrapping(_ error: any Error) -> Self {
        if let error = error as? Self { return error }
        if error is CancellationError { return Self("cancelled", "Processing cancelled") }
        return Self("io", error.localizedDescription)
    }
}
public struct ImageInfo: Codable, Sendable, Equatable {
    public let sourceURL: URL
    public let originalFilename: String
    public let format: ImageFormat
    public let fileSize: Int64
    /// Dimensions after applying EXIF orientation. No resizing is performed.
    public let width: Int
    public let height: Int
    public let storedWidth: Int
    public let storedHeight: Int
    public let colorProfile: String?
    public let colorProfileSHA256: String?
    public let hasAlpha: Bool
    public let orientation: Int
    public let bitsPerComponent: Int
    public let canDecode: Bool
    public let frameCount: Int
    public let contentSHA256: String
}
public struct OptimizationOptions: Codable, Sendable, Equatable {
    public var format: OutputFormat
    public var minimumScore: Double
    public var maxCandidates: Int
    public var timeoutSeconds: Double
    public var encoderThreads: Int
    public init(format: OutputFormat = .auto, minimumScore: Double = 90, maxCandidates: Int = 24,
                timeoutSeconds: Double = 180, encoderThreads: Int = 2) {
        self.format = format; self.minimumScore = minimumScore; self.maxCandidates = maxCandidates
        self.timeoutSeconds = timeoutSeconds; self.encoderThreads = encoderThreads
    }
    public func validate() throws {
        guard minimumScore.isFinite, (0...100).contains(minimumScore), (4...64).contains(maxCandidates),
              timeoutSeconds.isFinite, (1...3600).contains(timeoutSeconds), (1...8).contains(encoderThreads) else {
            throw AiruError("invalidOptions", "Score must be 0...100, candidates 4...64, timeout 1...3600, threads 1...8")
        }
    }
}
public struct CandidateRecord: Codable, Sendable {
    public let format: ImageFormat
    public let quality: Int?
    public let lossless: Bool
    public let bytes: Int64
    public let score: Double
}
public enum QualityVerification: String, Codable, Sendable { case ssimulacra2, unchangedOriginal }
public struct CompressionResult: Codable, Sendable {
    public let cacheKey: String
    public let source: ImageInfo
    public let options: OptimizationOptions
    public let selectedFormat: ImageFormat
    public let outputSize: Int64
    public let perceptualScore: Double?
    public let verification: QualityVerification
    public let alreadyOptimized: Bool
    public let cachedFileURL: URL
    public let outputSHA256: String
    public let candidates: [CandidateRecord]
    public let savingsPercentage: Double
}
public struct CompressionJob: Codable, Sendable, Identifiable {
    public let id: UUID
    public let sourceURL: URL
    public var originalFilename: String
    public var originalFormat: ImageFormat?
    public var originalSize: Int64?
    public var selectedOutputFormat: ImageFormat?
    public var outputSize: Int64?
    public var savingsPercentage: Double?
    public var perceptualQualityScore: Double?
    public var progress: Double
    public var status: ProcessingStatus
    public var destinationURL: URL?
    public var error: AiruError?
    public var result: CompressionResult?
    public init(id: UUID = UUID(), sourceURL: URL) {
        self.id = id; self.sourceURL = sourceURL; originalFilename = sourceURL.lastPathComponent
        progress = 0; status = .queued
    }
}
public struct ProgressUpdate: Codable, Sendable {
    public let status: ProcessingStatus
    public let fraction: Double
    public let message: String
    public let candidate: CandidateRecord?
    public init(_ status: ProcessingStatus, _ fraction: Double, _ message: String, candidate: CandidateRecord? = nil) {
        self.status = status; self.fraction = fraction; self.message = message; self.candidate = candidate
    }
}
public typealias ProgressHandler = @Sendable (ProgressUpdate) async -> Void
public struct BatchSnapshot: Codable, Sendable {
    public let jobs: [CompressionJob]
    public let progress: Double
    public let isFinished: Bool
    public init(jobs: [CompressionJob]) {
        self.jobs = jobs
        progress = jobs.isEmpty ? 1 : jobs.reduce(0) { $0 + $1.progress } / Double(jobs.count)
        isFinished = jobs.allSatisfy { [.ready, .completed, .failed, .cancelled].contains($0.status) }
    }
}
