import SwiftUI
import AiruCore

struct ImageListView: View {
    let model: CompressionViewModel
    @State private var previewID: UUID?
    @State private var previewThumbnail: CGImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var previewAnimation: Animation { reduceMotion ? .easeOut(duration: 0.12) : .timingCurve(0.22, 1, 0.36, 1, duration: 0.3) }
    var body: some View {
        list
            .overlayPreferenceValue(ThumbnailAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        if previewID != nil {
                            Color.clear.contentShape(Rectangle()).onTapGesture { dismissPreview() }
                        }
                        if let id = previewID, let thumbnail = previewThumbnail,
                           let anchor = anchors[id], let job = model.jobs.first(where: { $0.id == id }) {
                            let layout = ThumbnailPreviewLayout(thumbnail: proxy[anchor], viewport: proxy.size)
                            LargeThumbnailPreview(job: job, thumbnail: thumbnail, layout: layout, dismiss: dismissPreview)
                                .id(id)
                                .transition(reduceMotion ? .opacity : .modifier(
                                    active: ThumbnailPreviewTransform(progress: 0, layout: layout),
                                    identity: ThumbnailPreviewTransform(progress: 1, layout: layout)))
                                .position(x: layout.frame.midX, y: layout.frame.midY)
                                .zIndex(1)
                        }
                    }
                }
            }
            .onExitCommand { dismissPreview() }
            .onChange(of: model.jobs.map(\.id)) { _, _ in dismissPreview() }
    }
    @ViewBuilder private var list: some View {
        if #available(macOS 15.0, *) {
            FadingImageList(model: model, showPreview: showPreview, dismissPreview: dismissPreview)
        } else {
            ScrollView { ImageListRows(model: model, showPreview: showPreview) }
                .scrollClipDisabled()
                .mask(Rectangle().padding(.horizontal, -AiruStyle.inset))
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    private func showPreview(_ id: UUID, _ image: CGImage) {
        withAnimation(previewAnimation) {
            previewThumbnail = image
            previewID = previewID == id ? nil : id
        }
    }
    private func dismissPreview() {
        guard previewID != nil else { return }
        withAnimation(previewAnimation) { previewID = nil }
    }
}

private struct ImageListRows: View {
    let model: CompressionViewModel
    let showPreview: (UUID, CGImage) -> Void
    var body: some View {
        LazyVStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            ForEach(model.jobs) { job in
                ImageRowView(job: job, model: model, showPreview: showPreview)
                Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            }
        }
    }
}

@available(macOS 15.0, *)
private struct FadingImageList: View {
    let model: CompressionViewModel
    let showPreview: (UUID, CGImage) -> Void
    let dismissPreview: () -> Void
    @State private var position = ScrollPosition(y: 0)
    @State private var metrics = ListScrollMetrics()
    @State private var dragStart: CGFloat?
    var body: some View {
        ScrollView {
            ImageListRows(model: model, showPreview: showPreview)
        }
        // Let horizontal transitions pass through the list's inset to the window edge.
        // Keep vertical scrolling contained above the footer and below the header.
        .scrollClipDisabled()
        .mask(Rectangle().padding(.horizontal, -AiruStyle.inset))
        .scrollPosition($position)
        .onChange(of: model.jobs.first?.id) { oldID, newID in
            if let oldID, let newID, oldID != newID,
               model.jobs.contains(where: { $0.id == oldID }) {
                position.scrollTo(y: 0)
            }
        }
        .onScrollGeometryChange(for: ListScrollMetrics.self) { geometry in
            ListScrollMetrics(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                              contentHeight: geometry.contentSize.height,
                              viewportHeight: geometry.containerSize.height)
        } action: { old, value in
            if abs(old.offset - value.offset) > 0.5 { dismissPreview() }
            metrics = value
        }
        .scrollIndicators(.hidden)
        .overlay {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    fade(width: geometry.size.width, bottom: false).opacity(metrics.hasContentAbove ? 1 : 0)
                    Spacer(minLength: 0)
                    fade(width: geometry.size.width, bottom: true).opacity(metrics.hasContentBelow ? 1 : 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if metrics.maximumOffset > 1 {
                Capsule().fill(Color(white: 139/255)).frame(width: 5, height: metrics.thumbHeight)
                    .padding(.horizontal, 5).contentShape(Rectangle())
                    .offset(x: 18.5, y: metrics.thumbOffset)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        if dragStart == nil { dragStart = metrics.clampedOffset }
                        let travel = metrics.viewportHeight - metrics.thumbHeight
                        guard travel > 0 else { return }
                        let offset = (dragStart ?? 0) + value.translation.height * metrics.maximumOffset / travel
                        position.scrollTo(y: min(max(offset, 0), metrics.maximumOffset))
                    }.onEnded { _ in dragStart = nil })
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    private func fade(width: CGFloat, bottom: Bool) -> some View {
        // Original 606×37 Figma gradient, mirrored for the bottom edge.
        Image("ScrollFade", bundle: .module).resizable().frame(width: width + 6, height: 37)
            .scaleEffect(x: 1, y: bottom ? -1 : 1)
            .frame(width: width)
    }
}

private struct ListScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var maximumOffset: CGFloat { max(0, contentHeight - viewportHeight) }
    var clampedOffset: CGFloat { min(max(offset, 0), maximumOffset) }
    var hasContentAbove: Bool { clampedOffset > 1 }
    var hasContentBelow: Bool { clampedOffset < maximumOffset - 1 }
    var thumbHeight: CGFloat { min(viewportHeight, max(28, viewportHeight * viewportHeight / max(contentHeight, 1))) }
    var thumbOffset: CGFloat { maximumOffset > 0 ? clampedOffset / maximumOffset * (viewportHeight - thumbHeight) : 0 }
}

struct ImageRowView: View {
    @Bindable var job: ImageJobViewModel
    let model: CompressionViewModel
    var showPreview: ((UUID, CGImage) -> Void)? = nil
    @State private var hovering = false
    @State private var hoverEntryResolved = false
    @State private var thumbnailIsPrimary = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var showError = false
    @State private var actionsSuppressed = false
    @State private var thumbnail: CGImage?
    private var expanded: Bool { !actionsSuppressed && (hovering || focused) }
    private var actionsVisible: Bool { expanded && job.status != .exporting }
    var body: some View {
        interactiveRow
        .accessibilityElement(children: .contain)
        .accessibilityLabel(job.filename)
        .accessibilityValue(accessibilityStatus)
        .accessibilityAction(named: "Compress") { model.export(job) }
        .accessibilityAction(named: "Remove") { model.remove(job) }
        .accessibilityAction(named: "Reveal in Finder") { model.reveal(job) }
        .accessibilityAction(named: "Reset to original") { model.reset(job) }
        .accessibilityAction(named: "Preview image") { openPreview() }
        .contextMenu {
            Button("Compress") { model.export(job) }.disabled(!job.canExport && !job.canCompress)
            Menu("Output format") {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    Button(format.label) { model.setFormat(format, for: job) }.disabled(format == .jpeg && !job.canUseJPEG)
                }
            }
            Button("Choose export folder…") { Task { await model.chooseDestination(for: job) } }
            if job.destinationOverride != nil {
                Button("Use default export folder") { job.destinationOverride = nil; job.destinationAccess = nil }
            }
            Button("Preview image") { openPreview() }.disabled(thumbnail == nil)
            Button("Reveal in Finder") { model.reveal(job) }
            if job.canReset { Button("Reset to original") { model.reset(job) } }
            if job.error != nil { Button("Show error…") { showError = true } }
            Divider()
            Button("Remove") { model.remove(job) }
        }
        .alert("Couldn’t process \(job.filename)", isPresented: $showError) { Button("OK") {} } message: { Text(job.error?.message ?? "") }
    }
    private var interactiveRow: some View {
        rowContent
        .frame(height: AiruStyle.rowHeight)
        .task(id: job.info?.contentSHA256) { await loadThumbnail() }
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: expanded)
        // Export can hide the actions without changing hover or keyboard focus.
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: actionsVisible)
        .contentShape(Rectangle())
        // Keep image clicks available when entering on its column; other row hover reveals Remove.
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                let slot = CGRect(x: 0, y: 0, width: 22, height: AiruStyle.rowHeight)
                if !hoverEntryResolved {
                    thumbnailIsPrimary = slot.contains(point)
                    hoverEntryResolved = true
                } else if !slot.contains(point) { thumbnailIsPrimary = false }
                hovering = true
            case .ended:
                hovering = false; hoverEntryResolved = false; thumbnailIsPrimary = false
                actionsSuppressed = false
            }
        }
        .onChange(of: job.resetRevision) { _, _ in
            actionsSuppressed = true
            hovering = false
            focused = false
        }
        .onChange(of: focused) { _, value in
            if value { actionsSuppressed = false }
        }
        .focusable().focused($focused).focusEffectDisabled()
        .onKeyPress(.delete) { model.remove(job); return .handled }
        .onKeyPress(.return) { model.reveal(job); return .handled }
    }
    private func loadThumbnail() async {
        guard let identity = job.info?.contentSHA256 else { return }
        let image = await ImageThumbnailLoader.shared.image(at: job.sourceURL, contentIdentity: identity)
        guard !Task.isCancelled else { return }
        thumbnail = image
    }
    private var rowContent: some View {
        HStack(spacing: 10) {
            thumbnailSlot
            Button(action: openPreview) {
                Text(job.filename).font(AiruStyle.text(13, .light)).lineLimit(1).truncationMode(.middle)
                    .frame(minWidth: 50, maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Click to preview \(job.filename)")
            HStack(spacing: 10) {
                if let result = job.result {
                    Text(result.selectedFormat.label).font(AiruStyle.text(12))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(AiruStyle.control, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.trailing, 22)
                        .accessibilityLabel("Converted to \(result.selectedFormat.label)")
                }
                status
                if actionsVisible {
                    HStack(spacing: 10) {
                        if job.canReset {
                            Button { model.reset(job) } label: {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 14, weight: .medium))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain).background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 7))
                            .help("Reset to original file")
                            .accessibilityLabel("Reset \(job.filename) to original")
                        }
                        rowAction("Show") { model.reveal(job) }
                            .help(job.revealURL.path)
                            .accessibilityLabel("Show \(job.filename) in Finder")
                    }
                    .transition(actionTransition(from: .trailing))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    private var thumbnailSlot: some View {
        ZStack {
            if !expanded || thumbnailIsPrimary {
                Button(action: openPreview) {
                    Group {
                        if let thumbnail {
                            Image(decorative: thumbnail, scale: 2).resizable().scaledToFill()
                        } else {
                            AiruStyle.control.overlay {
                                Image(systemName: "photo").font(.system(size: 10)).foregroundStyle(AiruStyle.muted)
                            }
                        }
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(thumbnail == nil)
                .accessibilityLabel("Preview \(job.filename)")
                .transition(.opacity)
            }
            if expanded && !thumbnailIsPrimary {
                Button { model.remove(job) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .regular)).foregroundStyle(Color(red: 1, green: 56/255, blue: 60/255))
                        .frame(width: 22, height: 22).background(Color(red: 76/255, green: 20/255, blue: 21/255), in: RoundedRectangle(cornerRadius: 5.5))
            }.buttonStyle(.plain).accessibilityLabel("Remove \(job.filename)")
                .transition(.opacity)
            }
        }
        .frame(width: 22, height: 22)
        .anchorPreference(key: ThumbnailAnchorKey.self, value: .bounds) { [job.id: $0] }
    }
    private func openPreview() {
        guard let thumbnail else { return }
        showPreview?(job.id, thumbnail)
    }
    private func actionTransition(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity.animation(.easeOut(duration: 0.12)) : .move(edge: edge).combined(with: .opacity)
    }
    @ViewBuilder private var status: some View {
        switch job.status {
        case .queued:
            Text(job.compressionRequested ? "0%" : "In queue")
                .font(AiruStyle.text()).foregroundStyle(job.compressionRequested ? AiruStyle.yellow : AiruStyle.muted)
        case .analyzing, .optimizing:
            HStack(spacing: 5) {
                AiruSpinner()
                Text(job.status == .analyzing && !job.compressionRequested ? "Analyzing" : "\(job.progressPercentage)%")
                    .font(AiruStyle.text()).foregroundStyle(AiruStyle.yellow).monospacedDigit()
            }
        case .exporting:
            HStack(spacing: 5) {
                AiruSpinner()
                Text("\(job.progressPercentage)%").font(AiruStyle.text()).foregroundStyle(AiruStyle.yellow)
                    .monospacedDigit().help("Compression complete; saving the verified output")
            }
        case .ready, .completed:
            if let result = job.result {
                FileSizeComparison(result: result)
                    .help("\(job.outputFormatLabel) · \(result.alreadyOptimized ? "Already optimized" : "Verified quality")")
            } else if let info = job.info {
                Text(FileSizeText.format(info.fileSize)).font(AiruStyle.text(13, .light))
                    .foregroundStyle(AiruStyle.muted)
            }
        case .failed:
            Button { showError = true } label: {
                Label("Failed", systemImage: "exclamationmark.circle").font(AiruStyle.text()).foregroundStyle(.red)
            }.buttonStyle(.plain).help(job.error?.message ?? "Processing failed")
        case .cancelled:
            Text("Cancelled").font(AiruStyle.text()).foregroundStyle(AiruStyle.muted)
        }
    }
    private func rowAction(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).font(AiruStyle.text(12, .medium)).padding(.horizontal, 10).frame(height: 28) }
            .buttonStyle(.plain).background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityLabel("\(label) \(job.filename)")
    }
    private var accessibilityStatus: String {
        let size = job.result.map { "\(FileSizeText.format($0.source.fileSize)) to \(FileSizeText.format($0.outputSize))" } ?? ""
        return "\(job.status.rawValue), \(size), \(job.outputFormatLabel)"
    }
}

struct FileSizeComparison: View {
    let result: CompressionResult
    private var sizeColor: AnyShapeStyle {
        result.outputSize > result.source.fileSize
            ? AnyShapeStyle(Color(red: 1, green: 56/255, blue: 60/255)) : AnyShapeStyle(AiruStyle.success)
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(FileSizeText.format(result.source.fileSize)).font(AiruStyle.text(13, .light)).foregroundStyle(AiruStyle.muted)
            Text("→").font(AiruStyle.text(14)).foregroundStyle(AiruStyle.muted)
            if result.alreadyOptimized {
                Text("Already optimized").font(AiruStyle.text(12)).foregroundStyle(AiruStyle.muted)
            } else {
                Text(FileSizeText.format(result.outputSize)).font(AiruStyle.text()).foregroundStyle(sizeColor)
                Text(String(format: "(%@%.0f%%)", result.savingsPercentage >= 0 ? "−" : "+", abs(result.savingsPercentage)))
                    .font(AiruStyle.text(10)).foregroundStyle(result.savingsPercentage >= 0 ? AnyShapeStyle(AiruStyle.green.opacity(0.66)) : sizeColor)
            }
        }.monospacedDigit()
    }
}
