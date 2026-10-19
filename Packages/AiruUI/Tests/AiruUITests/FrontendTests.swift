import Foundation
import Testing
import AiruCore
@testable import AiruUI

@MainActor private struct Context {
    let root: URL
    let project: URL
    let service: CompressionService
    let model: CompressionViewModel
    let preferences: UserDefaults
    let suite: String
    init() throws {
        var project = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { project.deleteLastPathComponent() }
        self.project = project
        root = FileManager.default.temporaryDirectory.appendingPathComponent("airu-ui-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        suite = "Airu.test.\(UUID())"; preferences = UserDefaults(suiteName: suite)!
        service = CompressionService(executable: project.appendingPathComponent(".build/debug/airu"),
            tools: project.appendingPathComponent("Resources/Encoders"), cache: root.appendingPathComponent("cache"))
        model = CompressionViewModel(service: service, destinations: ExportDestinationManager(preferences: preferences,
            initialURL: root.appendingPathComponent("Exports")))
    }
    func fixture(_ name: String) -> URL { project.appendingPathComponent("Packages/AiruCore/Tests/AiruCoreTests/Fixtures/\(name)") }
    func cleanup() {
        model.cancelAll(); preferences.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
    func copy(_ name: String, to destination: String) throws -> URL {
        let url = root.appendingPathComponent(destination)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixture(name), to: url)
        return url
    }
}

@MainActor @Suite(.serialized) struct FrontendTests {
    @Test func importAndFormatSelectionDoNotCompress() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")])
        try await c.model.waitUntilIdle()
        let job = try #require(c.model.jobs.first)
        #expect(job.info != nil); #expect(job.status == .ready)
        #expect(job.result == nil); #expect(job.exportedURL == nil)
        #expect(job.progress == 0); #expect(c.model.batchProgress == 0)
        #expect(c.model.hasReadyFiles); #expect(!c.model.isCompressing)
        c.model.setDefaultFormat(.webp)
        c.model.setFormat(.png, for: job)
        try await c.model.waitUntilIdle()
        #expect(job.requestedFormat == .png); #expect(job.result == nil)
        #expect(!FileManager.default.fileExists(atPath: c.root.appendingPathComponent("cache").path))
        #expect(!FileManager.default.fileExists(atPath: c.model.destinations.defaultURL.path))
    }
    @Test func airufyCompressesQualityChecksAndExportsJPEG() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0]
        let result = try #require(job.result)
        #expect(job.status == .completed); #expect(c.model.allCompleted)
        #expect(result.perceptualScore! >= 90); #expect(result.outputSize < result.source.fileSize)
        let url = try #require(job.exportedURL)
        #expect(url.lastPathComponent == "photo-comp.avif")
        #expect(try ImageAnalyzer().analyze(url).fileSize == result.outputSize)
    }
    @Test func multipleFilesAndIndependentFormat() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg"), c.fixture("oriented.jpg"), c.fixture("photo.png")])
        c.model.setFormat(.webp, for: c.model.jobs[1])
        try await c.model.waitUntilIdle()
        #expect(c.model.jobs.allSatisfy { $0.result == nil })
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(c.model.allCompleted)
        #expect(c.model.jobs[0].result?.options.format == .auto)
        #expect(c.model.jobs[1].result?.selectedFormat == .webp)
        #expect(c.model.jobs[1].info?.width == 368 && c.model.jobs[1].info?.height == 550)
        #expect(c.model.jobs[2].result?.options.format == .auto)
    }
    @Test func transparentImageExcludesJPEG() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("transparent.png")]); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0]
        #expect(job.info?.hasAlpha == true); #expect(!job.canUseJPEG)
        c.model.setFormat(.jpeg, for: job); #expect(job.requestedFormat == .auto)
        c.model.setFormat(.webp, for: job); try await c.model.waitUntilIdle()
        #expect(job.result == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let result = try #require(job.result)
        #expect(result.selectedFormat == .webp)
        #expect(try ImageAnalyzer().analyze(try #require(job.exportedURL)).hasAlpha)
        #expect(result.perceptualScore! >= 90)
    }
    @Test func removalCancelsRunningAndQueuedWork() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.png"), c.fixture("photo.jpg"), c.fixture("oriented.jpg")])
        try await c.model.waitUntilIdle(); c.model.exportAll()
        try await Task.sleep(for: .milliseconds(70))
        for job in c.model.jobs { c.model.remove(job) }
        try await c.model.waitUntilIdle()
        #expect(c.model.jobs.isEmpty)
    }
    @Test func cancellationDoesNotStartQueuedJobs() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.png"), c.fixture("photo.jpg"), c.fixture("oriented.jpg")])
        try await c.model.waitUntilIdle(); c.model.exportAll()
        try await Task.sleep(for: .milliseconds(70)); c.model.cancelAll()
        try await c.model.waitUntilIdle()
        #expect(c.model.jobs.allSatisfy { $0.status == .cancelled })
        #expect(c.model.jobs.allSatisfy { $0.result == nil })
    }
    @Test func customDestinationUnicodeAndDuplicateImports() async throws {
        let c = try Context(); defer { c.cleanup() }
        let source = try c.copy("photo.jpg", to: "Дом photo.final.jpeg")
        c.model.importFiles([source, source, source]); try await c.model.waitUntilIdle()
        #expect(c.model.jobs.count == 1)
        let job = c.model.jobs[0], folder = c.root.appendingPathComponent("Custom folder")
        job.destinationOverride = folder
        c.model.export(job); try await c.model.waitUntilIdle()
        #expect(job.status == .completed)
        #expect(job.exportedURL?.deletingLastPathComponent().resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path)
        #expect(job.exportedURL?.lastPathComponent == "Дом photo.final-comp.avif")
        #expect(FileManager.default.fileExists(atPath: source.path))
    }
    @Test func alreadyOptimizedNeverShowsInventedScore() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("tiny.png")]); try await c.model.waitUntilIdle()
        #expect(c.model.jobs[0].result == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let result = try #require(c.model.jobs[0].result)
        #expect(result.alreadyOptimized); #expect(result.perceptualScore == nil)
        #expect(result.outputSize == result.source.fileSize); #expect(c.model.allCompleted)
    }
    @Test func formatChangesWaitForAirufyAndReuseCache() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0]
        c.model.setFormat(.webp, for: job); c.model.setFormat(.png, for: job)
        try await c.model.waitUntilIdle(); c.model.exportAll(); try await c.model.waitUntilIdle()
        let first = try #require(job.result)
        #expect(first.selectedFormat == .png)
        let modified = try first.cachedFileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        c.model.setFormat(.avif, for: job); c.model.setFormat(.png, for: job)
        try await c.model.waitUntilIdle()
        #expect(job.result == nil); #expect(job.exportedURL == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(job.result?.cacheKey == first.cacheKey)
        #expect(try first.cachedFileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == modified)
    }
    @Test func individualErrorsDoNotStopOtherRows() async throws {
        let c = try Context(); defer { c.cleanup() }
        let bad = c.root.appendingPathComponent("broken.jpg")
        try Data("not an image".utf8).write(to: bad)
        c.model.importFiles([bad, c.fixture("tiny.png")]); try await c.model.waitUntilIdle()
        #expect(c.model.jobs[0].status == .failed)
        #expect(c.model.jobs[0].error?.code == "unsupportedImage")
        #expect(c.model.jobs[1].result == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(c.model.jobs[1].status == .completed)
        #expect(!c.model.hasReadyFiles)
    }
    @Test func missingCLIIsExplicit() async throws {
        let c = try Context(); defer { c.cleanup() }
        do {
            _ = try await CompressionService(executable: c.root.appendingPathComponent("missing")).analyze(c.fixture("photo.jpg"))
            Issue.record("Missing CLI must fail")
        } catch let error as AiruError { #expect(error.code == "missingCLI") }
    }
    @Test func batchExportUsesUniqueNames() async throws {
        let c = try Context(); defer { c.cleanup() }
        let sources = try ["a", "b", "c"].map { try c.copy("photo.jpg", to: "\($0)/photo.jpg") }
        c.model.setDefaultFormat(.png); c.model.importFiles(sources); try await c.model.waitUntilIdle()
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(c.model.allCompleted)
        #expect(Set(c.model.jobs.compactMap { $0.exportedURL?.lastPathComponent }).count == 3)
        #expect(c.model.jobs.allSatisfy { $0.exportedURL?.pathExtension == "png" })
    }
    @Test func sourceMutationBeforeAirufyUsesCurrentContents() async throws {
        let c = try Context(); defer { c.cleanup() }
        let source = try c.copy("photo.png", to: "source.png")
        c.model.setDefaultFormat(.png); c.model.importFiles([source]); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0], oldSize = try #require(job.info?.fileSize)
        let handle = try FileHandle(forWritingTo: source); try handle.seekToEnd()
        try handle.write(contentsOf: Data([0])); try handle.close()
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(job.status == .completed)
        #expect(job.result?.source.fileSize == oldSize + 1)
    }
    @Test func addingFilesDuringCompressionWaitsForAnotherClick() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        c.model.exportAll()
        c.model.importFiles([c.fixture("tiny.png")])
        try await c.model.waitUntilIdle()
        #expect(c.model.jobs[0].status == .completed)
        let added = c.model.jobs[1]
        #expect(added.status == .ready); #expect(added.result == nil); #expect(added.exportedURL == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(c.model.allCompleted)
    }
    @Test func changingFormatCancelsCompressionAndWaitsForAnotherClick() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0]
        c.model.exportAll()
        try await Task.sleep(for: .milliseconds(70))
        c.model.setFormat(.png, for: job)
        try await c.model.waitUntilIdle()
        #expect(job.status == .ready); #expect(job.result == nil); #expect(job.exportedURL == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(job.status == .completed); #expect(job.result?.selectedFormat == .png)
    }
    @Test func destinationBookmarkRoundTrip() throws {
        let c = try Context(); defer { c.cleanup() }
        let directory = c.root.appendingPathComponent("Saved destination")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try c.model.destinations.setDefault(directory)
        let restored = ExportDestinationManager(preferences: c.preferences)
        #expect(restored.defaultURL.resolvingSymlinksInPath().path == directory.resolvingSymlinksInPath().path)
    }
}
