import AppKit
import SwiftUI
import AiruUI

@main enum AiruApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let model = CompressionViewModel()
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the running Dock tile explicitly, including launches from a rebuilt local bundle.
        if let iconURL = Bundle.main.url(forResource: "AiruIcon", withExtension: "icns")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            // Keep the logical size consistent with macOS app icons while retaining
            // every bitmap representation for Retina and Dock magnification.
            icon.size = NSSize(width: 128, height: 128)
            NSApp.applicationIconImage = icon
        }
        installMenus()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 430),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Airu"
        window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false; window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 640, height: 430)
        let host = NSHostingView(rootView: MainWindow(model: model).clipShape(RoundedRectangle(cornerRadius: 22)).ignoresSafeArea())
        host.safeAreaRegions = []
        window.contentView = host
        window.setFrame(NSRect(x: 0, y: 0, width: 640, height: 430), display: false)
        window.center(); window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        importLaunchArguments()
    }
    private func installMenus() {
        let bar = NSMenu()
        let application = NSMenuItem(); bar.addItem(application); application.submenu = NSMenu()
        application.submenu?.addItem(withTitle: "About Airu", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        application.submenu?.addItem(.separator())
        application.submenu?.addItem(withTitle: "Quit Airu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let file = NSMenuItem(); bar.addItem(file); file.submenu = NSMenu(title: "File")
        let add = file.submenu!.addItem(withTitle: "Add Images…", action: #selector(addImages), keyEquivalent: "o"); add.target = self
        let save = file.submenu!.addItem(withTitle: "Airufy All", action: #selector(compressAll), keyEquivalent: "s"); save.target = self
        let folder = file.submenu!.addItem(withTitle: "Choose Export Folder…", action: #selector(chooseFolder), keyEquivalent: "e")
        folder.target = self; folder.keyEquivalentModifierMask = [.command, .shift]
        file.submenu?.addItem(.separator())
        file.submenu?.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenuItem(); bar.addItem(edit); edit.submenu = NSMenu(title: "Edit")
        edit.submenu?.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.submenu?.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.submenu?.addItem(.separator())
        edit.submenu?.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.submenu?.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.submenu?.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.submenu?.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let window = NSMenuItem(); bar.addItem(window); window.submenu = NSMenu(title: "Window")
        window.submenu?.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.submenu?.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.mainMenu = bar; NSApp.windowsMenu = window.submenu
    }
    @objc private func addImages() { model.browseFiles() }
    @objc private func compressAll() { model.exportAll() }
    @objc private func chooseFolder() { Task { await model.chooseDestination() } }
    func application(_ sender: NSApplication, open urls: [URL]) { model.importFiles(urls) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { model.cancelAll() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.cancelAll()
        Task { try? await model.waitUntilIdle(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    private func importLaunchArguments() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let index = arguments.firstIndex(of: "--destination"), arguments.indices.contains(index + 1) {
            try? model.destinations.setDefault(URL(fileURLWithPath: arguments[index + 1]), persist: false)
        }
        if let index = arguments.firstIndex(of: "--import") {
            let paths = arguments[(index + 1)...].prefix { !$0.hasPrefix("--") }
            model.importFiles(paths.map { URL(fileURLWithPath: $0) })
        }
    }
}
