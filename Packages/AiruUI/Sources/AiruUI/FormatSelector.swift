import SwiftUI
import AppKit
import AiruCore
import Observation
import QuartzCore

struct FormatSelector: View {
    let value: OutputFormat
    let profile: CompressionProfile
    var caption: String? = nil
    var compact = false
    let jpegAllowed: Bool
    var onPresentationChange: ((Bool) -> Void)? = nil
    let select: (OutputFormat) -> Void
    let selectProfile: (CompressionProfile) -> Void
    @State private var isPresented = false
    @State private var hovering = false
    @State private var arrowHovered = false
    private var containerHovered: Bool { hovering && !arrowHovered && !isPresented }
    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: compact ? 5 : 8) {
                HStack(spacing: 6) {
                    Text(value.label).font(AiruStyle.text(compact ? 11 : 13, .medium))
                    if !compact { Text(profile.rawValue).font(AiruStyle.text(13, .light)).foregroundStyle(.white.opacity(0.5)) }
                }.fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.down").font(.system(size: compact ? 8 : 11, weight: .bold))
                    .frame(width: compact ? 14 : 30, height: compact ? 20 : 30)
                    .background(.white.opacity(arrowHovered && !isPresented ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 6.5))
                    .contentShape(Rectangle())
                    .onHover { arrowHovered = $0 }
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
                    .animation(.easeInOut(duration: 0.16), value: isPresented)
            }
            .lineLimit(1).padding(.leading, compact ? 6 : 10).padding(.trailing, 2)
            .frame(height: compact ? 26 : 36)
            .background(containerHovered ? Color(white: 39/255) : AiruStyle.control, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(containerHovered ? Color(white: 48/255) : AiruStyle.controlBorder))
            .padding(1).background(Color(white: 19/255), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .fixedSize(horizontal: true, vertical: false)
        .onHover {
            hovering = $0
            if !$0 { arrowHovered = false }
        }
        .accessibilityLabel(caption ?? "Output format").accessibilityValue("\(value.label), \(profile.rawValue)")
        .background(FormatMenuAnchor(isPresented: $isPresented, value: value, profile: profile, jpegAllowed: jpegAllowed, select: select, selectProfile: selectProfile))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 7 : 10))
        .onChange(of: isPresented) { _, presented in onPresentationChange?(presented) }
        .contextMenu { Button("Use Auto format") { select(.auto) } }
    }
}

@MainActor @Observable final class FormatMenuState {
    var value: OutputFormat
    var profile: CompressionProfile
    var jpegAllowed: Bool
    var select: (OutputFormat) -> Void
    var selectProfile: (CompressionProfile) -> Void
    init(value: OutputFormat, profile: CompressionProfile, jpegAllowed: Bool,
         select: @escaping (OutputFormat) -> Void, selectProfile: @escaping (CompressionProfile) -> Void) {
        self.value = value; self.profile = profile; self.jpegAllowed = jpegAllowed
        self.select = select; self.selectProfile = selectProfile
    }
}

/// Exact Figma panel: 260×156, 10-point inset, 35-point choices, no system arrow.
struct FormatMenuContent: View {
    @Bindable var state: FormatMenuState
    let dismiss: () -> Void
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.24)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Format", opacity: 0.7)
                HStack(spacing: 0) {
                    ForEach([OutputFormat.jpeg, .avif, .webp, .png], id: \.self) { format in
                        choice(format.label, selected: state.value == format, group: "format",
                               enabled: format != .jpeg || state.jpegAllowed) {
                            withAnimation(selectionAnimation) { state.value = format }
                            state.select(format)
                        }
                        .padding(2)
                        .overlay(alignment: .leading) {
                            if let index = [OutputFormat.jpeg, .avif, .webp, .png].firstIndex(of: format), index > 0,
                               state.value != format,
                               state.value != [OutputFormat.jpeg, .avif, .webp, .png][index - 1] {
                                Color(white: 34/255).frame(width: 1)
                            }
                        }
                        .help(format == .jpeg && !state.jpegAllowed ? "JPEG cannot preserve transparency" : format.label)
                    }
                }
                .background(Color(white: 24/255), in: RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Mode", opacity: 0.8)
                HStack(spacing: 2) {
                    ForEach(CompressionProfile.allCases, id: \.self) { profile in
                        choice(profile.rawValue, selected: state.profile == profile, group: "mode") {
                            withAnimation(selectionAnimation) { state.profile = profile }
                            state.selectProfile(profile)
                        }
                        .help("SSIMULACRA2 target \(Int(profile.minimumScore))")
                    }
                }
                .padding(2)
                .background(Color(white: 24/255), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(10).frame(width: 260, height: 156)
        .background(AiruStyle.control, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AiruStyle.controlBorder, lineWidth: 1))
        .animation(selectionAnimation, value: state.value)
        .animation(selectionAnimation, value: state.profile)
        .preferredColorScheme(.dark).onExitCommand(perform: dismiss)
    }
    private func sectionLabel(_ text: String, opacity: Double) -> some View {
        Text(text).font(AiruStyle.text(13)).foregroundStyle(.white.opacity(opacity)).frame(height: 10)
    }
    private func choice(_ label: String, selected: Bool, group: String,
                        enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(AiruStyle.text(13, .medium)).lineLimit(1)
                .foregroundStyle(selected ? Color.white : Color(white: 165/255))
                .frame(maxWidth: .infinity).frame(height: 35)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 6.5).fill(AiruStyle.controlBorder)
                            .matchedGeometryEffect(id: group, in: selection)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(FormatChoiceButtonStyle()).disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FormatChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A borderless native panel preserves the Figma geometry and opens above its anchor.
private struct FormatMenuAnchor: NSViewRepresentable {
    @Binding var isPresented: Bool
    let value: OutputFormat
    let profile: CompressionProfile
    let jpegAllowed: Bool
    let select: (OutputFormat) -> Void
    let selectProfile: (CompressionProfile) -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.dismissBinding = { isPresented = false }
        if isPresented {
            context.coordinator.present(from: view, value: value, profile: profile, jpegAllowed: jpegAllowed, select: select, selectProfile: selectProfile)
        } else { context.coordinator.close() }
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.close() }

    @MainActor final class Coordinator {
        var dismissBinding: (() -> Void)?
        private var panel: NSPanel?
        private var menuState: FormatMenuState?
        private var localMonitor: Any?
        private var globalMonitor: Any?
        private var observers: [NSObjectProtocol] = []
        func present(from anchor: NSView, value: OutputFormat, profile: CompressionProfile,
                     jpegAllowed: Bool, select: @escaping (OutputFormat) -> Void,
                     selectProfile: @escaping (CompressionProfile) -> Void) {
            if let menuState {
                menuState.value = value; menuState.profile = profile; menuState.jpegAllowed = jpegAllowed
                menuState.select = select; menuState.selectProfile = selectProfile
                return
            }
            guard let window = anchor.window else { return }
            let anchorRect = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
            let panel = FormatPanel(contentRect: NSRect(x: anchorRect.minX, y: anchorRect.maxY + 10, width: 260, height: 156),
                                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Output format"; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = false; panel.level = .popUpMenu; panel.hidesOnDeactivate = true
            panel.animationBehavior = .none
            let dismiss: () -> Void = { [weak self] in self?.dismiss() }
            panel.cancel = dismiss
            let state = FormatMenuState(value: value, profile: profile, jpegAllowed: jpegAllowed,
                                        select: select, selectProfile: selectProfile)
            menuState = state
            let host = NSHostingView(rootView: FormatMenuContent(state: state, dismiss: dismiss))
            if #available(macOS 15.0, *) { host.safeAreaRegions = [] }
            panel.contentView = host
            self.panel = panel
            let finalFrame = panel.frame
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            panel.alphaValue = 0
            if !reduceMotion { panel.setFrame(finalFrame.offsetBy(dx: 0, dy: -8), display: false) }
            window.addChildWindow(panel, ordered: .above)
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.12 : 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 1
                if !reduceMotion { panel.animator().setFrame(finalFrame, display: true) }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel, weak window] event in
                let consume = MainActor.assumeIsolated {
                    guard event.window !== panel else { return false }
                    self?.dismiss()
                    // Clicking the trigger again closes the menu without reopening it on mouse-up.
                    return event.window === window && anchorRect.contains(NSEvent.mouseLocation)
                }
                return consume ? nil : event
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.dismiss() }
            }
            for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification, NSWindow.willCloseNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.dismiss() }
                })
            }
            observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss() }
            })
        }
        func dismiss() { close(); dismissBinding?() }
        func close() {
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }; globalMonitor = nil
            for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
            if let panel {
                let parent = panel.parent
                let restoreKey = panel.isKeyWindow && NSApp.isActive
                parent?.removeChildWindow(panel); panel.orderOut(nil)
                if restoreKey { parent?.makeKey() }
            }
            panel = nil; menuState = nil
        }
    }
}

private final class FormatPanel: NSPanel {
    var cancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { cancel?() }
}
