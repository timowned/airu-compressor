import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AiruCore

public struct MainWindow: View {
    @Bindable private var model: CompressionViewModel
    @State private var isDropTarget = false
    public init(model: CompressionViewModel) { self.model = model }
    public var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if model.mode == .manual {
                    Text("Coming soon...")
                        .font(AiruStyle.text(16, .medium)).foregroundStyle(AiruStyle.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.jobs.isEmpty {
                    DropZoneView(isTargeted: isDropTarget, browse: model.browseFiles)
                        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget, perform: acceptDrop)
                        .padding(AiruStyle.inset)
                } else {
                    VStack(spacing: 10) {
                        ImageListView(model: model)
                        footer
                    }
                    .padding(AiruStyle.inset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if isDropTarget {
                            DropZoneGlow()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [10, 10])))
                                .padding(20).allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: isDropTarget)
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget, perform: acceptDrop)
                }
            }
        }
        .background(AiruStyle.background)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .frame(minWidth: 640, minHeight: 430)
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
                    Button { model.mode = mode } label: {
                        Text(mode.rawValue).font(AiruStyle.text(14))
                            .padding(.horizontal, 12).frame(height: 32)
                            .background(model.mode == mode ? Color.black.opacity(0.4) : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(model.mode == mode ? .isSelected : [])
                    .accessibilityIdentifier("mode-\(mode.rawValue)")
                }
            }
            .padding(4).airuLiquidGlass()
            .offset(y: 5)
            HStack {
                WindowTrafficLights().frame(width: 60, height: 14)
                Spacer()
                if !model.jobs.isEmpty {
                    Button(action: model.browseFiles) {
                        Image(systemName: "plus").font(.system(size: 20, weight: .ultraLight)).foregroundStyle(Color(white: 0.7))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain).airuLiquidGlass().accessibilityLabel("Add images")
                    .keyboardShortcut("o", modifiers: .command).help("Add images (⌘O)")
                    .offset(y: 5)
                }
            }.padding(.horizontal, 22)
        }
    }
    private var footer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Compress to").font(.system(size: 13, weight: .regular)).foregroundStyle(.white.opacity(0.8))
                FormatSelector(value: model.defaultFormat, caption: "Default output format", jpegAllowed: model.canUseJPEG,
                               select: model.setDefaultFormat)
                    .accessibilityIdentifier("default-format")
            }
            Spacer(minLength: 0)
            DestinationPicker(url: model.destinations.defaultURL) { Task { await model.chooseDestination() } }
            Spacer(minLength: 0)
            Button(action: model.exportAll) {
                HStack(spacing: 5) {
                    if model.isCompressing { AiruSpinner(button: true) }
                    Text(model.allCompleted ? "Airufied!" : (model.isCompressing ? "Airufying..." : "Airufy"))
                }
            }
            .buttonStyle(AiruButtonStyle(kind: model.allCompleted ? .success : (model.isCompressing ? .working : .primary)))
            .disabled(!model.allCompleted && (!model.hasReadyFiles || model.isBusy))
            .accessibilityLabel(model.allCompleted ? "Reveal exported images in Finder" : "Compress all ready images")
            .accessibilityIdentifier("compress-all")
        }
    }
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                if let url { Task { @MainActor in model.importFiles([url]) } }
            }
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
                // Two slow, continuous paths drift independently without snapping at loop boundaries.
                let x = sin(elapsed * 2 * .pi / 70) * geometry.size.width * 0.25
                let y = sin(elapsed * 2 * .pi / 95) * geometry.size.height * 0.16
                // Figma's raster export retains blur/noise effects unsupported by asset-catalog SVGs.
                ZStack {
                    DesignAsset(name: "DropGlowRaster", width: 600, height: 332)
                    // Add 30% intensity; the base texture already uses full view opacity.
                    DesignAsset(name: "DropGlowRaster", width: 600, height: 332)
                        .opacity(0.3).blendMode(.plusLighter)
                }
                    .compositingGroup()
                    .scaleEffect(max(1.8, geometry.size.width / 600 * 1.8, geometry.size.height / 332 * 1.8))
                    .position(x: geometry.size.width / 2 + 9.28 + x,
                              y: geometry.size.height / 2 - 23.67 + y)
            }
        }
        .clipped().allowsHitTesting(false).accessibilityHidden(true)
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
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isTargeted ? Color(white: 0.36) : AiruStyle.border,
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
    var body: some View {
        HStack(spacing: 12) {
            Button(action: choose) { DesignAsset(name: "FolderOpen", width: 14, height: 10.7569) }
                .buttonStyle(AiruButtonStyle()).accessibilityLabel("Choose default export folder")
            Button(action: choose) {
                HStack(spacing: 8) {
                    breadcrumb(url.deletingLastPathComponent().lastPathComponent)
                    DesignAsset(name: "PathChevron", width: 5.06066, height: 8.70711)
                    breadcrumb(url.lastPathComponent)
                }
            }
            .buttonStyle(.plain).accessibilityLabel("Export destination, \(url.path)").help(url.path)
        }
        .frame(height: 38)
    }
    private func breadcrumb(_ name: String) -> some View {
        HStack(spacing: 4) {
            DesignAsset(name: "Folder", width: 12.444, height: 12.444)
            Text(name).font(AiruStyle.text(12)).lineLimit(1).truncationMode(.middle)
        }
    }
}

struct WindowTrafficLights: NSViewRepresentable {
    func makeNSView(context: Context) -> TrafficLightContainer { TrafficLightContainer() }
    func updateNSView(_ nsView: TrafficLightContainer, context: Context) { nsView.needsLayout = true }
}
final class TrafficLightContainer: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        for (index, kind) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
            guard let button = window.standardWindowButton(kind) else { continue }
            button.removeFromSuperview(); addSubview(button)
            button.autoresizingMask = []
            button.setFrameOrigin(NSPoint(x: CGFloat(index) * 23, y: 0))
            button.setFrameSize(NSSize(width: 14, height: 14))
        }
    }
    override func layout() {
        super.layout()
        for (index, button) in subviews.compactMap({ $0 as? NSButton }).enumerated() {
            button.frame = NSRect(x: CGFloat(index) * 23, y: 0, width: 14, height: 14)
        }
    }
}
