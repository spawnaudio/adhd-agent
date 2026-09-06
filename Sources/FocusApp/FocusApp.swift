import AppKit
import SwiftUI
import Combine
import FocusCore

@MainActor
final class FocusStore: ObservableObject {
    @Published var session: FocusSession {
        didSet {
            if let data = try? JSONEncoder().encode(session) { defaults.set(data, forKey: "session.v1") }
        }
    }
    private let defaults = UserDefaults.standard
    init() {
        if let data = UserDefaults.standard.data(forKey: "session.v1"),
           let restored = try? JSONDecoder().decode(FocusSession.self, from: data) {
            session = restored
        } else { session = FocusSession() }
    }
    func tick() {
        if session.reconcile() { showWindow() }
    }
    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.title == "Focus" })?.makeKeyAndOrderFront(nil)
    }
}

@main
struct FocusApp: App {
    @StateObject private var store = FocusStore()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some Scene {
        Window("Focus", id: "focus") {
            FocusView(store: store)
                .onReceive(timer) { _ in store.tick() }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in store.tick() }
        }
        .defaultSize(width: 580, height: 720)
        MenuBarExtra("Focus", systemImage: "scope") {
            MenuContent(store: store)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var store: FocusStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(store.session.isActive ? (store.session.pauseUntil == nil ? "Focus in progress" : "Focus paused") : "Ready when you are")
        if store.session.isActive { Text(store.session.nextAction) }
        Button("Show Focus") { openWindow(id: "focus"); store.showWindow() }
        if store.session.pauseUntil != nil { Button("Resume focus") { store.session.resume(); openWindow(id: "focus"); store.showWindow() } }
        Divider()
        Button("Quit Focus") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

@MainActor
final class ViewState: ObservableObject {
    @Published var thought = ""
    @Published var showPause = false
    @Published var pauseMinutes = 5
    @Published var showSaved = false
    @Published var showEnd = false
}

struct FocusView: View {
    @ObservedObject var store: FocusStore
    @StateObject private var ui = ViewState()
    private let accent = Color(red: 0.30, green: 0.47, blue: 0.39)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Image(systemName: "scope").font(.title).foregroundStyle(accent)
                    Text("Focus").font(.title2.weight(.semibold))
                    Spacer()
                    Text("ONE THING AT A TIME").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                }
                if !store.session.isActive { setup } else { activeSession }
                Divider()
                savedIdeas
                Text("Your task and saved ideas stay on this Mac. Focus does not monitor or block other apps.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(32)
        }
        .frame(minWidth: 480, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .sheet(isPresented: $ui.showPause) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pause with a way back.").font(.title2.bold())
                Text("When the break ends, Focus will bring your next action back into view.").foregroundStyle(.secondary)
                Picker("Break length", selection: $ui.pauseMinutes) {
                    ForEach([5, 10, 15], id: \.self) { Text("\($0) minutes").tag($0) }
                }.pickerStyle(.segmented)
                HStack {
                    Button("Keep focusing", role: .cancel) { ui.showPause = false }
                    Spacer()
                    Button("Pause focus to continue") {
                        store.session.pause(minutes: ui.pauseMinutes)
                        ui.showPause = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding(28).frame(width: 420)
        }
        .confirmationDialog("End this focus session?", isPresented: $ui.showEnd, titleVisibility: .visible) {
            Button("End session") { store.session.end() }
            Button("Keep focusing", role: .cancel) {}
        } message: { Text("Your task and saved ideas will stay here.") }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What matters right now?").font(.largeTitle.weight(.semibold))
            Text("Bring one task here. Give yourself one place to start.").foregroundStyle(.secondary)
            Text("LINEAR ISSUE / TASK").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: $store.session.task)
                .font(.body).scrollContentBackground(.hidden)
                .padding(10).frame(height: 115)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                .accessibilityLabel("Paste a Linear issue, task text, or issue URL")
            Text("Paste the task text or issue link. A link alone won’t fetch its details.").font(.caption).foregroundStyle(.secondary)
            Text("FIRST SMALL ACTION").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField("e.g. Open the draft and write the first sentence", text: $store.session.nextAction)
                .textFieldStyle(.roundedBorder)
            Button { store.session.start() } label: {
                Label("Start focus", systemImage: "arrow.right").frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(.borderedProminent).disabled(!store.session.canStart)
        }
    }

    private var activeSession: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(store.session.pauseUntil == nil ? "Here’s your next step." : "Take your pause.")
                .font(.largeTitle.weight(.semibold))
            if let expiry = store.session.pauseUntil {
                HStack {
                    Image(systemName: "pause.circle")
                    Text("Back to focus in")
                    Text(expiry, style: .timer).monospacedDigit()
                }.foregroundStyle(.secondary)
            } else {
                Text("You can come back to this as often as you need.").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("NEXT ACTION").font(.caption.weight(.semibold)).foregroundStyle(accent)
                Text(store.session.nextAction).font(.title2.weight(.medium)).textSelection(.enabled)
                Divider()
                Text(store.session.task).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                if let url = store.session.linearURL { Link("Open issue in Linear ↗", destination: url) }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            HStack {
                if store.session.pauseUntil != nil {
                    Button("Resume focus") { store.session.resume() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Pause focus to continue") { ui.showPause = true }.buttonStyle(.bordered)
                }
                Spacer()
                Button("End session") { ui.showEnd = true }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Something else caught your attention?").font(.headline)
                Text("Leave it here for later.").font(.callout).foregroundStyle(.secondary)
                HStack {
                    TextField("An idea, app name, or link…", text: $ui.thought).textFieldStyle(.roundedBorder)
                        .onSubmit(saveThought)
                    Button("Save", action: saveThought).disabled(ui.thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var savedIdeas: some View {
        DisclosureGroup("Saved for later · \(store.session.thoughts.count)", isExpanded: $ui.showSaved) {
            VStack(alignment: .leading, spacing: 12) {
                if store.session.thoughts.isEmpty {
                    Text("Ideas you save during focus will be waiting here.").foregroundStyle(.secondary)
                }
                ForEach(store.session.thoughts) { item in
                    HStack(alignment: .top) {
                        Text(item.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            store.session.thoughts.removeAll { $0.id == item.id }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Delete saved idea")
                    }
                }
            }.padding(.top, 12)
        }
    }
    private func saveThought() { store.session.saveThought(ui.thought); ui.thought = "" }
}
