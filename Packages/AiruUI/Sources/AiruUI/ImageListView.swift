import SwiftUI
import AiruCore

struct ImageListView: View {
    let model: CompressionViewModel
    var body: some View {
        if #available(macOS 15.0, *) {
            FadingImageList(model: model)
        } else {
            ScrollView { ImageListRows(model: model) }
                .scrollClipDisabled()
                .mask(Rectangle().padding(.horizontal, -AiruStyle.inset))
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct ImageListRows: View {
    let model: CompressionViewModel
    var body: some View {
        LazyVStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            ForEach(model.jobs) { job in
                ImageRowView(job: job, model: model)
                Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            }
        }
    }
}

@available(macOS 15.0, *)
private struct FadingImageList: View {
    let model: CompressionViewModel
    @State private var position = ScrollPosition(y: 0)
    @State private var metrics = ListScrollMetrics()
    @State private var dragStart: CGFloat?
    var body: some View {
        ScrollView {
            ImageListRows(model: model)
        }
        // Let horizontal transitions pass through the list's inset to the window edge.
        // Keep vertical scrolling contained above the footer and below the header.
        .scrollClipDisabled()
        .mask(Rectangle().padding(.horizontal, -AiruStyle.inset))
        .scrollPosition($position)
        .onScrollGeometryChange(for: ListScrollMetrics.self) { geometry in
            ListScrollMetrics(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                              contentHeight: geometry.contentSize.height,
                              viewportHeight: geometry.containerSize.height)
        } action: { _, value in metrics = value }
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
    @State private var hovering = false
    @State private var formatMenuPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var showError = false
    private var expanded: Bool { hovering || focused || formatMenuPresented }
    private var actionsVisible: Bool { expanded && job.status != .exporting }
    var body: some View {
        HStack(spacing: expanded ? 10 : 0) {
            if expanded {
                Button { model.remove(job) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .regular)).foregroundStyle(Color(red: 1, green: 56/255, blue: 60/255))
                        .frame(width: 22, height: 22).background(Color(red: 76/255, green: 20/255, blue: 21/255), in: RoundedRectangle(cornerRadius: 5.5))
                }.buttonStyle(.plain).accessibilityLabel("Remove \(job.filename)")
                    .transition(actionTransition(from: .leading))
            }
            Text(job.filename).font(AiruStyle.text(13, .light)).lineLimit(1).truncationMode(.middle)
                .frame(minWidth: 50, maxWidth: .infinity, alignment: .leading).help(job.filename)
            HStack(spacing: 10) {
                status
                if actionsVisible {
                    HStack(spacing: 10) {
                        FormatSelector(value: job.requestedFormat, caption: "Format for \(job.filename)", compact: true,
                                       jpegAllowed: job.canUseJPEG, onPresentationChange: { formatMenuPresented = $0 }) {
                            model.setFormat($0, for: job)
                        }
                        Button { Task { await model.chooseDestination(for: job) } } label: {
                            DesignAsset(name: "FolderOpen", width: 14, height: 10.7569).frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain).background(AiruStyle.control, in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel("Export destination for \(job.filename)")
                        .help((job.destinationOverride ?? model.destinations.defaultURL).path)
                        if job.status == .completed {
                            rowAction("Show") { model.reveal(job) }
                        } else if [.failed, .cancelled].contains(job.status) {
                            rowAction("Retry") { model.retry(job) }
                        } else {
                            rowAction("Airufy") { model.export(job) }.disabled(!job.canExport && !job.canCompress)
                                .accessibilityLabel("Compress \(job.filename)")
                        }
                    }
                    .transition(actionTransition(from: .trailing))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: AiruStyle.rowHeight)
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: expanded)
        // Export can hide the actions without changing hover or keyboard focus.
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: actionsVisible)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .focusable().focused($focused)
        .onKeyPress(.delete) { model.remove(job); return .handled }
        .onKeyPress(.return) { if job.status == .completed { model.reveal(job) } else { model.export(job) }; return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(job.filename)
        .accessibilityValue(accessibilityStatus)
        .accessibilityAction(named: "Compress") { model.export(job) }
        .accessibilityAction(named: "Remove") { model.remove(job) }
        .accessibilityAction(named: "Reveal in Finder") { model.reveal(job) }
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
            if job.exportedURL != nil { Button("Reveal in Finder") { model.reveal(job) } }
            if job.error != nil { Button("Show error…") { showError = true } }
            Divider()
            Button("Remove") { model.remove(job) }
        }
        .alert("Couldn’t process \(job.filename)", isPresented: $showError) { Button("OK") {} } message: { Text(job.error?.message ?? "") }
    }
    private func actionTransition(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity.animation(.easeOut(duration: 0.12)) : .move(edge: edge).combined(with: .opacity)
    }
    @ViewBuilder private var status: some View {
        switch job.status {
        case .queued:
            Text("In queue").font(AiruStyle.text()).foregroundStyle(AiruStyle.muted)
        case .analyzing, .optimizing:
            HStack(spacing: 5) {
                AiruSpinner()
                Text(job.status == .analyzing ? "Analyzing" : "\(Int(job.progress * 100))%")
                    .font(AiruStyle.text()).foregroundStyle(AiruStyle.yellow).monospacedDigit()
            }
        case .exporting:
            HStack(spacing: 5) {
                AiruSpinner()
                Text("Saving…").font(AiruStyle.text()).foregroundStyle(AiruStyle.yellow)
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
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(FileSizeText.format(result.source.fileSize)).font(AiruStyle.text(13, .light)).foregroundStyle(AiruStyle.muted)
            Text("→").font(AiruStyle.text(14)).foregroundStyle(AiruStyle.muted)
            if result.alreadyOptimized {
                Text("Already optimized").font(AiruStyle.text(12)).foregroundStyle(AiruStyle.muted)
            } else {
                Text(FileSizeText.format(result.outputSize)).font(AiruStyle.text()).foregroundStyle(AiruStyle.success)
                Text(String(format: "(%@%.0f%%)", result.savingsPercentage >= 0 ? "−" : "+", abs(result.savingsPercentage)))
                    .font(AiruStyle.text(10)).foregroundStyle(result.savingsPercentage >= 0 ? AiruStyle.green.opacity(0.66) : AiruStyle.yellow)
            }
        }.monospacedDigit()
    }
}
