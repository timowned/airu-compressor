import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AiruCore

public struct MainWindow: View {
    @Bindable private var rootModel: CompressionViewModel
    public init(model: CompressionViewModel) { rootModel = model }
    public var body: some View {
        WorkspaceWindow(model: rootModel.activeWorkspace, selectedMode: $rootModel.mode)
    }
}

private struct WorkspaceWindow: View {
    @Bindable var model: CompressionViewModel
    @Binding var selectedMode: ApplicationMode
    @Namespace private var tabSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTarget = false
    @State private var formatMenuPresented = false
    public var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if model.isPresentingImportAnalysis {
                    ImportAnalysisView()
                        .padding([.horizontal, .bottom], AiruStyle.inset).padding(.top, 16)
                } else if model.jobs.isEmpty {
                    DropZoneView(isTargeted: isDropTarget, browse: model.browseFiles)
                        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget, perform: acceptDrop)
                        .padding([.horizontal, .bottom], AiruStyle.inset).padding(.top, 16)
                } else {
                    VStack(spacing: 10) {
                        ImageListView(model: model)
                        footer
                    }
                    .padding([.horizontal, .bottom], AiruStyle.inset).padding(.top, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if isDropTarget {
                            DropZoneGlow()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [10, 10])))
                                .padding([.horizontal, .bottom], AiruStyle.inset).padding(.top, 16).allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: isDropTarget)
                }
            }
        }
        .onChange(of: selectedMode) { _, _ in
            isDropTarget = false
            formatMenuPresented = false
        }
        .background(AiruStyle.background)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .frame(minWidth: 640, minHeight: 430)
        .contentShape(Rectangle())
        .onDrop(of: !model.jobs.isEmpty ? [UTType.fileURL.identifier] : [],
                isTargeted: $isDropTarget, perform: acceptDrop)
        .alert("Airu", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK") { model.alert = nil }
        } message: { Text(model.alert?.message ?? "") }
    }
    @ViewBuilder private var header: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 16) { headerContents }
                .frame(height: AiruStyle.headerHeight)
        } else { headerContents.frame(height: AiruStyle.headerHeight) }
    }
    private var headerContents: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(ApplicationMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { selectedMode = mode }
                    } label: {
                        Text(mode.rawValue).font(AiruStyle.text(14))
                            .padding(.horizontal, 12).frame(height: 32)
                            .background {
                                if selectedMode == mode {
                                    Capsule().fill(Color.black.opacity(0.4))
                                        .matchedGeometryEffect(id: "selected-tab", in: tabSelection)
                                }
                            }
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
                    .accessibilityIdentifier("mode-\(mode.rawValue)")
                }
            }
            .padding(4).airuLiquidGlass()
            .offset(y: 5)
            HStack {
                Spacer()
                if !model.jobs.isEmpty && !model.isPresentingImportAnalysis {
                    Button(action: model.browseFiles) {
                        DesignAsset(name: "Add", width: 16, height: 16)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain).airuLiquidGlass().accessibilityLabel("Add images")
                    .keyboardShortcut("o", modifiers: .command).help("Add images (⌘O)")
                    .offset(y: 5)
                }
            }.padding(.horizontal, 22)
        }
        .frame(height: AiruStyle.headerHeight)
        .overlay(alignment: .topLeading) {
            WindowTrafficLights().frame(width: 60, height: 14)
                .padding(.top, 22).padding(.leading, 22)
        }
    }
    private var footer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.workflow == .upscale ? "Save as" : "Compress").font(.system(size: 13, weight: .regular)).foregroundStyle(.white.opacity(0.5))
                    .frame(height: 9)
                    .opacity(formatMenuPresented ? 0 : 1)
                    .accessibilityHidden(formatMenuPresented)
                    .animation(.easeInOut(duration: 0.16), value: formatMenuPresented)
                FormatSelector(value: model.defaultFormat, profile: model.defaultProfile,
                               caption: "Default output format", resizeModel: model.workflow == .compress ? model : nil, jpegAllowed: model.canUseJPEG,
                               onPresentationChange: { formatMenuPresented = $0 },
                               select: model.setDefaultFormat, selectProfile: model.setDefaultProfile)
                    .accessibilityIdentifier("default-format")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Upscale").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5)).frame(height: 9)
                HStack(spacing: 2) {
                    ForEach([2, 4], id: \.self) { factor in
                        Button { model.setUpscaleFactor(factor) } label: {
                            Text("\(factor)×").font(AiruStyle.text(13, .medium)).frame(width: 30, height: 30)
                                .background((model.workflow == .upscale ? model.upscaleFactor : model.compressionUpscaleFactor) == factor ? Color(white: 0.2) : .clear,
                                            in: RoundedRectangle(cornerRadius: 7))
                        }.buttonStyle(.plain).accessibilityLabel("Upscale \(factor) times")
                            .accessibilityAddTraits((model.workflow == .upscale ? model.upscaleFactor : model.compressionUpscaleFactor) == factor ? .isSelected : [])
                    }
                }
                .padding(4).background(AiruStyle.control, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AiruStyle.controlBorder))
                .help("Real-ESRGAN x4plus · offline AI enhancement")
            }
            DestinationPicker(url: model.destinations.defaultURL) { Task { await model.chooseDestination() } }
            Spacer(minLength: 0)
            if model.isCompressing {
                Button("Stop", action: model.stopWorkspace)
                    .buttonStyle(AiruButtonStyle(kind: .destructive))
                    .help(model.workflow == .upscale ? "Stop current upscale" : "Stop current compression")
                    .accessibilityLabel(model.workflow == .upscale ? "Stop upscaling" : "Stop compression")
                    .accessibilityIdentifier("stop-compression")
            }
            if model.canResetAll {
                Button(action: model.resetAll) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 16)
                }
                .buttonStyle(AiruButtonStyle(kind: .secondary))
                .help("Reset all processed images to their originals")
                .accessibilityLabel("Reset All")
                .accessibilityIdentifier("reset-all")
            }
            if !model.isCompressing {
                Button(model.allCompleted ? "Airufied!" : "Airufy", action: model.exportAll)
                    .buttonStyle(AiruButtonStyle(kind: model.allCompleted ? .success : .primary))
                    .disabled(!model.allCompleted && (!model.hasReadyFiles || model.isBusy))
                    .accessibilityLabel(model.allCompleted ? "Reveal exported images in Finder" : (model.workflow == .upscale ? "Upscale all ready images" : "Compress all ready images"))
                    .accessibilityIdentifier("compress-all")
            }
        }
    }
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        // Resolve the drop as one ordered import, so asynchronous URL loading cannot shuffle rows.
        Task { @MainActor in
            var urls: [URL] = []
            for provider in matching {
                let url: URL? = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                        continuation.resume(returning: url)
                    }
                }
                if let url { urls.append(url) }
            }
            if !urls.isEmpty { model.importFiles(urls, showAnalysisScreen: true) }
        }
        return !matching.isEmpty
    }
}

private struct DropZoneGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startedAt)
                // Keep the illuminated rim attached to all four edges; gently vary its color phase.
                Image("DropEdgeGlow", bundle: .module).resizable().renderingMode(.original)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .saturation(0.65)
                    .hueRotation(.degrees(sin(elapsed * 2 * .pi / 80) * 3))
                    .opacity(0.68)
                    .background(Color(white: 12/255))
            }
        }
        .clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ImportAnalysisView: View {
    var body: some View {
        ZStack {
            Color(red: 5/255, green: 7/255, blue: 10/255)
            DropZoneGlow()
            VStack(spacing: 18) {
                AiruSpinner(analysis: true)
                Text("Analyzing...").font(AiruStyle.text(16, .semibold)).foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.18), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing imported images")
        .accessibilityIdentifier("import-analysis")
    }
}

struct DropZoneView: View {
    let isTargeted: Bool
    let browse: () -> Void
    var body: some View {
        Button(action: browse) {
            ZStack {
                AiruStyle.background
                if isTargeted {
                    DropZoneGlow()
                        .transition(.opacity)
                }
                VStack(spacing: 18) {
                    DesignAsset(name: isTargeted ? "DropMarkActive" : "DropMark", width: 67.0682, height: 69.9855)
                    Text("Drop your files").font(AiruStyle.text(16, .semibold))
                        .foregroundStyle(isTargeted ? Color(white: 0.33) : AiruStyle.border).frame(height: 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeInOut(duration: 0.4), value: isTargeted)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isTargeted ? Color(white: 0.62) : AiruStyle.border,
                         style: StrokeStyle(lineWidth: 1.5, dash: [10, 10])))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain).accessibilityLabel("Drop images here or browse files")
        .accessibilityIdentifier("drop-zone").keyboardShortcut("o", modifiers: .command)
        .help("Drop JPEG, PNG, HEIC or WebP images, or click to browse")
    }
}

struct DestinationPicker: View {
    let url: URL
    let choose: () -> Void
    @State private var hovering = false
    @State private var folderHovered = false
    private var containerHovered: Bool { hovering && !folderHovered }
    init(url: URL, hovering: Bool = false, folderHovered: Bool = false, choose: @escaping () -> Void) {
        self.url = url
        self.choose = choose
        _hovering = State(initialValue: hovering)
        _folderHovered = State(initialValue: folderHovered)
    }
    var body: some View {
        Button(action: choose) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    DesignAsset(name: folderHovered ? "DestinationHover" : "DestinationIdle", width: 30, height: 30)
                        .contentShape(Rectangle())
                        .onHover { folderHovered = $0 }
                    AiruStyle.controlBorder.frame(width: 1, height: 36).opacity(hovering ? 0 : 1)
                }
                HStack(spacing: 10) {
                    breadcrumb(url.deletingLastPathComponent().lastPathComponent)
                    DesignAsset(name: "PathChevron", width: 5.06066, height: 8.70711).frame(width: 4, height: 8)
                    breadcrumb(url.lastPathComponent)
                }
            }
            .padding(.leading, 2).padding(.trailing, 10).frame(height: 36)
            .background(containerHovered ? Color(white: 39/255) : AiruStyle.control, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(containerHovered ? Color(white: 48/255) : AiruStyle.controlBorder))
            .padding(1).background(Color(white: 19/255), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .onHover {
            hovering = $0
            if !$0 { folderHovered = false }
        }
        .accessibilityLabel("Choose export folder, \(url.path)").help(url.path)
    }
    private func breadcrumb(_ name: String) -> some View {
        HStack(spacing: 4) {
            DesignAsset(name: "Folder", width: 12.444, height: 12.444).padding(1.778)
            Text(name).font(AiruStyle.text(12)).lineLimit(1).truncationMode(.middle)
        }
    }
}

struct WindowTrafficLights: NSViewRepresentable {
    func makeNSView(context: Context) -> TrafficLightContainer { TrafficLightContainer() }
    func updateNSView(_ nsView: TrafficLightContainer, context: Context) { nsView.needsLayout = true }
}
final class TrafficLightContainer: NSView {
    private var positioning = false
    private var refreshScheduled = false
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { return }
        for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                     NSWindow.didChangeBackingPropertiesNotification, NSWindow.didBecomeKeyNotification,
                     NSWindow.didBecomeMainNotification, NSWindow.didUpdateNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(schedulePositioning), name: name, object: window)
        }
        for (index, kind) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
            guard let button = window.standardWindowButton(kind) else { continue }
            button.removeFromSuperview(); addSubview(button)
            button.autoresizingMask = []
            button.setFrameOrigin(NSPoint(x: CGFloat(index) * 23, y: 0))
            button.setFrameSize(NSSize(width: 14, height: 14))
            button.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(schedulePositioning),
                name: NSView.frameDidChangeNotification, object: button)
        }
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func schedulePositioning() {
        guard !positioning, !refreshScheduled, let window else { return }
        let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let needsRepair = kinds.enumerated().contains { index, kind in
            guard let button = window.standardWindowButton(kind) else { return false }
            return button.superview !== self || button.frame != NSRect(x: CGFloat(index) * 23, y: 0, width: 14, height: 14)
        }
        guard needsRepair else { return }
        refreshScheduled = true
        // AppKit can reposition standard window buttons after SwiftUI has laid out
        // their custom container. Restore them after that native resize pass finishes.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshScheduled = false
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
        }
    }
    override func layout() {
        super.layout()
        positioning = true
        defer { positioning = false }
        guard let window else { return }
        for (index, kind) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
            guard let button = window.standardWindowButton(kind) else { continue }
            // AppKit can reclaim or replace standard buttons during titlebar updates.
            if button.superview !== self {
                button.removeFromSuperview(); addSubview(button)
                button.autoresizingMask = []
                button.postsFrameChangedNotifications = true
                NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: button)
                NotificationCenter.default.addObserver(self, selector: #selector(schedulePositioning),
                    name: NSView.frameDidChangeNotification, object: button)
            }
            button.frame = NSRect(x: CGFloat(index) * 23, y: 0, width: 14, height: 14)
        }
    }
}
