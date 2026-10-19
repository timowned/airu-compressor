import Foundation
import Darwin

public enum EncoderTool: String, Codable, Sendable, CaseIterable {
    case avifenc, avifdec, cwebp, dwebp, cjpeg, jpegtran, oxipng, ssimulacra2
}
public struct Toolchain: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory.standardizedFileURL }
    /// No PATH lookup: an explicit installation or the application bundle owns all executable code.
    public static func bundled() throws -> Toolchain {
        if let path = ProcessInfo.processInfo.environment["AIRU_ENCODER_DIR"] { return .init(directory: URL(fileURLWithPath: path)) }
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let candidates = [Bundle.main.resourceURL?.appendingPathComponent("Encoders"),
                          executable.deletingLastPathComponent().appendingPathComponent("../Resources/Encoders").standardizedFileURL]
        for case let url? in candidates where FileManager.default.fileExists(atPath: url.appendingPathComponent("bin").path) {
            return .init(directory: url)
        }
        throw AiruError("missingToolchain", "Supply --tools <Encoders directory> or bundle Resources/Encoders")
    }
    public func executable(_ tool: EncoderTool) throws -> URL {
        let url = directory.appendingPathComponent("bin/\(tool.rawValue)")
        guard Files.fm.isExecutableFile(atPath: url.path) else {
            throw AiruError("missingEncoder", "Required bundled executable is missing: \(url.path)")
        }
        return url
    }
    public func fingerprint() throws -> String {
        var data = Data("airu-toolchain-v1".utf8)
        for tool in EncoderTool.allCases { data.append(contentsOf: try Files.digest(executable(tool)).utf8) }
        if let manifest = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")) { data.append(manifest) }
        return Files.hash(data)
    }
}
public struct ProcessOutput: Sendable { public let stdout: String; public let stderr: String }

private final class ProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    func launch(_ process: Process) throws {
        lock.lock(); defer { lock.unlock() }
        if cancelled { throw CancellationError() }
        self.process = process
        try process.run()
    }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        if let process, process.isRunning { process.terminate() }
    }
}

public struct ProcessRunner: Sendable {
    public init() {}
    public func run(executable: URL, arguments: [String], timeout: Double) async throws -> ProcessOutput {
        try Task.checkCancellation()
        guard timeout > 0 else { throw AiruError("timeout", "Optimization time limit exceeded") }
        let work = Files.fm.temporaryDirectory.appendingPathComponent("airu-process-\(UUID())", isDirectory: true)
        try Files.directory(work)
        defer { Files.remove(work) }
        let stdoutURL = work.appendingPathComponent("stdout"), stderrURL = work.appendingPathComponent("stderr")
        Files.fm.createFile(atPath: stdoutURL.path, contents: nil)
        Files.fm.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL), stderr = try FileHandle(forWritingTo: stderrURL)
        defer { try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = executable; process.arguments = arguments
        process.standardOutput = stdout; process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        // Do not inherit dynamic loader overrides or user encoder settings.
        process.environment = ["PATH": "/usr/bin:/bin", "LC_ALL": "C", "TMPDIR": work.path, "RAYON_NUM_THREADS": "2"]
        let cancellation = ProcessCancellation()
        return try await withTaskCancellationHandler {
            try cancellation.launch(process)
            let deadline = Date().addingTimeInterval(timeout)
            do {
                while process.isRunning {
                    try Task.checkCancellation()
                    if Date() >= deadline { throw AiruError("timeout", "\(executable.lastPathComponent) exceeded its time limit") }
                    try await Task.sleep(for: .milliseconds(25))
                }
                try Task.checkCancellation()
            } catch {
                if process.isRunning { process.terminate() }
                // SIGTERM can be ignored. Use an uncancelled cleanup task and let Foundation reap.
                await Task.detached {
                    for _ in 0..<20 where process.isRunning { try? await Task.sleep(for: .milliseconds(10)) }
                }.value
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                await Task.detached {
                    while process.isRunning { try? await Task.sleep(for: .milliseconds(10)) }
                }.value
                throw error
            }
            // isRunning is false only once Foundation has collected termination status.
            // waitUntilExit spins a thread-local run loop and can hang on Swift's cooperative executor.
            func read(_ url: URL) -> String {
                guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
                defer { try? handle.close() }
                return String(decoding: (try? handle.read(upToCount: 1_048_576)) ?? Data(), as: UTF8.self)
            }
            let output = ProcessOutput(stdout: read(stdoutURL), stderr: read(stderrURL))
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                throw AiruError("processFailed", "\(executable.lastPathComponent) exited \(process.terminationStatus): \(output.stderr.prefix(2000))")
            }
            return output
        } onCancel: { cancellation.cancel() }
    }
}
