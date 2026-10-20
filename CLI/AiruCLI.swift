import Foundation
import AiruCore
import Darwin

private struct Arguments {
    let command: String
    var files: [URL] = []
    var options = OptimizationOptions()
    var tools: URL?
    var cache: URL?
    var destination: URL?
    var key: String?
    var concurrency = 2
    var json = false
    var requestID: String?
    var help = false
    private var suppliedOptions: Set<String> = []
    init(_ args: [String]) throws {
        command = args.first ?? "help"
        var index = 1
        var explicitScore = false
        while index < args.count {
            let arg = args[index]; index += 1
            if arg.hasPrefix("--"), arg != "--", !suppliedOptions.insert(arg).inserted {
                throw AiruError("usage", "Duplicate option \(arg)")
            }
            func value() throws -> String {
                guard index < args.count, !args[index].isEmpty, !args[index].hasPrefix("--") else {
                    throw AiruError("usage", "Missing value for \(arg); use ./ for paths beginning with --")
                }
                defer { index += 1 }; return args[index]
            }
            switch arg {
            case "--format":
                let raw = try value()
                guard let f = OutputFormat(rawValue: raw == "jpg" ? "jpeg" : raw) else { throw AiruError("usage", "Invalid output format \(raw)") }
                options.format = f
            case "--mode":
                guard let mode = PNGCompressionMode(rawValue: try value()) else { throw AiruError("usage", "Mode must be airy or superlight") }
                options.pngMode = mode
            case "--score": guard let n = Double(try value()) else { throw AiruError("usage", "Invalid score") }; options.minimumScore = n; explicitScore = true
            case "--candidates": guard let n = Int(try value()) else { throw AiruError("usage", "Invalid candidate count") }; options.maxCandidates = n
            case "--timeout": guard let n = Double(try value()) else { throw AiruError("usage", "Invalid timeout") }; options.timeoutSeconds = n
            case "--threads": guard let n = Int(try value()) else { throw AiruError("usage", "Invalid thread count") }; options.encoderThreads = n
            case "--concurrency":
                guard let n = Int(try value()), (1...8).contains(n) else { throw AiruError("usage", "Concurrency must be 1...8") }; concurrency = n
            case "--tools": tools = URL(fileURLWithPath: try value(), isDirectory: true)
            case "--cache": cache = URL(fileURLWithPath: try value(), isDirectory: true)
            case "--destination": destination = URL(fileURLWithPath: try value(), isDirectory: true)
            case "--key": key = try value()
            case "--json": json = true
            case "--request-id": requestID = try value()
            case "--help", "-h": help = true
            case "--": files += args[index...].map { URL(fileURLWithPath: $0) }; index = args.count
            default:
                guard !arg.hasPrefix("--") else { throw AiruError("usage", "Unknown option \(arg)") }
                files.append(URL(fileURLWithPath: arg))
            }
        }
        if options.pngMode == .superlight && !explicitScore { options.minimumScore = 80 }
    }
    func validate() throws {
        if let requestID {
            guard (1...128).contains(requestID.utf8.count),
                  !requestID.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw AiruError("usage", "Request ID must be 1...128 UTF-8 bytes with no control characters")
            }
        }
        let name = ["--help", "-h"].contains(command) ? "help" : command
        guard let contract = CommandContract.all.first(where: { $0.name == name }) else {
            throw AiruError("usage", "Unknown command \(command); use capabilities for machine-readable usage")
        }
        if help { return }
        let allowed = Set(contract.options + AgentCapabilities().globalOptions)
        guard suppliedOptions.isSubset(of: allowed) else {
            throw AiruError("usage", "Options not supported by \(name): \(suppliedOptions.subtracting(allowed).sorted().joined(separator: ", "))")
        }
        guard files.count >= contract.minimumFiles,
              contract.maximumFiles.map({ files.count <= $0 }) ?? true else {
            throw AiruError("usage", "Invalid input file count for \(name); use capabilities for limits")
        }
        for option in contract.requiredOptions where !suppliedOptions.contains(option) {
            throw AiruError("usage", "\(name) requires \(option)")
        }
        if let key {
            guard key.utf8.count == 64, key.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                throw AiruError("invalidCacheKey", "Cache keys must be lowercase SHA-256 values")
            }
        }
        if ["prepare", "optimize", "batch"].contains(name) { try options.validate() }
    }
}
private struct Event: Encodable, Sendable {
    var protocolVersion = 1
    var sequence = 0
    var type: String
    var sourceURL: URL?
    var analysis: ImageInfo?
    var progress: ProgressUpdate?
    var result: CompressionResult?
    var batch: BatchSnapshot?
    var destinationURL: URL?
    var error: AiruError?
    var message: String?
    var requestID: String?
    var capabilities: AgentCapabilities?
    var toolchain: ToolchainReport?
}
private actor Output {
    private var sequence = 0
    private var requestID: String?
    func correlate(_ value: String?) { requestID = value }
    func send(_ event: Event) {
        var event = event; sequence += 1; event.sequence = sequence
        event.requestID = requestID
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(event) { FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10])) }
    }
}
@main struct AiruCLI {
    static func main() async {
        let output = Output()
        let task = Task { () -> Int32 in
            do {
                let args = try Arguments(Array(CommandLine.arguments.dropFirst()))
                // Malformed IDs are not echoed into the protocol.
                if let id = args.requestID, (1...128).contains(id.utf8.count),
                   !id.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                    await output.correlate(id)
                }
                try args.validate()
                return try await run(args, output: output)
            }
            catch {
                let error = AiruError.wrapping(error)
                await output.send(Event(type: "error", error: error))
                return error.code == "cancelled" ? 130 : 1
            }
        }
        signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN)
        let sources = [SIGINT, SIGTERM].map { signalNumber in
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler { task.cancel() }; source.resume(); return source
        }
        let code = await task.value
        for source in sources { source.cancel() }
        exit(code)
    }
    private static func run(_ args: Arguments, output: Output) async throws -> Int32 {
        if args.help || ["help", "--help", "-h"].contains(args.command) {
            print("""
            Airu — offline perceptual image compression (NDJSON protocol v1)
            airu capabilities [--json]
            airu analyze FILE... [--json]
            airu prepare FILE [--format auto|avif|webp|jpeg|png] [OPTIONS]
            airu optimize FILE [--destination DIR] [OPTIONS]
            airu batch FILE... [--destination DIR] [--concurrency 2] [OPTIONS]
            airu export --key SHA256 [--cache DIR] [--destination DIR]
            airu doctor --tools DIR
            OPTIONS: --tools DIR --cache DIR --mode airy|superlight --score N --candidates 24 --timeout 180 --threads 2
            Airy: lossless PNG, score 90 for other formats. Superlight: palette PNG, score 80 (minimum).
            --json suppresses progress; terminal records remain one JSON object per line.
            --request-id ID echoes a caller correlation ID on protocol events.
            Use capabilities for command limits, options, side effects and exit codes.
            Tools resolve only from --tools, AIRU_ENCODER_DIR or bundled Resources/Encoders.
            """)
            return 0
        }
        if args.command == "capabilities" {
            await output.send(Event(type: "capabilities", capabilities: AgentCapabilities())); return 0
        }
        let cache = args.cache.map { CompressionCache(root: $0) } ?? CompressionCache()
        if args.command == "export" {
            guard let key = args.key else { throw AiruError("usage", "export requires --key") }
            let url = try await ExportManager(cache: cache).export(cacheKey: key, to: args.destination ?? ExportManager.defaultDirectory)
            await output.send(Event(type: "exported", destinationURL: url)); return 0
        }
        if args.command == "analyze" {
            guard !args.files.isEmpty else { throw AiruError("usage", "No input files") }
            var failed = false
            for file in args.files {
                try Task.checkCancellation()
                do { await output.send(Event(type: "analysis", sourceURL: file, analysis: try ImageAnalyzer().analyze(file))) }
                catch { failed = true; await output.send(Event(type: "error", sourceURL: file, error: .wrapping(error))) }
            }
            return failed ? 1 : 0
        }
        let tools = try args.tools.map { Toolchain(directory: $0) } ?? Toolchain.bundled()
        if args.command == "doctor" {
            let availability = EncoderTool.allCases.map { tool in
                ToolAvailability(name: tool, executableURL: tools.directory.appendingPathComponent("bin/\(tool.rawValue)"),
                                 executable: (try? tools.executable(tool)) != nil)
            }
            let allExecutable = availability.allSatisfy(\.executable)
            let fingerprint = allExecutable ? try tools.fingerprint() : nil
            let report = ToolchainReport(directoryURL: tools.directory, tools: availability,
                                         allExecutable: allExecutable, fingerprint: fingerprint)
            await output.send(Event(type: "toolchain", error: allExecutable ? nil : AiruError("missingEncoder", "One or more required tools are missing or not executable"),
                                    message: allExecutable ? "All \(availability.count) tools executable; SHA256 \(fingerprint!)" : "Toolchain is incomplete",
                                    toolchain: report))
            return allExecutable ? 0 : 1
        }
        let engine = CompressionEngine(tools: tools, cache: cache)
        if args.command == "batch" {
            guard !args.files.isEmpty else { throw AiruError("usage", "No input files") }
            let processor = BatchProcessor(engine: engine, concurrencyLimit: args.concurrency)
            let updates = await processor.updates()
            let observer = Task {
                for await snapshot in updates where !args.json { await output.send(Event(type: "batchProgress", batch: snapshot)) }
            }
            defer { observer.cancel() }
            for file in args.files { await processor.add(file, options: args.options) }
            let snapshot: BatchSnapshot
            do { snapshot = try await processor.waitUntilFinished() }
            catch {
                await processor.cancelAll()
                // Await cancellation cleanup before the CLI exits.
                _ = try? await Task.detached { try await processor.waitUntilFinished() }.value
                throw error
            }
            if let destination = args.destination {
                for job in snapshot.jobs where job.status == .ready {
                    try Task.checkCancellation()
                    do {
                        let url = try await processor.export(job.id, to: destination)
                        await output.send(Event(type: "exported", sourceURL: job.sourceURL, destinationURL: url))
                    } catch {
                        let error = AiruError.wrapping(error)
                        if error.code == "cancelled" { throw error }
                        await output.send(Event(type: "error", sourceURL: job.sourceURL, error: error))
                    }
                }
            }
            let final = await processor.snapshot()
            await output.send(Event(type: "batchCompleted", batch: final))
            return final.jobs.contains { $0.status == .failed } ? 1 : 0
        }
        guard ["prepare", "optimize"].contains(args.command), args.files.count == 1 else { throw AiruError("usage", "Use prepare/optimize with one file, or batch with multiple files") }
        let source = args.files[0]
        let result = try await engine.prepare(source, options: args.options) { progress in
            if !args.json { await output.send(Event(type: "progress", sourceURL: source, progress: progress)) }
        }
        await output.send(Event(type: "ready", sourceURL: source, result: result))
        if args.command == "optimize" {
            let url = try await ExportManager(cache: cache).export(cacheKey: result.cacheKey, to: args.destination ?? ExportManager.defaultDirectory)
            await output.send(Event(type: "exported", sourceURL: source, destinationURL: url))
        }
        return 0
    }
}
