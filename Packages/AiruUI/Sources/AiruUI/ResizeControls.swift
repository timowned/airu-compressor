import SwiftUI
import AiruCore

/// Empty fields are automatic; two explicit values request an exact crop frame.
struct ResolutionDraft {
    var width = ""
    var height = ""
    var baseWidth: Int
    var baseHeight: Int
    mutating func commitDimensions() throws -> (width: Int, height: Int) {
        let target = try dimensions()
        if !width.isEmpty && !height.isEmpty {
            baseWidth = target.width; baseHeight = target.height
        }
        return target
    }
    func dimensions() throws -> (width: Int, height: Int) {
        func parse(_ text: String) throws -> Int? {
            if text.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
            guard let value = Int(text), (1...65500).contains(value) else {
                throw AiruError("invalidDimensions", "Resolution must contain positive whole pixels")
            }
            return value
        }
        let w = try parse(width), h = try parse(height)
        let target: (Int, Int)
        switch (w, h) {
        case (let w?, let h?): target = (w, h)
        case (let w?, nil): target = (w, max(1, Int((Double(w) * Double(baseHeight) / Double(baseWidth)).rounded())))
        case (nil, let h?): target = (max(1, Int((Double(h) * Double(baseWidth) / Double(baseHeight)).rounded())), h)
        case (nil, nil): target = (baseWidth, baseHeight)
        }
        try ResizeOptions.resolution(width: target.0, height: target.1).validate()
        return target
    }
}

/// Commits on Return or focus loss, allowing intermediate text edits without launching work.
struct ResizeControls: View {
    let model: CompressionViewModel
    @Binding var alignmentPresented: Bool
    @State private var scale = "100%"
    @State private var scaleHovered = false
    @State private var resolution = ResolutionDraft(baseWidth: 1, baseHeight: 1)
    @FocusState private var field: Field?
    private enum Field: Hashable { case scale, width, height }
    private var reference: ImageInfo? {
        model.jobs.first(where: { $0.status != .completed && $0.info != nil })?.info ?? model.jobs.first?.info
    }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                label("Scale")
                HStack(spacing: 0) {
                    TextField("100%", text: $scale).focused($field, equals: .scale)
                        .padding(.leading, 10).onSubmit { commit(.scale) }
                        .accessibilityLabel("Scale percent")
                    Rectangle().fill(Color(white: 34/255)).frame(width: 1).opacity(scaleHovered ? 0 : 1)
                    VStack(spacing: 0) {
                        stepper("chevron.up", delta: 1)
                        stepper("chevron.down", delta: -1)
                    }.padding(.vertical, 2).frame(width: 24)
                }.frame(width: 80, height: 39).background(Color(white: 24/255), in: RoundedRectangle(cornerRadius: 8))
                    .onHover { scaleHovered = $0 }
            }
            VStack(alignment: .leading, spacing: 12) {
                label("Resolution (px)")
                HStack(spacing: 0) {
                    TextField("", text: $resolution.width).focused($field, equals: .width)
                        .multilineTextAlignment(.center).frame(width: 61.5, height: 39)
                        .overlay {
                            if resolution.width.isEmpty {
                                Text(automaticWidth).foregroundStyle(.white.opacity(0.2))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel("Output width in pixels").onSubmit { commit(.width) }
                    Rectangle().fill(Color(white: 34/255)).frame(width: 1)
                    TextField("", text: $resolution.height).focused($field, equals: .height)
                        .multilineTextAlignment(.center).frame(width: 61.5, height: 39)
                        .overlay {
                            if resolution.height.isEmpty {
                                Text(automaticHeight).foregroundStyle(.white.opacity(0.2))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel("Output height in pixels").onSubmit { commit(.height) }
                }.multilineTextAlignment(.center).frame(width: 124, height: 39)
                    .background(Color(white: 24/255), in: RoundedRectangle(cornerRadius: 8))
            }
            Button {
                if let field { commit(field) }
                field = nil
                alignmentPresented.toggle()
            } label: {
                CropAlignmentIcon(alignment: model.defaultResize?.alignment ?? .center,
                                  enabled: model.defaultResize?.isCustomResolution == true)
                    .frame(width: 39, height: 39)
                    .background(Color(white: 24/255), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(model.defaultResize?.isCustomResolution != true)
            .padding(.top, 21)
            .help("Crop alignment")
            .accessibilityLabel("Crop alignment")
            .accessibilityValue(model.defaultResize?.alignment.label ?? "Center")
        }
        .textFieldStyle(.plain).font(AiruStyle.text(13)).foregroundStyle(.white)
        .disabled(reference == nil)
        .onAppear { sync() }
        .onDisappear { if let field { commit(field) } }
        .onChange(of: model.defaultResize) { _, value in
            if value?.isCustomResolution != true { alignmentPresented = false }
            sync(preservingDraft: true)
        }
        .onChange(of: reference) { _, _ in sync() }
        .onChange(of: field) { old, _ in if let old { commit(old) } }
    }
    private func label(_ text: String) -> some View {
        Text(text).foregroundStyle(.white.opacity(0.8)).lineLimit(1).fixedSize(horizontal: true, vertical: false).frame(height: 9)
    }
    private func stepper(_ symbol: String, delta: Double) -> some View {
        Button {
            let current = Double(scale.replacingOccurrences(of: "%", with: "")) ?? 100
            set(.scale(min(10000, max(1, current + delta))))
        } label: {
            Image(systemName: symbol).font(.system(size: 8, weight: .bold)).frame(width: 21, height: 17.5)
        }.buttonStyle(ScaleStepperStyle()).accessibilityLabel(delta > 0 ? "Increase scale" : "Decrease scale")
    }
    private func set(_ value: ResizeOptions) {
        model.setDefaultResize(value == .scale(100) ? nil : value)
        sync()
    }
    private func commit(_ field: Field) {
        switch field {
        case .scale:
            guard scale != "Custom", let value = Double(scale.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) else { sync(); return }
            set(.scale(value))
        case .width, .height:
            do {
                let dimensions = try resolution.commitDimensions()
                model.setDefaultResize(.resolution(width: dimensions.width, height: dimensions.height,
                                                   alignment: model.defaultResize?.alignment ?? .center))
                sync(preservingDraft: true)
            } catch { model.alert = AiruError.wrapping(error) }
        }
    }
    private var automaticWidth: String {
        String((try? resolution.dimensions().width) ?? resolution.baseWidth)
    }
    private var automaticHeight: String {
        String((try? resolution.dimensions().height) ?? resolution.baseHeight)
    }
    private func sync(preservingDraft: Bool = false) {
        guard let info = reference else { return }
        let resize = model.defaultResize ?? .scale(100)
        guard let dimensions = try? resize.dimensions(width: info.width, height: info.height) else { return }
        let draft = try? resolution.dimensions()
        if !preservingDraft || draft?.width != dimensions.width || draft?.height != dimensions.height {
            resolution = ResolutionDraft(baseWidth: dimensions.width, baseHeight: dimensions.height)
        }
        if let percent = try? resize.percentage(width: info.width, height: info.height) {
            scale = String(format: "%g%%", percent)
        } else { scale = "Custom" }
    }
}

private struct ScaleStepperStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ScaleStepperAppearance(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct ScaleStepperAppearance<Label: View>: View {
    let label: Label
    let pressed: Bool
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        label
            .background(Color(white: pressed ? 0.23 : 0.19).opacity(enabled && (hovered || pressed) ? 1 : 0),
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovered = $0 }
    }
}
