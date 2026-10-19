import Foundation
import AiruCore
import Darwin

/// The Stage 1 protocol is the only source of processing status, sizes, and results.
public struct CLIEvent: Decodable, Sendable {
    public let protocolVersion: Int
    public let sequence: Int
    public let type: String
    public let analysis: ImageInfo?
    public let progress: ProgressUpdate?
    public let result: CompressionResult?
    public let destinationURL: URL?
    public let error: AiruError?
}

private final class InvocationControl: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var stopped = false
    private var timeout = false
    var timedOut: Bool { lock.withLock { timeout } }
    func launch(_ process: Process) throws {
        try lock.withLock {
            guard !stopped else { throw CancellationError() }
            self.process = process
            try process.run()
        }
    }
    func stop(timeout: Bool = false) {
        lock.withLock {
            self.timeout = self.timeout || timeout
            guard !stopped else { return }
            stopped = true
            guard let process, process.isRunning else { return }
            // CLI SIGINT performs encoder cancellation and workspace cleanup before exiting.
            kill(process.processIdentifier, SIGINT)
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
    }
}

public struct CLIProcessBridge: Sendable {
    public let executable: URL
    public init(executable: URL) { self.executable = executable }
    public func run(_ arguments: [String], timeout: Double = 240,
                    onEvent: @escaping @Sendable (CLIEvent) async -> Void) async throws {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw AiruError("missingCLI", "Airu's bundled compression executable is missing. Rebuild the application with Scripts/build.sh.")
        }
        try Task.checkCancellation()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("airu-frontend-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let diagnostics = directory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: diagnostics.path, contents: nil)
        let errorFile = try FileHandle(forWritingTo: diagnostics)
        defer { try? errorFile.close() }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = executable; process.arguments = arguments
        process.standardInput = FileHandle.nullDevice; process.standardOutput = pipe; process.standardError = errorFile
        process.environment = ["PATH": "/usr/bin:/bin", "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                               "TMPDIR": FileManager.default.temporaryDirectory.path, "LC_ALL": "C"]
        let control = InvocationControl()
        let (events, continuation) = AsyncThrowingStream<CLIEvent, any Error>.makeStream()
        let timer = Task {
            do { try await Task.sleep(for: .seconds(timeout)); control.stop(timeout: true) } catch {}
        }
        defer { timer.cancel(); try? pipe.fileHandleForReading.close(); try? pipe.fileHandleForWriting.close() }
        try await withTaskCancellationHandler {
            do {
                try control.launch(process)
                try pipe.fileHandleForWriting.close()
                // Blocking pipe reads use a dedicated queue, never the main/cooperative executor.
                DispatchQueue(label: "com.airu.cli.\(UUID())", qos: .userInitiated).async {
                    do {
                        var buffer = Data(), sequence = 0
                        let decoder = JSONDecoder()
                        var bytes = [UInt8](repeating: 0, count: 65536)
                        while true {
                            let count = Darwin.read(pipe.fileHandleForReading.fileDescriptor, &bytes, 65536)
                            if count == 0 { break }
                            if count < 0 {
                                if errno == EINTR { continue }
                                throw AiruError("io", "Could not read compression events")
                            }
                            buffer.append(contentsOf: bytes.prefix(count))
                            guard buffer.count < 4_194_304 else { throw AiruError("invalidProtocol", "CLI event exceeds the maximum size") }
                            while let end = buffer.firstIndex(of: 10) {
                                let line = Data(buffer[..<end]); buffer.removeSubrange(...end)
                                if line.isEmpty { continue }
                                let event = try decoder.decode(CLIEvent.self, from: line)
                                guard event.protocolVersion == 1, event.sequence == sequence + 1 else {
                                    throw AiruError("invalidProtocol", "Unsupported or unordered compression event")
                                }
                                sequence = event.sequence; continuation.yield(event)
                            }
                        }
                        guard buffer.isEmpty else { throw AiruError("invalidProtocol", "Truncated compression event") }
                        continuation.finish()
                    } catch { continuation.finish(throwing: error) }
                }
                var reportedError: AiruError?
                for try await event in events {
                    try Task.checkCancellation()
                    if let error = event.error { reportedError = error }
                    await onEvent(event)
                }
                while process.isRunning { try await Task.sleep(for: .milliseconds(10)) }
                if control.timedOut { throw AiruError("timeout", "Image processing exceeded its time limit") }
                try Task.checkCancellation()
                if let reportedError { throw reportedError }
                guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                    let details = (try? String(contentsOf: diagnostics, encoding: .utf8)) ?? ""
                    throw AiruError("processFailed", "Compression helper exited \(process.terminationStatus). \(details.prefix(1200))")
                }
            } catch {
                control.stop()
                await Task.detached { while process.isRunning { try? await Task.sleep(for: .milliseconds(20)) } }.value
                throw error
            }
        } onCancel: { control.stop() }
    }
}

private actor EventResult {
    var analysis: ImageInfo?
    var result: CompressionResult?
    var destination: URL?
    func consume(_ event: CLIEvent) {
        if let value = event.analysis { analysis = value }
        if let value = event.result { result = value }
        if let value = event.destinationURL { destination = value }
    }
}

public struct CompressionService: Sendable {
    public let bridge: CLIProcessBridge
    public let tools: URL?
    public let cache: URL?
    public init(executable: URL, tools: URL? = nil, cache: URL? = nil) {
        bridge = CLIProcessBridge(executable: executable); self.tools = tools; self.cache = cache
    }
    public static func bundled() -> CompressionService {
        CompressionService(executable: Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/airu-cli"))
    }
    private var cacheArguments: [String] { cache.map { ["--cache", $0.path] } ?? [] }
    public func analyze(_ source: URL) async throws -> ImageInfo {
        let value = EventResult()
        try await bridge.run(["analyze", source.path, "--json"], timeout: 30) { await value.consume($0) }
        guard let info = await value.analysis else { throw AiruError("invalidProtocol", "The compression helper returned no image analysis") }
        return info
    }
    public func prepare(_ source: URL, format: OutputFormat,
                        progress: @escaping ProgressHandler) async throws -> CompressionResult {
        let value = EventResult()
        let arguments = ["prepare", source.path, "--format", format.rawValue] + cacheArguments + (tools.map { ["--tools", $0.path] } ?? [])
        try await bridge.run(arguments) { event in
            await value.consume(event)
            if let update = event.progress { await progress(update) }
        }
        guard let result = await value.result else { throw AiruError("invalidProtocol", "The compression helper returned no prepared output") }
        return result
    }
    public func export(_ result: CompressionResult, to folder: URL) async throws -> URL {
        let value = EventResult()
        try await bridge.run(["export", "--key", result.cacheKey, "--destination", folder.path] + cacheArguments, timeout: 60) {
            await value.consume($0)
        }
        guard let destination = await value.destination else { throw AiruError("invalidProtocol", "The compression helper returned no exported file") }
        return destination
    }
}
