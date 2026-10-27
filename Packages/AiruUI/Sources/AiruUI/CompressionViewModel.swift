import AppKit
import AiruCore
import Observation
import UniformTypeIdentifiers

public enum CompressionProfile: String, CaseIterable, Codable, Sendable {
    case airy = "Airy", superlight = "Superlight"
    public var minimumScore: Double { self == .airy ? 90 : 80 }
}

public enum ApplicationMode: String, CaseIterable, Sendable { case compress = "Compress", upscale = "Upscale" }

@MainActor @Observable public final class ImageJobViewModel: Identifiable {
    public let id = UUID()
    public let sourceURL: URL
    let importedFileSize: Int64?
    public internal(set) var info: ImageInfo?
    public internal(set) var result: CompressionResult?
    public internal(set) var status: ProcessingStatus = .queued
    public internal(set) var progress: Double = 0
    public internal(set) var requestedProfile: CompressionProfile
    public internal(set) var requestedFormat: OutputFormat
    public internal(set) var exportedURL: URL?
    public internal(set) var error: AiruError?
    public internal(set) var destinationOverride: URL?
    var requestedUpscale: Int?
    var requestedResize: ResizeOptions?
    var compressionRequested = false
    var followsDefaultFormat = true
    var generation = UUID()
    var resetRevision = 0
    let sourceAccess: ScopedURL
    var destinationAccess: ScopedURL?
    init(source: URL, format: OutputFormat, profile: CompressionProfile = .airy) {
        requestedProfile = profile
        importedFileSize = (try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        sourceURL = source; requestedFormat = format; sourceAccess = ScopedURL(source)
    }
    public var filename: String { sourceURL.lastPathComponent }
    public var revealURL: URL { exportedURL ?? sourceURL }
    public var progressPercentage: Int {
        guard progress.isFinite else { return 0 }
        // Only a received, verified result can finish compression.
        return min(result == nil ? 99 : 100, max(0, Int((min(1, max(0, progress)) * 100).rounded(.down))))
    }
    public var canUseJPEG: Bool { info?.hasTransparency == false }
    public var canExport: Bool { result != nil && [.ready, .completed, .failed, .cancelled].contains(status) }
    public var canReset: Bool { result != nil && !isBusy }
    public var canCompress: Bool { info != nil && result == nil && [.ready, .failed, .cancelled].contains(status) }
    public var isBusy: Bool { [.queued, .analyzing, .optimizing, .exporting].contains(status) }
    public var outputFormatLabel: String {
        if requestedFormat == .auto { return result.map { "Auto · \($0.selectedFormat.label)" } ?? "Auto" }
        return requestedFormat.label
    }
}

@MainActor @Observable public final class CompressionViewModel {
    public var mode: ApplicationMode = .compress
    public let workflow: ApplicationMode
    public private(set) var upscaleFactor = 2
    public private(set) var compressionUpscaleFactor: Int?
    private var upscaleWorkspace: CompressionViewModel?
    public var activeWorkspace: CompressionViewModel {
        guard workflow == .compress && mode == .upscale else { return self }
        if let upscaleWorkspace { return upscaleWorkspace }
        let workspace = CompressionViewModel(service: service, destinations: destinations, concurrencyLimit: 1, workflow: .upscale)
        upscaleWorkspace = workspace
        return workspace
    }
    public private(set) var jobs: [ImageJobViewModel] = []
    public private(set) var isPresentingImportAnalysis = false
    private var importAnalysisTask: Task<Void, Never>?
    public private(set) var defaultProfile: CompressionProfile = .airy
    public private(set) var defaultFormat: OutputFormat = .auto
    public private(set) var defaultResize: ResizeOptions?
    public var alert: AiruError?
    public let destinations: ExportDestinationManager
    private let service: CompressionService
    private let concurrencyLimit: Int
    private var running: [UUID: (UUID, Task<Void, Never>)] = [:]
    private var exports: [UUID: Task<Void, Never>] = [:]
    private var pendingExports: [UUID] = []
    public init(service: CompressionService = .bundled(), destinations: ExportDestinationManager? = nil, concurrencyLimit: Int = 2, workflow: ApplicationMode = .compress) {
        self.workflow = workflow; mode = workflow
        if workflow == .upscale { defaultFormat = .png }
        self.service = service; self.destinations = destinations ?? ExportDestinationManager()
        self.concurrencyLimit = max(1, min(4, concurrencyLimit))
    }
    public var isBusy: Bool { jobs.contains { $0.isBusy } }
    public var hasReadyFiles: Bool { jobs.contains { $0.status != .completed && ($0.canCompress || $0.canExport) } }
    public var isCompressing: Bool { jobs.contains { $0.isBusy && ($0.compressionRequested || $0.status == .exporting) } }
    public var canResetAll: Bool { !isCompressing && jobs.contains { $0.canReset } }
    public var allCompleted: Bool { !jobs.isEmpty && jobs.allSatisfy { $0.status == .completed } }
    public var canUseJPEG: Bool {
        let pending = jobs.filter { $0.status != .completed }
        return !pending.isEmpty && pending.allSatisfy { $0.canUseJPEG }
    }
    public var batchProgress: Double {
        jobs.isEmpty ? 0 : jobs.reduce(0) { $0 + ($1.status == .completed ? 1 : $1.progress) } / Double(jobs.count)
    }
    public static var importTypes: [UTType] {
        [.jpeg, .png] + [UTType.heic, UTType.webP].filter { type in
            (CGImageSourceCopyTypeIdentifiers() as? [String] ?? []).contains(type.identifier)
        }
    }
    public func importFiles(_ urls: [URL], showAnalysisScreen: Bool = false) {
        if activeWorkspace !== self { activeWorkspace.importFiles(urls, showAnalysisScreen: showAnalysisScreen); return }
        var identities = Set(jobs.map { $0.sourceURL.resolvingSymlinksInPath().standardizedFileURL.path })
        var imported: [ImageJobViewModel] = []
        for url in urls where url.isFileURL {
            let source = url.standardizedFileURL
            guard identities.insert(source.resolvingSymlinksInPath().path).inserted else { continue }
            let job = ImageJobViewModel(source: source, format: defaultFormat, profile: defaultProfile)
            job.requestedResize = defaultResize
            job.requestedUpscale = workflow == .upscale ? upscaleFactor : compressionUpscaleFactor
            imported.append(job)
        }
        jobs.insert(contentsOf: imported, at: 0)
        if showAnalysisScreen && !imported.isEmpty { presentImportAnalysis(for: Set(imported.map(\.id))) }
        schedule()
    }
    private func presentImportAnalysis(for ids: Set<UUID>) {
        importAnalysisTask?.cancel()
        isPresentingImportAnalysis = true
        importAnalysisTask = Task { [weak self] in
            do {
                // Real metadata analysis runs concurrently; this only holds its presentation.
                try await Task.sleep(for: .seconds(3))
                guard let self else { return }
                while self.jobs.contains(where: { ids.contains($0.id) && [.queued, .analyzing].contains($0.status) }) {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(25))
                }
                try Task.checkCancellation()
                self.isPresentingImportAnalysis = false
                self.importAnalysisTask = nil
            } catch { /* A later drop or shutdown owns presentation cleanup. */ }
        }
    }
    public func browseFiles() {
        if activeWorkspace !== self { activeWorkspace.browseFiles(); return }
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
    public func reset(_ job: ImageJobViewModel) {
        guard jobs.contains(where: { $0.id == job.id }), job.canReset else { return }
        job.generation = UUID()
        job.resetRevision += 1
        job.result = nil; job.exportedURL = nil; job.error = nil; job.info = nil
        job.progress = 0; job.compressionRequested = false
        job.requestedFormat = defaultFormat; job.requestedProfile = defaultProfile
        job.followsDefaultFormat = true
        job.requestedResize = defaultResize
        job.requestedUpscale = workflow == .upscale ? upscaleFactor : compressionUpscaleFactor
        job.status = .queued
        // Revalidate the original; compression still waits for another Airufy click.
        schedule()
    }
    public func resetAll() {
        guard canResetAll else { return }
        for job in jobs where job.canReset { reset(job) }
    }
    public func setUpscaleFactor(_ factor: Int) {
        guard [2, 4].contains(factor), !isCompressing else { return }
        let selected: Int?
        if workflow == .upscale {
            guard upscaleFactor != factor else { return }
            upscaleFactor = factor
            selected = factor
        } else {
            compressionUpscaleFactor = compressionUpscaleFactor == factor ? nil : factor
            selected = compressionUpscaleFactor
            if selected != nil { defaultResize = nil }
        }
        for job in jobs where job.status != .completed {
            reprepare(job, format: job.requestedFormat, resize: selected != nil ? .some(nil) : nil, upscale: .some(selected))
        }
    }
    public func setDefaultResize(_ resize: ResizeOptions?) {
        do {
            try resize?.validate()
            for job in jobs where job.status != .completed {
                if let info = job.info { _ = try resize?.dimensions(width: info.width, height: info.height) }
            }
            if resize != nil { compressionUpscaleFactor = nil }
            defaultResize = resize
            for job in jobs where job.status != .completed {
                reprepare(job, format: job.requestedFormat, resize: .some(resize), upscale: resize != nil ? .some(nil) : nil)
            }
        } catch { alert = AiruError.wrapping(error) }
    }
    public func setDefaultFormat(_ format: OutputFormat) {
        guard format != .jpeg || canUseJPEG else { return }
        defaultFormat = format
        for job in jobs where job.followsDefaultFormat && job.status != .completed { reprepare(job, format: format) }
    }
    public func setDefaultProfile(_ profile: CompressionProfile) {
        defaultProfile = profile
        for job in jobs where job.status != .completed {
            reprepare(job, format: job.requestedFormat, profile: profile)
        }
    }
    private func reprepare(_ job: ImageJobViewModel, format: OutputFormat, profile: CompressionProfile? = nil, resize: ResizeOptions?? = nil, upscale: Int?? = nil) {
        let upscale = upscale ?? job.requestedUpscale
        let resize = resize ?? job.requestedResize
        let profile = profile ?? job.requestedProfile
        guard job.requestedUpscale != upscale || job.requestedResize != resize || job.requestedProfile != profile || job.requestedFormat != format || job.status == .failed || job.status == .cancelled else { return }
        running[job.id]?.1.cancel(); exports[job.id]?.cancel()
        pendingExports.removeAll { $0 == job.id }
        job.requestedProfile = profile
        job.requestedResize = resize
        job.requestedUpscale = upscale
        job.compressionRequested = false
        job.generation = UUID(); job.requestedFormat = format; job.result = nil; job.error = nil
        // Changing options does not invalidate metadata already read from the original.
        job.status = job.info == nil ? .queued : .ready
        job.progress = 0; job.exportedURL = nil
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
                    if job.requestedFormat == .jpeg && info.hasTransparency {
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
                    let result = try await service.prepare(job.sourceURL, format: job.requestedFormat, minimumScore: job.requestedProfile.minimumScore,
                                                           pngMode: job.requestedProfile == .superlight ? .superlight : .airy, resize: job.requestedResize, upscale: job.requestedUpscale) { [weak self, weak job] update in
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
        if update.fraction.isFinite { job.progress = max(job.progress, min(1, max(0, update.fraction))) }
    }
    public func export(_ job: ImageJobViewModel) {
        guard jobs.contains(where: { $0.id == job.id }), exports[job.id] == nil, !pendingExports.contains(job.id) else { return }
        if job.canCompress {
            job.compressionRequested = true; job.status = .queued; job.progress = 0; job.error = nil
            schedule()
            return
        }
        guard job.canExport else { return }
        job.status = .exporting; job.progress = 1; job.error = nil
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
        job.status = .exporting; job.progress = 1; job.error = nil
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
                job.error = error; job.status = error.code == "cancelled" ? .cancelled : .failed
            }
        }
    }
    public func exportAll() {
        if activeWorkspace !== self { activeWorkspace.exportAll(); return }
        if allCompleted { revealExports(); return }
        for job in jobs where job.status != .completed && (job.canCompress || job.canExport) { export(job) }
    }
    public func chooseDestination(for job: ImageJobViewModel? = nil) async {
        if activeWorkspace !== self { await activeWorkspace.chooseDestination(for: job); return }
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
        NSWorkspace.shared.activateFileViewerSelecting([job.revealURL])
    }
    public func revealExports() {
        let urls = jobs.compactMap(\.exportedURL)
        if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
    }
    public func waitUntilIdle() async throws {
        if let upscaleWorkspace { try await upscaleWorkspace.waitUntilIdle() }
        while !running.isEmpty || !exports.isEmpty || !pendingExports.isEmpty || importAnalysisTask != nil { try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(25)) }
    }
    public func cancelAll() {
        upscaleWorkspace?.cancelAll()
        stopWorkspace()
    }
    public func stopWorkspace() {
        importAnalysisTask?.cancel(); importAnalysisTask = nil; isPresentingImportAnalysis = false
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
