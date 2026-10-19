import Foundation

public actor BatchProcessor {
    private let engine: CompressionEngine
    private let concurrencyLimit: Int
    private var jobs: [UUID: CompressionJob] = [:]
    private var order: [UUID] = []
    private var pending: [UUID] = []
    private var options: [UUID: OptimizationOptions] = [:]
    private var running: [UUID: Task<Void, Never>] = [:]
    private var exporting: [UUID: Task<URL, any Error>] = [:]
    private var observers: [UUID: AsyncStream<BatchSnapshot>.Continuation] = [:]
    public init(engine: CompressionEngine, concurrencyLimit: Int = 2) {
        self.engine = engine; self.concurrencyLimit = min(8, max(1, concurrencyLimit))
    }
    public func updates() -> AsyncStream<BatchSnapshot> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(128)) { continuation in
            observers[id] = continuation
            continuation.yield(snapshot())
            continuation.onTermination = { @Sendable _ in Task { await self.removeObserver(id) } }
        }
    }
    private func removeObserver(_ id: UUID) { observers[id] = nil }
    public func snapshot() -> BatchSnapshot { BatchSnapshot(jobs: order.compactMap { jobs[$0] }) }
    private func publish() { let value = snapshot(); for observer in observers.values { observer.yield(value) } }
    @discardableResult public func add(_ source: URL, options: OptimizationOptions = .init()) -> UUID {
        let job = CompressionJob(sourceURL: source)
        jobs[job.id] = job; order.append(job.id); pending.append(job.id); self.options[job.id] = options
        publish(); schedule(); return job.id
    }
    public func cancel(_ id: UUID) {
        guard var job = jobs[id], ![.completed, .failed, .cancelled].contains(job.status) else { return }
        pending.removeAll { $0 == id }; running[id]?.cancel()
        exporting[id]?.cancel()
        job.status = .cancelled; job.progress = 1; job.result = nil; jobs[id] = job
        publish()
    }
    public func cancelAll() { for id in order { cancel(id) } }
    public func remove(_ id: UUID) {
        cancel(id); jobs[id] = nil; options[id] = nil; order.removeAll { $0 == id }; publish()
    }
    private func schedule() {
        while running.count < concurrencyLimit, !pending.isEmpty {
            let id = pending.removeFirst()
            guard let job = jobs[id], let options = options[id] else { continue }
            let engine = engine
            running[id] = Task { [weak self] in
                do {
                    let result = try await engine.prepare(job.sourceURL, options: options) { [weak self] update in
                        await self?.update(id, progress: update)
                    }
                    await self?.finish(id, result: .success(result))
                } catch { await self?.finish(id, result: .failure(AiruError.wrapping(error))) }
            }
        }
    }
    private func update(_ id: UUID, progress: ProgressUpdate) {
        guard var job = jobs[id], job.status != .cancelled else { return }
        job.status = progress.status; job.progress = max(job.progress, progress.fraction)
        jobs[id] = job; publish()
    }
    private func finish(_ id: UUID, result: Result<CompressionResult, AiruError>) {
        running[id] = nil
        if var job = jobs[id], job.status != .cancelled {
            job.progress = 1
            switch result {
            case .success(let result):
                job.result = result; job.originalFilename = result.source.originalFilename
                job.originalFormat = result.source.format; job.originalSize = result.source.fileSize
                job.selectedOutputFormat = result.selectedFormat; job.outputSize = result.outputSize
                job.savingsPercentage = result.savingsPercentage; job.perceptualQualityScore = result.perceptualScore; job.status = .ready
            case .failure(let error): job.error = error; job.status = error.code == "cancelled" ? .cancelled : .failed
            }
            jobs[id] = job
        }
        publish(); schedule()
    }
    public func waitUntilFinished() async throws -> BatchSnapshot {
        while !running.isEmpty || !pending.isEmpty || !exporting.isEmpty {
            try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(25))
        }
        return snapshot()
    }
    public func export(_ id: UUID, to directory: URL = ExportManager.defaultDirectory) async throws -> URL {
        guard let result = jobs[id]?.result, jobs[id]?.status == .ready else { throw AiruError("notReady", "Job is not ready for export") }
        jobs[id]?.status = .exporting; publish()
        let cache = engine.cache
        let task = Task { try await ExportManager(cache: cache).export(cacheKey: result.cacheKey, to: directory) }
        exporting[id] = task
        defer { exporting[id] = nil }
        do {
            let url = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            // Removing a job while exporting must not resurrect it.
            if let job = jobs[id], job.status != .cancelled { jobs[id]?.status = .completed; jobs[id]?.destinationURL = url; publish() }
            return url
        } catch {
            if let job = jobs[id], job.status != .cancelled {
                let error = AiruError.wrapping(error)
                jobs[id]?.status = error.code == "cancelled" ? .cancelled : .failed; jobs[id]?.error = error; publish()
            }
            throw error
        }
    }
}
