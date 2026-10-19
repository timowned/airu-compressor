import AppKit
import AiruCore
import Observation
import UniformTypeIdentifiers

public enum ApplicationMode: String, CaseIterable, Sendable { case auto = "Auto", manual = "Manual" }

@MainActor @Observable public final class ImageJobViewModel: Identifiable {
    public let id = UUID()
    public let sourceURL: URL
    public internal(set) var info: ImageInfo?
    public internal(set) var result: CompressionResult?
    public internal(set) var status: ProcessingStatus = .queued
    public internal(set) var progress: Double = 0
    public internal(set) var requestedFormat: OutputFormat
    public internal(set) var exportedURL: URL?
    public internal(set) var error: AiruError?
    public internal(set) var destinationOverride: URL?
    var compressionRequested = false
    var followsDefaultFormat = true
    var generation = UUID()
    let sourceAccess: ScopedURL
    var destinationAccess: ScopedURL?
    init(source: URL, format: OutputFormat) {
        sourceURL = source; requestedFormat = format; sourceAccess = ScopedURL(source)
    }
    public var filename: String { sourceURL.lastPathComponent }
    public var canUseJPEG: Bool { info?.hasAlpha == false }
    public var canExport: Bool { result != nil && [.ready, .completed, .failed].contains(status) }
    public var canCompress: Bool { info != nil && result == nil && [.ready, .failed, .cancelled].contains(status) }
    public var isBusy: Bool { [.queued, .analyzing, .optimizing, .exporting].contains(status) }
    public var outputFormatLabel: String {
        if requestedFormat == .auto { return result.map { "Auto · \($0.selectedFormat.label)" } ?? "Auto" }
        return requestedFormat.label
    }
}

@MainActor @Observable public final class CompressionViewModel {
    public var mode: ApplicationMode = .auto
    public private(set) var jobs: [ImageJobViewModel] = []
    public private(set) var defaultFormat: OutputFormat = .auto
    public var alert: AiruError?
    public let destinations: ExportDestinationManager
    private let service: CompressionService
    private let concurrencyLimit: Int
    private var running: [UUID: (UUID, Task<Void, Never>)] = [:]
    private var exports: [UUID: Task<Void, Never>] = [:]
    private var pendingExports: [UUID] = []
    public init(service: CompressionService = .bundled(), destinations: ExportDestinationManager? = nil, concurrencyLimit: Int = 2) {
        self.service = service; self.destinations = destinations ?? ExportDestinationManager()
        self.concurrencyLimit = max(1, min(4, concurrencyLimit))
    }
    public var isBusy: Bool { jobs.contains { $0.isBusy } }
    public var hasReadyFiles: Bool { jobs.contains { $0.status != .completed && ($0.canCompress || $0.canExport) } }
    public var isCompressing: Bool { jobs.contains { $0.isBusy && ($0.compressionRequested || $0.status == .exporting) } }
    public var allCompleted: Bool { !jobs.isEmpty && jobs.allSatisfy { $0.status == .completed } }
    public var canUseJPEG: Bool { !jobs.isEmpty && jobs.allSatisfy { $0.canUseJPEG } }
    public var batchProgress: Double {
        jobs.isEmpty ? 0 : jobs.reduce(0) { $0 + ($1.status == .completed ? 1 : $1.progress) } / Double(jobs.count)
    }
    public static var importTypes: [UTType] {
        [.jpeg, .png] + [UTType.heic, UTType.webP].filter { type in
            (CGImageSourceCopyTypeIdentifiers() as? [String] ?? []).contains(type.identifier)
        }
    }
    public func importFiles(_ urls: [URL]) {
        var identities = Set(jobs.map { $0.sourceURL.resolvingSymlinksInPath().standardizedFileURL.path })
        for url in urls where url.isFileURL {
            let source = url.standardizedFileURL
            guard identities.insert(source.resolvingSymlinksInPath().path).inserted else { continue }
            jobs.append(ImageJobViewModel(source: source, format: defaultFormat))
        }
        mode = .auto; schedule()
    }
    public func browseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Add images to Airu"; panel.prompt = "Add Images"
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = Self.importTypes
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.importFiles(panel.urls)
        }
    }
    public func remove(_ job: ImageJobViewModel) {
        job.generation = UUID(); running[job.id]?.1.cancel(); exports[job.id]?.cancel()
        pendingExports.removeAll { $0 == job.id }
        jobs.removeAll { $0.id == job.id }
        schedule()
    }
    public func setFormat(_ format: OutputFormat, for job: ImageJobViewModel) {
        guard format != .jpeg || job.canUseJPEG else { return }
        job.followsDefaultFormat = false
        reprepare(job, format: format)
    }
    public func setDefaultFormat(_ format: OutputFormat) {
        guard format != .jpeg || canUseJPEG else { return }
        defaultFormat = format
        for job in jobs where job.followsDefaultFormat { reprepare(job, format: format) }
    }
    private func reprepare(_ job: ImageJobViewModel, format: OutputFormat) {
        guard job.requestedFormat != format || job.status == .failed || job.status == .cancelled else { return }
        running[job.id]?.1.cancel(); exports[job.id]?.cancel()
        pendingExports.removeAll { $0 == job.id }
        job.compressionRequested = false
        job.generation = UUID(); job.requestedFormat = format; job.result = nil; job.error = nil
        job.status = .queued; job.progress = 0; job.exportedURL = nil
        schedule()
    }
    public func retry(_ job: ImageJobViewModel) {
        if job.canExport || job.canCompress { export(job) } else { reprepare(job, format: job.requestedFormat) }
    }
    private func contains(_ job: ImageJobViewModel, generation: UUID) -> Bool {
        jobs.contains { $0.id == job.id } && job.generation == generation
    }
    private func schedule() {
        for job in jobs where job.status == .queued && running[job.id] == nil && exports[job.id] == nil {
            guard running.count < concurrencyLimit else { break }
            let token = job.generation
            let service = service
            let task = Task { [weak self] in
                guard let self else { return }
                defer {
                    if self.running[job.id]?.0 == token { self.running[job.id] = nil }
                    self.schedule()
                }
                guard !Task.isCancelled, self.contains(job, generation: token) else { return }
                do {
                    job.status = .analyzing
                    let info = try await service.analyze(job.sourceURL)
                    try Task.checkCancellation()
                    guard self.contains(job, generation: token) else { return }
                    job.info = info
                    if job.requestedFormat == .jpeg && info.hasAlpha {
                        if job.followsDefaultFormat {
                            job.requestedFormat = .auto; job.followsDefaultFormat = false
                        } else {
                            throw AiruError("transparencyUnsupported", "JPEG cannot preserve this image's transparency. Choose Auto, AVIF, WebP or PNG.")
                        }
                    }
                    // Import and format changes only validate metadata. Encoders run after Airufy.
                    guard job.compressionRequested else {
                        job.status = .ready; job.progress = 0
                        return
                    }
                    job.status = .optimizing
                    let result = try await service.prepare(job.sourceURL, format: job.requestedFormat) { [weak self, weak job] update in
                        await self?.receive(update, job: job, generation: token)
                    }
                    try Task.checkCancellation()
                    guard self.contains(job, generation: token) else { return }
                    job.result = result; job.info = result.source; job.progress = 1; job.status = .ready
                    self.export(job)
                } catch {
                    guard self.contains(job, generation: token) else { return }
                    let error = AiruError.wrapping(error)
                    job.error = error; job.status = error.code == "cancelled" ? .cancelled : .failed
                }
            }
            running[job.id] = (token, task)
        }
    }
    private func receive(_ update: ProgressUpdate, job: ImageJobViewModel?, generation: UUID) {
        guard let job, contains(job, generation: generation) else { return }
        // ready is published only after its matching result is received, never with a stale size.
        if update.status != .ready { job.status = update.status }
        job.progress = max(job.progress, update.fraction)
    }
    public func export(_ job: ImageJobViewModel) {
        guard jobs.contains(where: { $0.id == job.id }), exports[job.id] == nil, !pendingExports.contains(job.id) else { return }
        if job.canCompress {
            job.compressionRequested = true; job.status = .queued; job.progress = 0; job.error = nil
            schedule()
            return
        }
        guard job.canExport else { return }
        job.status = .exporting; job.progress = 0; job.error = nil
        pendingExports.append(job.id)
        scheduleExports()
    }
    private func scheduleExports() {
        while exports.count < concurrencyLimit, !pendingExports.isEmpty {
            let id = pendingExports.removeFirst()
            if let job = jobs.first(where: { $0.id == id }), job.status == .exporting { startExport(job) }
        }
    }
    private func startExport(_ job: ImageJobViewModel) {
        guard let result = job.result else { return }
        let token = job.generation
        job.status = .exporting; job.progress = 0; job.error = nil
        let folder = job.destinationOverride ?? destinations.defaultURL
        let access = ScopedURL(folder)
        let service = service
        exports[job.id] = Task { [weak self] in
            guard let self else { return }
            defer { self.exports[job.id] = nil; self.scheduleExports(); self.schedule(); withExtendedLifetime(access) {} }
            do {
                let destination: URL
                do { destination = try await service.export(result, to: folder) }
                catch let error as AiruError where error.code == "authorizationRequired" {
                    let authorized = try await self.destinations.chooseFolder(startingAt: folder)
                    guard self.contains(job, generation: token) else { return }
                    job.destinationOverride = authorized; job.destinationAccess = ScopedURL(authorized)
                    destination = try await service.export(result, to: authorized)
                }
                try Task.checkCancellation()
                guard self.contains(job, generation: token) else { return }
                job.exportedURL = destination; job.status = .completed; job.progress = 1
            } catch {
                guard self.contains(job, generation: token) else { return }
                let error = AiruError.wrapping(error)
                if error.code == "userCancelled" { job.status = .ready; return }
                if ["cacheInvalid", "sourceChanged"].contains(error.code) { job.result = nil }
                job.error = error; job.status = error.code == "cancelled" ? .cancelled : .failed; job.progress = 1
            }
        }
    }
    public func exportAll() {
        if allCompleted { revealExports(); return }
        for job in jobs where job.status != .completed && (job.canCompress || job.canExport) { export(job) }
    }
    public func chooseDestination(for job: ImageJobViewModel? = nil) async {
        do {
            let url = try await destinations.chooseFolder(startingAt: job?.destinationOverride)
            if let job {
                guard jobs.contains(where: { $0.id == job.id }) else { return }
                job.destinationOverride = url; job.destinationAccess = ScopedURL(url)
            } else { try destinations.setDefault(url) }
        } catch let error as AiruError where error.code == "userCancelled" {}
        catch { alert = AiruError.wrapping(error) }
    }
    public func reveal(_ job: ImageJobViewModel) {
        if let url = job.exportedURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
    public func revealExports() {
        let urls = jobs.compactMap(\.exportedURL)
        if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
    }
    public func waitUntilIdle() async throws {
        while !running.isEmpty || !exports.isEmpty || !pendingExports.isEmpty { try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(25)) }
    }
    public func cancelAll() {
        // Prevent completion cleanup from scheduling queued work during shutdown.
        for job in jobs where job.status == .queued { job.status = .cancelled }
        for task in running.values { task.1.cancel() }
        for task in exports.values { task.cancel() }
        for id in pendingExports { jobs.first(where: { $0.id == id })?.status = .cancelled }
        pendingExports.removeAll()
    }
}

import ImageIO
extension OutputFormat {
    public var label: String {
        switch self { case .auto: "Auto"; case .avif: "AVIF"; case .webp: "WebP"; case .jpeg: "JPEG"; case .png: "PNG" }
    }
}
extension ImageFormat {
    public var label: String { self == .jpeg ? "JPEG" : (self == .webp ? "WebP" : rawValue.uppercased()) }
}
