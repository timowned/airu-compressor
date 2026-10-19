import SwiftUI
import AppKit
import AiruCore

struct FormatSelector: View {
    let value: OutputFormat
    var caption: String? = nil
    var compact = false
    let jpegAllowed: Bool
    var onPresentationChange: ((Bool) -> Void)? = nil
    let select: (OutputFormat) -> Void
    @State private var isPresented = false
    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: compact ? 5 : 0) {
                HStack(spacing: 6) {
                    Text(value.label).font(AiruStyle.text(compact ? 11 : 13, .medium))
                    if !compact { Text("Airy").font(AiruStyle.text(13, .light)).foregroundStyle(.white.opacity(0.5)) }
                }.fixedSize(horizontal: true, vertical: false)
                if !compact { Spacer(minLength: 10) }
                Image(systemName: "chevron.down").font(.system(size: compact ? 8 : 11, weight: .bold))
                    .frame(width: compact ? 14 : 30, height: compact ? 20 : 30)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6.5))
            }
            .lineLimit(1).padding(.leading, compact ? 6 : 10).padding(.trailing, 2)
            .frame(width: compact ? nil : 118, height: compact ? 26 : 36)
            .background(AiruStyle.control, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AiruStyle.controlBorder))
            .padding(1).background(Color(white: 19/255), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .accessibilityLabel(caption ?? "Output format").accessibilityValue(value.label)
        .background(FormatMenuAnchor(isPresented: $isPresented, value: value, jpegAllowed: jpegAllowed, select: select))
        .onChange(of: isPresented) { _, presented in onPresentationChange?(presented) }
        .contextMenu { Button("Use Auto format") { select(.auto) } }
    }
}

/// Exact Figma panel: 260×148, 10-point inset, 35-point choices, no system arrow.
private struct FormatMenuContent: View {
    let value: OutputFormat
    let jpegAllowed: Bool
    let select: (OutputFormat) -> Void
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Format", opacity: 0.7)
                HStack(spacing: 2) {
                    ForEach([OutputFormat.jpeg, .avif, .webp, .png], id: \.self) { format in
                        choice(format.label, selected: value == format, enabled: format != .jpeg || jpegAllowed) {
                            dismiss(); select(format)
                        }
                        .help(format == .jpeg && !jpegAllowed ? "JPEG cannot preserve transparency" : format.label)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Mode", opacity: 0.8)
                HStack(spacing: 2) {
                    choice("Airy", selected: true) { dismiss() }
                    choice("Superlight", selected: false, enabled: false) {}.help("Coming soon...")
                }
            }
        }
        .padding(10).frame(width: 260, height: 148)
        .background(AiruStyle.control, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AiruStyle.controlBorder, lineWidth: 1))
        .preferredColorScheme(.dark).onExitCommand(perform: dismiss)
    }
    private func sectionLabel(_ text: String, opacity: Double) -> some View {
        Text(text).font(AiruStyle.text(13)).foregroundStyle(.white.opacity(opacity)).frame(height: 10)
    }
    private func choice(_ label: String, selected: Bool, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(AiruStyle.text(13, .medium)).lineLimit(1)
                .foregroundStyle(selected ? Color.white : Color(white: 165/255))
                .frame(maxWidth: .infinity).frame(height: 35)
                .background(selected ? Color(white: 53/255) : .clear, in: RoundedRectangle(cornerRadius: 6))
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
    let jpegAllowed: Bool
    let select: (OutputFormat) -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.dismissBinding = { isPresented = false }
        if isPresented {
            context.coordinator.present(from: view, value: value, jpegAllowed: jpegAllowed, select: select)
        } else { context.coordinator.close() }
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.close() }

    @MainActor final class Coordinator {
        var dismissBinding: (() -> Void)?
        private var panel: NSPanel?
        private var localMonitor: Any?
        private var globalMonitor: Any?
        private var observers: [NSObjectProtocol] = []
        func present(from anchor: NSView, value: OutputFormat, jpegAllowed: Bool, select: @escaping (OutputFormat) -> Void) {
            guard panel == nil, let window = anchor.window else { return }
            let anchorRect = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
            let panel = FormatPanel(contentRect: NSRect(x: anchorRect.minX, y: anchorRect.maxY + 10, width: 260, height: 148),
                                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Output format"; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = false; panel.level = .popUpMenu; panel.hidesOnDeactivate = true
            panel.animationBehavior = .none
            let dismiss: () -> Void = { [weak self] in self?.dismiss() }
            panel.cancel = dismiss
            let host = NSHostingView(rootView: FormatMenuContent(value: value, jpegAllowed: jpegAllowed, select: select, dismiss: dismiss))
            if #available(macOS 15.0, *) { host.safeAreaRegions = [] }
            panel.contentView = host
            self.panel = panel
            window.addChildWindow(panel, ordered: .above)
            panel.makeKeyAndOrderFront(nil)
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
            panel = nil
        }
    }
}

private final class FormatPanel: NSPanel {
    var cancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { cancel?() }
}
