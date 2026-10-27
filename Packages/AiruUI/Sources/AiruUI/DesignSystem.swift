import SwiftUI

/// Values measured from Airu / Auto Mode in Figma (640 × 430).
enum AiruStyle {
    static let background = Color(red: 21/255, green: 21/255, blue: 21/255)
    static let dropBackground = Color(red: 18/255, green: 18/255, blue: 18/255)
    static let border = Color(white: 0.2)
    static let control = Color(white: 30/255)
    static let controlBorder = Color(white: 39/255)
    static let muted = Color.white.opacity(0.5)
    static let green = Color(red: 100/255, green: 220/255, blue: 33/255)
    static let yellow = Color(red: 1, green: 222/255, blue: 0)
    static let success = LinearGradient(colors: [Color(red: 145/255, green: 220/255, blue: 33/255),
                                                Color(red: 36/255, green: 220/255, blue: 33/255)], startPoint: .leading, endPoint: .trailing)
    static let inset: CGFloat = 20
    static let headerHeight: CGFloat = 58
    static let rowHeight: CGFloat = 50
    static func text(_ size: CGFloat = 13, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

struct AiruButtonStyle: ButtonStyle {
    var kind: Kind = .secondary
    enum Kind { case primary, secondary, success, working, destructive }
    func makeBody(configuration: Configuration) -> some View {
        AiruStyledButton(label: configuration.label, kind: kind, pressed: configuration.isPressed)
    }
}

private struct AiruStyledButton<Label: View>: View {
    let label: Label
    let kind: AiruButtonStyle.Kind
    let pressed: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    var body: some View {
        label
            .font(AiruStyle.text(13, .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background {
                RoundedRectangle(cornerRadius: 9).fill(background.opacity(pressed ? 0.75 : 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.black.opacity(kind == .primary && hovering && isEnabled ? 0.15 : 0))
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(kind == .primary ? Color(white: 19/255) : rim, lineWidth: 1))
            .padding(1)
            .background(kind == .primary ? Color(white: 102/255) : Color(white: 16/255), in: RoundedRectangle(cornerRadius: 10))
            .opacity(!isEnabled && kind == .secondary ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onHover { hovering = $0 }
    }
    private var rim: Color {
        switch kind {
        case .success: Color(red: 19/255, green: 53/255, blue: 12/255)
        case .destructive: Color(red: 91/255, green: 26/255, blue: 27/255)
        default: AiruStyle.controlBorder
        }
    }
    private var foreground: Color {
        switch kind { case .primary: .black; case .secondary: .white; case .success: AiruStyle.green; case .working: AiruStyle.yellow; case .destructive: Color(red: 1, green: 56/255, blue: 60/255) }
    }
    private var background: Color {
        switch kind {
        case .primary: Color(white: 237/255)
        case .secondary: AiruStyle.control
        case .success: Color(red: 13/255, green: 43/255, blue: 9/255)
        case .working: Color(red: 46/255, green: 42/255, blue: 13/255)
        case .destructive: Color(red: 76/255, green: 20/255, blue: 21/255)
        }
    }
}

extension View {
    func airuLiquidGlass() -> some View { modifier(AiruLiquidGlass()) }
}

private struct AiruLiquidGlass: ViewModifier {
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    func body(content: Content) -> some View {
        material(content)
            .overlay {
                Capsule().fill(.white.opacity(hovering && isEnabled ? 0.06 : 0))
                    .allowsHitTesting(false)
            }
            .contentShape(Capsule())
            .onHover { hovering = $0 }
    }
    @ViewBuilder private func material(_ content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct DesignAsset: View {
    let name: String
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        Image(name, bundle: .module).resizable().renderingMode(.original)
            .frame(width: width, height: height).accessibilityHidden(true)
    }
}

/// The original Figma spinner artwork, animated only while real work is active.
struct AiruSpinner: View {
    var button = false
    var analysis = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false
    var body: some View {
        Image(button ? "ButtonSpinner" : "RowSpinner", bundle: .module).resizable()
            .renderingMode(analysis ? .template : .original).foregroundStyle(.white)
            .frame(width: analysis ? 24 : (button ? 12 : 11), height: analysis ? 24 : (button ? 12 : 11))
            .rotationEffect(.degrees(rotating && !reduceMotion ? 360 : 0))
            .animation(reduceMotion ? nil : .timingCurve(0.42, 0, 0.58, 1, duration: 2).repeatForever(autoreverses: false), value: rotating)
            .onAppear { rotating = true }
    }
}

enum FileSizeText {
    static func format(_ bytes: Int64) -> String {
        if bytes < 1000 { return "\(bytes)B" }
        let unit = bytes < 1_000_000 ? "KB" : (bytes < 1_000_000_000 ? "MB" : "GB")
        let divisor: Double = unit == "KB" ? 1000 : (unit == "MB" ? 1_000_000 : 1_000_000_000)
        return String(format: "%.1f%@", Double(bytes) / divisor, unit)
    }
}
