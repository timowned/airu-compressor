import SwiftUI

struct ThumbnailAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

struct ThumbnailPreviewLayout {
    let thumbnail: CGRect
    let frame: CGRect
    init(thumbnail: CGRect, viewport: CGSize) {
        self.thumbnail = thumbnail
        // Three 50-point rows, two intervening dividers, and six-point insets.
        let side = max(1, min(AiruStyle.rowHeight * 3 + 2 - 12, viewport.width, viewport.height - 12))
        let rowTop = thumbnail.midY - AiruStyle.rowHeight / 2
        var y = rowTop + 6
        if y + side > viewport.height - 6 {
            y = rowTop + AiruStyle.rowHeight - 6 - side
        }
        frame = CGRect(x: min(max(0, thumbnail.minX), max(0, viewport.width - side)),
                       y: min(max(6, y), max(6, viewport.height - side - 6)), width: side, height: side)
    }
    func imageFrame(at progress: CGFloat) -> CGRect {
        let p = min(1, max(0, progress))
        let side = thumbnail.width + (frame.width - thumbnail.width) * p
        let center = CGPoint(x: thumbnail.midX + (frame.midX - thumbnail.midX) * p,
                             y: thumbnail.midY + (frame.midY - thumbnail.midY) * p)
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }
}

/// Center-based scaling and translation start at the exact small-image bounds.
struct ThumbnailPreviewTransform: AnimatableModifier {
    var progress: CGFloat
    let layout: ThumbnailPreviewLayout
    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let current = layout.imageFrame(at: progress)
        let scale = current.width / layout.frame.width
        content
            .scaleEffect(scale, anchor: .center)
            .offset(x: current.midX - layout.frame.midX, y: current.midY - layout.frame.midY)
    }
}

struct LargeThumbnailPreview: View {
    let job: ImageJobViewModel
    let thumbnail: CGImage
    let layout: ThumbnailPreviewLayout
    let dismiss: () -> Void
    @State private var detailedImage: CGImage?
    var body: some View {
        Button(action: dismiss) {
            Image(decorative: detailedImage ?? thumbnail, scale: 2).resizable().scaledToFill()
                .frame(width: layout.frame.width, height: layout.frame.height)
                .clipped()
                .background(AiruStyle.control)
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(white: 44/255), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .focusEffectDisabled()
        .accessibilityLabel("Close preview of \(job.filename)")
        .task(id: job.info?.contentSHA256) {
            guard let identity = job.info?.contentSHA256 else { return }
            let image = await ImageThumbnailLoader.shared.image(at: job.sourceURL, contentIdentity: identity, maximumPixels: 512)
            guard !Task.isCancelled else { return }
            detailedImage = image
        }
    }
}
