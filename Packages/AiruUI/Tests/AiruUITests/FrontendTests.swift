import Foundation
import Testing
import AiruCore
import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
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
    @Test func compressionUpscaleControlsToggleAndExcludeResize() async throws {
        let c = try Context(); defer { c.cleanup() }
        #expect(ApplicationMode.allCases == [.compress, .upscale])
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        let job = try #require(c.model.jobs.first)
        #expect(job.requestedUpscale == nil)
        c.model.setUpscaleFactor(2)
        #expect(c.model.compressionUpscaleFactor == 2 && job.requestedUpscale == 2)
        #expect(job.result == nil && !job.compressionRequested)
        c.model.setUpscaleFactor(2)
        #expect(job.requestedUpscale == nil)
        c.model.setUpscaleFactor(4)
        c.model.setDefaultResize(.resolution(width: 100, height: 100))
        #expect(c.model.compressionUpscaleFactor == nil && job.requestedUpscale == nil)
        c.model.setUpscaleFactor(2)
        #expect(c.model.defaultResize == nil && job.requestedResize == nil)
        try await c.model.waitUntilIdle()
    }
    @Test func upscaleWorkspaceIsIndependentAndExportsRealEnhancement() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        let compressJob = try #require(c.model.jobs.first)
        #expect(c.model.mode == .compress)
        c.model.mode = .upscale
        let workspace = c.model.activeWorkspace
        #expect(workspace !== c.model && workspace.workflow == .upscale && workspace.defaultFormat == .png)
        let input = try #require(CGImageSourceCreateWithURL(c.fixture("photo.png") as CFURL, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(input, 0, nil))
        let small = try ImageResizer.resize(decoded, options: .resolution(width: 24, height: 32))
        let source = c.root.appendingPathComponent("Small photo.png")
        let dest = try #require(CGImageDestinationCreateWithURL(source as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, small, nil); #expect(CGImageDestinationFinalize(dest))
        c.model.importFiles([source]); try await c.model.waitUntilIdle()
        #expect(workspace.jobs.count == 1 && c.model.jobs.count == 1)
        #expect(workspace.jobs[0].requestedUpscale == 2)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let job = workspace.jobs[0]
        #expect(job.status == .completed && job.result?.options.upscale == 2)
        let url = try #require(job.exportedURL)
        let info = try ImageAnalyzer().analyze(url)
        #expect(info.width == 48 && info.height == 64)
        #expect(url.lastPathComponent == "Small photo-upscaled-2x.png")
        #expect(compressJob.result == nil && compressJob.status == .ready)
        if ProcessInfo.processInfo.environment["AIRU_RENDER_UI"] == "1" {
            let host = NSHostingView(rootView: MainWindow(model: c.model).ignoresSafeArea())
            host.safeAreaRegions = []
            host.frame = NSRect(x: 0, y: 0, width: 640, height: 430)
            let window = NSWindow(contentRect: host.frame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host
            defer { window.close() }
            host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(100))
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: "/tmp/airu-upscale-workspace.png"))
        }
        workspace.setUpscaleFactor(4)
        #expect(job.result?.options.upscale == 2)
        workspace.resetAll(); try await workspace.waitUntilIdle()
        #expect(job.requestedUpscale == 4 && job.result == nil)
        c.model.mode = .compress
        #expect(c.model.activeWorkspace === c.model && c.model.jobs[0].id == compressJob.id)
        c.model.mode = .upscale
        #expect(c.model.activeWorkspace === workspace && workspace.jobs[0].id == job.id)
    }
    @Test func trafficLightsKeepWindowCornerInsetsAcrossContentAndActivation() async throws {
        let c = try Context(); defer { c.cleanup() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        let host = NSHostingView(rootView: MainWindow(model: c.model).ignoresSafeArea())
        host.safeAreaRegions = []
        window.contentView = host
        defer { window.close() }
        for (index, size) in [NSSize(width: 640, height: 430), NSSize(width: 900, height: 600), NSSize(width: 640, height: 430)].enumerated() {
            if index == 1 { c.model.importFiles([c.fixture("photo.png")]); try await c.model.waitUntilIdle() }
            window.setContentSize(size)
            host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
            // Force the native titlebar to take its buttons back, as AppKit can do on activation.
            if index == 2, let button = window.standardWindowButton(.closeButton),
               let nativeTitlebar = window.contentView?.superview?.subviews.first(where: { $0 !== host }) {
                button.removeFromSuperview(); nativeTitlebar.addSubview(button)
            }
            NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.post(name: NSWindow.didUpdateNotification, object: window)
            try await Task.sleep(for: .milliseconds(60))
            for (buttonIndex, kind) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
                let button = try #require(window.standardWindowButton(kind))
                let frame = host.convert(button.bounds, from: button)
                #expect(abs(frame.minX - (22 + CGFloat(buttonIndex) * 23)) < 0.5)
                #expect(abs((host.isFlipped ? frame.minY : host.bounds.maxY - frame.maxY) - 22) < 0.5)
            }
        }
    }
    @Test func trafficLightsStayAnchoredAfterNativeResizePass() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let container = TrafficLightContainer(frame: NSRect(x: 22, y: 394, width: 60, height: 14))
        try #require(window.contentView).addSubview(container)
        let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for size in [NSSize(width: 900, height: 600), NSSize(width: 640, height: 430)] {
            window.setContentSize(size)
            container.layoutSubtreeIfNeeded()
            // AppKit may adjust these frames after the container's layout completed.
            for kind in kinds {
                let button = try #require(window.standardWindowButton(kind))
                button.setFrameOrigin(NSPoint(x: button.frame.minX + 8, y: 8))
            }
            try await Task.sleep(for: .milliseconds(30))
            for (index, kind) in kinds.enumerated() {
                let button = try #require(window.standardWindowButton(kind))
                #expect(button.superview === container)
                #expect(button.frame == NSRect(x: CGFloat(index) * 23, y: 0, width: 14, height: 14))
                #expect(button.target != nil && button.action != nil)
            }
        }
    }

    @Test func thumbnailsAreSmallOrientedCachedAndInvalidateWithContent() async throws {
        let c = try Context(); defer { c.cleanup() }
        let source = try c.copy("photo.jpg", to: "preview image.jpg")
        let firstInfo = try ImageAnalyzer().analyze(source)
        let first = try #require(await ImageThumbnailLoader.shared.image(at: source, contentIdentity: firstInfo.contentSHA256))
        #expect(max(first.width, first.height) <= 88)
        #expect(first.width > first.height)
        let cached = try #require(await ImageThumbnailLoader.shared.image(at: source, contentIdentity: firstInfo.contentSHA256))
        #expect(first === cached)
        try Data(contentsOf: c.fixture("oriented.jpg")).write(to: source)
        let changed = try ImageAnalyzer().analyze(source)
        let rotated = try #require(await ImageThumbnailLoader.shared.image(at: source, contentIdentity: changed.contentSHA256))
        #expect(rotated.height > rotated.width)
        #expect(max(rotated.width, rotated.height) <= 88)
        let broken = c.root.appendingPathComponent("broken.png")
        try Data("broken".utf8).write(to: broken)
        #expect(await ImageThumbnailLoader.shared.image(at: broken, contentIdentity: "broken") == nil)
    }

    @Test func cancellingCLIWaitsForPipeReaderCleanup() async throws {
        let c = try Context(); defer { c.cleanup() }
        for _ in 0..<4 {
            let (updates, continuation) = AsyncStream<Void>.makeStream()
            let service = c.service, source = c.fixture("photo.png")
            let task = Task {
                defer { continuation.finish() }
                return try await service.prepare(source, format: .png, minimumScore: 80, pngMode: .superlight) { _ in
                    continuation.yield(())
                }
            }
            var iterator = updates.makeAsyncIterator()
            #expect(await iterator.next() != nil)
            task.cancel()
            do {
                _ = try await task.value
                Issue.record("Cancelled CLI should not return a prepared result")
            } catch is CancellationError { }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["AIRU_RENDER_UI"] == "1", "Optional resize controls render"))
    func renderResizeControls() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.png")]); try await c.model.waitUntilIdle()
        c.model.setDefaultResize(.resolution(width: 200, height: 200, alignment: .bottomRight))
        let state = FormatMenuState(value: .jpeg, profile: .airy, jpegAllowed: true, select: { _ in }, selectProfile: { _ in })
        state.resizeModel = c.model
        let host = NSHostingView(rootView: FormatMenuContent(state: state, dismiss: {}))
        host.frame = NSRect(x: 0, y: 0, width: FormatMenuContent.resizePanelWidth, height: 230)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: "/tmp/airu-resize-native.png"))
    }
    @Test func singleResolutionEntryPreservesCurrentRatio() throws {
        var draft = ResolutionDraft(baseWidth: 3000, baseHeight: 2000)
        draft.width = "1500"
        var target = try draft.dimensions()
        #expect(target.width == 1500 && target.height == 1000)
        draft.width = ""; draft.height = "1200"
        target = try draft.dimensions()
        #expect(target.width == 1800 && target.height == 1200)
        draft.width = "1200"
        target = try draft.dimensions()
        #expect(target.width == 1200 && target.height == 1200)
        _ = try draft.commitDimensions()
        draft.height = ""
        target = try draft.dimensions()
        #expect(target.width == 1200 && target.height == 1200)
        draft = ResolutionDraft(baseWidth: 3000, baseHeight: 2000)
        draft.width = ""; draft.height = ""
        target = try draft.dimensions()
        #expect(target.width == 3000 && target.height == 2000)
        var custom = ResolutionDraft(baseWidth: 1000, baseHeight: 1000)
        custom.height = "750"
        target = try custom.dimensions()
        #expect(target.width == 750 && target.height == 750)
        custom.width = "0"
        #expect(throws: AiruError.self) { try custom.dimensions() }
        custom.width = "oops"
        #expect(throws: AiruError.self) { try custom.dimensions() }
    }
    @Test func resizeSettingsUseOriginalsAndInvalidatePreparedResults() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.setDefaultFormat(.png)
        c.model.importFiles([c.fixture("photo.png"), c.fixture("oriented.jpg")])
        try await c.model.waitUntilIdle()
        c.model.setDefaultResize(.scale(50))
        #expect(c.model.jobs.allSatisfy { $0.requestedResize == .scale(50) && $0.result == nil })
        c.model.exportAll(); try await c.model.waitUntilIdle()
        for job in c.model.jobs {
            let original = try #require(job.info)
            let result = try #require(job.result)
            let output = try ImageAnalyzer().analyze(result.cachedFileURL)
            let expected = try ResizeOptions.scale(50).dimensions(width: original.width, height: original.height)
            #expect(output.width == expected.width && output.height == expected.height)
        }
        let first = c.model.jobs[0], completed = c.model.jobs[1]
        let firstKey = first.result?.cacheKey, completedKey = completed.result?.cacheKey
        c.model.reset(first); try await c.model.waitUntilIdle()
        c.model.setDefaultResize(.resolution(width: 80, height: 120))
        #expect(first.result == nil && first.requestedResize == .resolution(width: 80, height: 120))
        #expect(completed.result?.cacheKey == completedKey)
        c.model.setDefaultResize(c.model.defaultResize?.aligned(.bottomRight))
        #expect(first.requestedResize?.alignment == .bottomRight)
        #expect(completed.result?.cacheKey == completedKey)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let resized = try #require(first.result)
        #expect(resized.cacheKey != firstKey)
        let exact = try ImageAnalyzer().analyze(resized.cachedFileURL)
        #expect(exact.width == 80 && exact.height == 120)
        c.model.reset(first); try await c.model.waitUntilIdle()
        c.model.setDefaultResize(nil)
        #expect(first.requestedResize == nil && first.result == nil)
        c.model.setDefaultResize(.scale(-1))
        #expect(c.model.defaultResize == nil && c.model.alert?.code == "invalidDimensions")
    }
    @Test func resetAllRemainsAvailableUntilLastProcessedFileIsReset() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.setDefaultFormat(.png)
        c.model.importFiles([c.fixture("photo.png"), c.fixture("photo.jpg")])
        try await c.model.waitUntilIdle()
        #expect(!c.model.canResetAll)
        c.model.exportAll()
        #expect(!c.model.canResetAll)
        try await c.model.waitUntilIdle()
        #expect(c.model.canResetAll)
        let exports = try c.model.jobs.map { job in
            let url = try #require(job.exportedURL)
            return (url, try Data(contentsOf: url))
        }
        c.model.reset(c.model.jobs[0]); try await c.model.waitUntilIdle()
        #expect(!c.model.allCompleted && c.model.canResetAll)
        c.model.resetAll(); try await c.model.waitUntilIdle()
        #expect(!c.model.canResetAll)
        #expect(c.model.jobs.allSatisfy { $0.status == .ready && $0.result == nil && $0.exportedURL == nil })
        #expect(c.model.jobs.allSatisfy { !$0.compressionRequested && $0.progress == 0 })
        for (url, bytes) in exports { #expect(try Data(contentsOf: url) == bytes) }
    }
    @Test func resetRestoresOriginalAndWaitsForAirufy() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.png"), c.fixture("photo.jpg")])
        try await c.model.waitUntilIdle()
        c.model.setDefaultFormat(.webp)
        try await c.model.waitUntilIdle()
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0], other = c.model.jobs[1]
        #expect(job.canReset)
        let oldExport = try #require(job.exportedURL)
        let oldBytes = try Data(contentsOf: oldExport)
        let otherExport = other.exportedURL, otherKey = other.result?.cacheKey
        let resetRevision = job.resetRevision
        c.model.reset(job)
        #expect(job.resetRevision == resetRevision + 1)
        try await c.model.waitUntilIdle()
        #expect(job.status == .ready); #expect(job.result == nil)
        #expect(job.exportedURL == nil); #expect(job.revealURL == job.sourceURL)
        #expect(job.progress == 0); #expect(!job.compressionRequested); #expect(!job.canReset)
        #expect(!c.model.allCompleted); #expect(c.model.hasReadyFiles)
        #expect(try Data(contentsOf: oldExport) == oldBytes)
        c.model.setDefaultFormat(.avif); c.model.setDefaultProfile(.superlight)
        try await c.model.waitUntilIdle()
        #expect(job.result == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(job.status == .completed)
        #expect(job.result?.selectedFormat == .avif)
        #expect(job.result?.options.minimumScore == 80)
        #expect(job.result?.options.pngMode == .superlight)
        #expect(job.result?.source.sourceURL == c.fixture("photo.png"))
        #expect(other.status == .completed); #expect(other.exportedURL == otherExport)
        #expect(other.result?.cacheKey == otherKey)
        #expect(try Data(contentsOf: oldExport) == oldBytes)
    }
    @Test func pngModeSelectsLosslessOrPalettePipeline() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.setDefaultFormat(.png)
        c.model.importFiles([c.fixture("palette-graphic.png")]); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0]
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let airy = try #require(job.result)
        #expect(airy.options.pngMode == .airy)
        #expect(airy.candidates.count == 1 && airy.candidates[0].lossless)
        c.model.reset(job); try await c.model.waitUntilIdle()
        c.model.setDefaultProfile(.superlight)
        #expect(job.result == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let superlight = try #require(job.result)
        #expect(job.status == .completed)
        #expect(superlight.options.pngMode == .superlight)
        #expect(superlight.options.minimumScore == 80)
        #expect(try #require(superlight.perceptualScore) >= 80)
        #expect(superlight.outputSize < airy.outputSize)
        #expect(superlight.cacheKey != airy.cacheKey)
    }

    @Test func importAndFormatSelectionDoNotCompress() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")])
        try await c.model.waitUntilIdle()
        let job = try #require(c.model.jobs.first)
        #expect(job.info != nil); #expect(job.status == .ready)
        #expect(job.result == nil); #expect(job.exportedURL == nil)
        #expect(job.revealURL == job.sourceURL)
        #expect(job.progress == 0); #expect(c.model.batchProgress == 0)
        #expect(c.model.hasReadyFiles); #expect(!c.model.isCompressing)
        c.model.setDefaultFormat(.webp)
        #expect(job.status == .ready)
        #expect(job.info != nil)
        c.model.setFormat(.png, for: job)
        #expect(job.status == .ready)
        c.model.setDefaultProfile(.superlight)
        #expect(job.status == .ready)
        try await c.model.waitUntilIdle()
        #expect(job.requestedFormat == .png); #expect(job.result == nil)
        #expect(!FileManager.default.fileExists(atPath: c.root.appendingPathComponent("cache").path))
        #expect(!FileManager.default.fileExists(atPath: c.model.destinations.defaultURL.path))
    }
    @Test func airufyCompressesQualityChecksAndExportsJPEG() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        let job = c.model.jobs[0]
        var percentages = [job.progressPercentage]
        c.model.exportAll()
        while job.isBusy {
            percentages.append(job.progressPercentage)
            if job.result == nil { #expect(job.progressPercentage < 100) }
            if job.status == .exporting { #expect(job.progressPercentage == 100) }
            try await Task.sleep(for: .milliseconds(10))
        }
        try await c.model.waitUntilIdle()
        percentages.append(job.progressPercentage)
        #expect(percentages.first == 0); #expect(percentages.last == 100)
        #expect(percentages.contains { $0 > 0 && $0 < 100 })
        #expect(zip(percentages, percentages.dropFirst()).allSatisfy { $0 <= $1 })
        let result = try #require(job.result)
        #expect(job.status == .completed); #expect(c.model.allCompleted)
        #expect(result.perceptualScore! >= 90); #expect(result.outputSize < result.source.fileSize)
        let url = try #require(job.exportedURL)
        #expect(job.revealURL == url)
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
    @Test func stoppingCompressionPreservesCompletedFilesAndAllowsRestart() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.setDefaultFormat(.png)
        c.model.importFiles([c.fixture("photo.png")])
        try await c.model.waitUntilIdle()
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let completed = try #require(c.model.jobs.first)
        #expect(completed.status == .completed)
        let exportedURL = try #require(completed.exportedURL)
        let exportedData = try Data(contentsOf: exportedURL)

        c.model.importFiles([c.fixture("photo.jpg")])
        try await c.model.waitUntilIdle()
        let pending = try #require(c.model.jobs.first { $0.id != completed.id })
        #expect(!c.model.isCompressing)
        c.model.exportAll()
        #expect(c.model.isCompressing)
        c.model.cancelAll(); try await c.model.waitUntilIdle()
        #expect(!c.model.isCompressing)
        #expect(pending.status == .cancelled && pending.canCompress)
        #expect(completed.status == .completed && completed.exportedURL == exportedURL)
        #expect(try Data(contentsOf: exportedURL) == exportedData)

        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(pending.status == .completed)
        #expect(completed.exportedURL == exportedURL)
        // A stopped export can reuse its already verified compression result.
        pending.status = .cancelled
        #expect(pending.canExport)
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
        let original = c.model.jobs[0]
        c.model.exportAll()
        c.model.importFiles([c.fixture("tiny.png")])
        try await c.model.waitUntilIdle()
        #expect(original.status == .completed)
        #expect(c.model.jobs.last?.id == original.id)
        let added = c.model.jobs[0]
        #expect(added.status == .ready); #expect(added.result == nil); #expect(added.exportedURL == nil)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(c.model.allCompleted)
    }
    @Test func newImportsPrependAndCompletedFilesRemainUnchanged() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.setDefaultFormat(.png)
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let original = c.model.jobs[0]
        let result = try #require(original.result), url = try #require(original.exportedURL)
        let bytes = try Data(contentsOf: url)
        let modified = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        c.model.importFiles([c.fixture("oriented.jpg"), c.fixture("transparent.png"), c.fixture("photo.jpg")])
        try await c.model.waitUntilIdle()
        #expect(c.model.jobs.map(\.filename) == ["oriented.jpg", "transparent.png", "photo.jpg"])
        c.model.setDefaultFormat(.webp); try await c.model.waitUntilIdle()
        #expect(original.status == .completed); #expect(original.requestedFormat == .png)
        #expect(original.result?.cacheKey == result.cacheKey); #expect(original.exportedURL == url)
        #expect(c.model.jobs.prefix(2).allSatisfy { $0.result == nil && $0.requestedFormat == .webp })
        c.model.exportAll(); try await c.model.waitUntilIdle()
        #expect(c.model.allCompleted)
        #expect(original.result?.cacheKey == result.cacheKey); #expect(original.exportedURL == url)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == modified)
        #expect(try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("photo-comp") }.count == 1)
    }
    @Test func completedTransparencyDoesNotBlockJPEGForNewFiles() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.setDefaultFormat(.png)
        c.model.importFiles([c.fixture("transparent.png")]); try await c.model.waitUntilIdle()
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let completed = c.model.jobs[0]
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        #expect(c.model.canUseJPEG)
        c.model.setDefaultFormat(.jpeg); try await c.model.waitUntilIdle()
        #expect(c.model.jobs[0].requestedFormat == .jpeg)
        #expect(completed.status == .completed); #expect(completed.requestedFormat == .png)
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
    @Test func superlightUsesTarget80AndLeavesCompletedAiryFilesUnchanged() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.setDefaultFormat(.webp)
        c.model.importFiles([c.fixture("photo.jpg")]); try await c.model.waitUntilIdle()
        #expect(c.model.defaultProfile == .airy)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let old = c.model.jobs[0], oldResult = try #require(c.model.jobs[0].result)
        let oldURL = try #require(old.exportedURL)
        #expect(oldResult.options.minimumScore == 90)
        c.model.setDefaultProfile(.superlight)
        c.model.importFiles([c.fixture("oriented.jpg")]); try await c.model.waitUntilIdle()
        let pending = c.model.jobs[0]
        c.model.setDefaultProfile(.airy); c.model.setDefaultProfile(.superlight)
        try await c.model.waitUntilIdle()
        #expect(pending.requestedProfile == .superlight); #expect(pending.result == nil)
        #expect(pending.progress == 0); #expect(!c.model.isCompressing)
        #expect(old.status == .completed); #expect(old.requestedProfile == .airy)
        #expect(old.exportedURL == oldURL); #expect(old.result?.cacheKey == oldResult.cacheKey)
        c.model.exportAll(); try await c.model.waitUntilIdle()
        let result = try #require(pending.result)
        #expect(pending.status == .completed); #expect(result.options.minimumScore == 80)
        #expect(try #require(result.perceptualScore) >= 80)
        #expect(old.exportedURL == oldURL); #expect(old.result?.options.minimumScore == 90)
    }
    @Test func droppedFilesShowAnalysisForAtLeastThreeSecondsWithoutCompression() async throws {
        let c = try Context(); defer { c.cleanup() }
        let clock = ContinuousClock(), start = ContinuousClock.now
        c.model.importFiles([c.fixture("photo.jpg")], showAnalysisScreen: true)
        #expect(c.model.isPresentingImportAnalysis)
        try await Task.sleep(for: .milliseconds(200))
        #expect(c.model.isPresentingImportAnalysis)
        try await c.model.waitUntilIdle()
        #expect(start.duration(to: clock.now) >= .seconds(3))
        #expect(!c.model.isPresentingImportAnalysis)
        #expect(c.model.jobs[0].info != nil); #expect(c.model.jobs[0].result == nil)
        #expect(c.model.jobs[0].status == .ready)
    }
    @Test func cancellingImportClearsAnalysisPresentation() async throws {
        let c = try Context(); defer { c.cleanup() }
        c.model.importFiles([c.fixture("photo.jpg")], showAnalysisScreen: true)
        c.model.cancelAll(); try await c.model.waitUntilIdle()
        #expect(!c.model.isPresentingImportAnalysis)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AIRU_RENDER_UI"] == "1", "Run Scripts/render-analysis.sh to compile native image assets"))
    func renderImportAnalysisReference() throws {
        let c = try Context(); defer { c.cleanup() }
        let renderer = ImageRenderer(content: ImportAnalysisView().frame(width: 600, height: 332))
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let folder = c.project.appendingPathComponent("Tests/Screenshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("auto-analyzing.png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        #expect(image.width == 1200 && image.height == 664)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AIRU_RENDER_UI"] == "1", "Run Scripts/render-analysis.sh to compile native image assets"))
    func renderDropEdgeReference() throws {
        let c = try Context(); defer { c.cleanup() }
        let renderer = ImageRenderer(content: DropZoneView(isTargeted: true, browse: {}).frame(width: 600, height: 332))
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let folder = c.project.appendingPathComponent("Tests/Screenshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("drop-edge-glow.png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        #expect(image.width == 1200 && image.height == 664)
    }
    @Test func formatSelectorHugsItsSelectedContent() {
        func size(_ format: OutputFormat, _ profile: CompressionProfile) -> CGSize {
            let view = FormatSelector(value: format, profile: profile, jpegAllowed: true, select: { _ in }, selectProfile: { _ in })
            return NSHostingView(rootView: view).fittingSize
        }
        let jpeg = size(.jpeg, .airy), png = size(.png, .airy), superlight = size(.jpeg, .superlight)
        #expect(jpeg.height == 38); #expect(superlight.height == 38)
        #expect(png.width < jpeg.width)
        #expect(superlight.width > jpeg.width + 20)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AIRU_RENDER_UI"] == "1", "Compile native image assets before rendering"))
    func renderFigmaComponentsReference() throws {
        let c = try Context(); defer { c.cleanup() }
        let content = VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 24) {
                FormatMenuContent(state: FormatMenuState(value: .jpeg, profile: .airy, jpegAllowed: true,
                                                        select: { _ in }, selectProfile: { _ in }), dismiss: {})
                VStack(alignment: .leading, spacing: 20) {
                    DestinationPicker(url: URL(fileURLWithPath: "/Users/timparanitsa/Desktop"), choose: {})
                    DestinationPicker(url: URL(fileURLWithPath: "/Users/timparanitsa/Desktop"), hovering: true, folderHovered: true, choose: {})
                    DestinationPicker(url: URL(fileURLWithPath: "/Users/timparanitsa/Desktop"), hovering: true, choose: {})
                }
            }
            HStack(spacing: 24) {
                FormatSelector(value: .jpeg, profile: .airy, jpegAllowed: true, select: { _ in }, selectProfile: { _ in })
                DestinationPicker(url: URL(fileURLWithPath: "/Users/timparanitsa/Desktop"), choose: {})
                Button("Airufy") {}.buttonStyle(AiruButtonStyle(kind: .primary))
            }
            HStack(spacing: 24) {
                FormatSelector(value: .png, profile: .airy, jpegAllowed: true, select: { _ in }, selectProfile: { _ in })
                FormatSelector(value: .webp, profile: .superlight, jpegAllowed: true, select: { _ in }, selectProfile: { _ in })
            }
        }.padding(16).background(AiruStyle.background).preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let folder = c.project.appendingPathComponent("Tests/Screenshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let output = folder.appendingPathComponent("figma-components.png")
        let destination = try #require(CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
    @Test func destinationWidthIsUnchangedOnHover() {
        let url = URL(fileURLWithPath: "/Users/timparanitsa/Desktop")
        let idle = NSHostingView(rootView: DestinationPicker(url: url, choose: {})).fittingSize
        let hover = NSHostingView(rootView: DestinationPicker(url: url, hovering: true, choose: {})).fittingSize
        let folderHover = NSHostingView(rootView: DestinationPicker(url: url, hovering: true, folderHovered: true, choose: {})).fittingSize
        #expect(idle == hover)
        #expect(idle == folderHover)
        #expect(idle.height == 38)
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
