import AppKit
import SwiftUI
import Combine
import FocusFlowCore

@main
struct FocusFlowMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = ApplicationDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var store: AppStore!
    private var statusItem: NSStatusItem!
    private var subscriptions: Set<AnyCancellable> = []
    private var renderingDirectory: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--check-companion") {
            NSApplication.shared.setActivationPolicy(.prohibited)
            Task {
                let server = CompanionServer()
                do {
                    let port = arguments.firstIndex(of: "--port").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "8000"
                    try await server.ensureRunning(port: port)
                    let client = try CompanionClient(port: port)
                    try await client.checkConnection()
                    let reply = try await client.suggest(prompt: "We are turning you, Focus & Flow, into a native macOS assistant. The user chose four areas: Brain Dump, Plan, Focus, and Drafts. The first version saves raw thoughts; lets the user choose at most three priorities; shows one small next action; runs a local timer with deliberate pauses; and provides editable communication drafts to copy. Your suggestions are optional and never send messages or start timers automatically. Safari distraction checkpoints are a later milestone. Please help direct this app by giving up to three brief, practical interaction recommendations consistent with your existing companion principles. Do not give medical advice or invent implemented capabilities.")
                    print(reply)
                    let conversationID = UUID()
                    _ = try await client.chat(prompt: "For this test, remember the task code mint-leaf. Briefly acknowledge it.", conversationID: conversationID)
                    let followUp = try await client.chat(prompt: "What task code did I just give you? Reply with the code only.", conversationID: conversationID)
                    guard followUp.lowercased().contains("mint-leaf") else { throw CompanionError.emptyReply }
                    print("Native conversation continuity passed.")
                    server.stop()
                    exit(0)
                } catch {
                    print("Companion check failed: \(error.localizedDescription)")
                    server.stop()
                    exit(1)
                }
            }
            return
        }
        if let i = arguments.firstIndex(of: "--render-previews"), arguments.count > i + 1 {
            renderingDirectory = URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let repository = WorkspaceRepository(fileURL: appSupport.appendingPathComponent("FocusFlow/workspace.json"))
        store = AppStore(repository: renderingDirectory == nil ? repository : nil, sample: renderingDirectory != nil)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1210, height: 850),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Focus & Flow"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Palette.canvas)
        window.minSize = NSSize(width: 950, height: 730)
        if renderingDirectory == nil { window.setFrameAutosaveName("FocusFlowMainWindow") }
        window.contentView = NSHostingView(rootView: ContentView(store: store))
        window.center()
        installMenu()
        installStatusItem()
        showWindow()
        if let renderingDirectory { renderPreviews(to: renderingDirectory) }
    }

    func applicationWillTerminate(_ notification: Notification) { store?.stopCompanion() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    private func installMenu() {
        let main = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "About Focus & Flow", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        item("Companion Settings…", action: #selector(settings), key: ",", to: app)
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Focus & Flow", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Focus & Flow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = app; main.addItem(appItem)

        let file = NSMenu(title: "File")
        item("Capture a Thought", action: #selector(capture), key: "n", to: file)
        item("Show Window", action: #selector(showWindow), key: "0", to: file)
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: ""); fileItem.submenu = file; main.addItem(fileItem)

        let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        let redo = edit.insertItem(withTitle: "Redo", action: NSSelectorFromString("redo:"), keyEquivalent: "z", at: 1)
        redo.keyEquivalentModifierMask = [.command, .shift]
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editItem.submenu = edit; main.addItem(editItem)

        let view = NSMenu(title: "View")
        for (index, section) in AppSection.allCases.enumerated() {
            let entry = item(section.rawValue, action: #selector(navigate(_:)), key: String(index + 1), to: view)
            entry.tag = index
        }
        let viewItem = NSMenuItem(title: "View", action: nil, keyEquivalent: ""); viewItem.submenu = view; main.addItem(viewItem)
        NSApplication.shared.mainMenu = main
    }

    @discardableResult private func item(_ title: String, action: Selector, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        entry.target = self
        return entry
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "leaf", accessibilityDescription: "Focus & Flow")
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        item("Open Focus & Flow", action: #selector(showWindow), to: menu)
        item("Capture a Thought", action: #selector(capture), to: menu)
        item("Return to Focus", action: #selector(focus), to: menu)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Focus & Flow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
        store.$now.sink { [weak self] date in
            guard let self else { return }
            if let session = self.store.state.session {
                let phase = session.phase(at: date)
                let time = phase == .paused ? session.breakRemaining(at: date) : session.remaining(at: date)
                self.statusItem.button?.title = phase == .finished ? " Done" : " \(phase == .paused ? "Ⅱ " : "")\(AppStore.clockText(time))"
            } else { self.statusItem.button?.title = "" }
        }.store(in: &subscriptions)
    }

    @objc private func showWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    @objc private func capture() { store.section = .capture; showWindow() }
    @objc private func focus() { store.section = .focus; showWindow() }
    @objc private func settings() { store.settingsVisible = true; showWindow() }
    @objc private func navigate(_ sender: NSMenuItem) { store.section = AppSection.allCases[sender.tag] }

    private func renderPreviews(to directory: URL) {
        // Render only this app's own view hierarchy, with synthetic data and no persisted workspace.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let samples = store.state
        let sections: [(String, AppSection)] = [("plan", .plan), ("brain-dump", .capture), ("focus", .focus), ("drafts", .drafts), ("plan-empty", .plan), ("focus-empty", .focus), ("plan-compact", .plan)]
        func render(_ index: Int) {
            guard index < sections.count else { NSApplication.shared.terminate(nil); return }
            if index == 4 { store.state = WorkspaceState() }
            if index == 6 {
                store.state = samples
                window.setContentSize(NSSize(width: 950, height: 730))
            }
            store.section = sections[index].1
            if index == 2 { store.startFocus() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                guard let view = window.contentView else { return }
                view.layoutSubtreeIfNeeded()
                if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    if let data = bitmap.representation(using: .png, properties: [:]) {
                        try? data.write(to: directory.appendingPathComponent("\(sections[index].0).png"))
                    }
                }
                render(index + 1)
            }
        }
        render(0)
    }
}
