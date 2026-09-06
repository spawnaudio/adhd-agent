import SwiftUI
import FocusFlowCore

enum Palette {
    static let canvas = Color(red: 0.965, green: 0.960, blue: 0.940)
    static let sidebar = Color(red: 0.938, green: 0.936, blue: 0.908)
    static let ink = Color(red: 0.17, green: 0.22, blue: 0.21)
    static let muted = Color(red: 0.39, green: 0.43, blue: 0.40)
    static let teal = Color(red: 0.18, green: 0.37, blue: 0.32)
    static let pale = Color(red: 0.89, green: 0.93, blue: 0.88)
    static let line = Color(red: 0.85, green: 0.86, blue: 0.82)
}

struct Surface<Content: View>: View {
    var color: Color = .white.opacity(0.83)
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line.opacity(0.55), lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(Palette.muted)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 17).padding(.vertical, 11)
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.8))
            .background(Palette.teal.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.42), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.teal).padding(.horizontal, 12).padding(.vertical, 9)
            .background(Palette.pale.opacity(configuration.isPressed ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ContentView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                topbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        switch store.section {
                        case .plan: PlanView(store: store)
                        case .capture: CaptureView(store: store)
                        case .focus: FocusView(store: store)
                        case .drafts: DraftsView(store: store)
                        }
                        if let notice = store.notice {
                            HStack {
                                Label(notice, systemImage: "checkmark.circle").font(.system(size: 12)).foregroundStyle(Palette.teal)
                                Spacer()
                                Button { store.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss message")
                            }.padding(.vertical, 4)
                        }
                    }
                    .padding(36).frame(maxWidth: 1040, alignment: .leading).frame(maxWidth: .infinity)
                }
            }.background(Palette.canvas)
        }
        .foregroundStyle(Palette.ink).tint(Palette.teal).preferredColorScheme(.light)
        .frame(minWidth: 940, minHeight: 680)
        .disabled(!store.canSave)
        .sheet(isPresented: $store.settingsVisible) { SettingsView(store: store) }
        .sheet(isPresented: $store.resetVisible) { ResetView(store: store) }
        .sheet(item: $store.suggestion, onDismiss: { store.cancelSuggestion() }) { request in
            SuggestionView(store: store, request: request)
        }
        .alert("A quick note", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill").font(.system(size: 23)).foregroundStyle(Palette.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("focus & flow").font(.system(size: 19, weight: .semibold, design: .serif))
                    Text("A little help, right here.").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }.padding(.top, 32).padding(.bottom, 46).padding(.horizontal, 22)
            Eyebrow(text: "Your space").padding(.horizontal, 24).padding(.bottom, 14)
            ForEach(AppSection.allCases) { section in
                Button { store.section = section; store.notice = nil } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.symbol).font(.system(size: 17)).frame(width: 23)
                        Text(section.rawValue).font(.system(size: 13, weight: store.section == section ? .semibold : .regular))
                        Spacer()
                        if section == .capture && !store.state.parked.isEmpty {
                            Text("\(store.state.parked.count)").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                        }
                        if section == .focus && store.activeSession { Circle().fill(Palette.teal).frame(width: 6, height: 6) }
                    }.padding(.horizontal, 14).padding(.vertical, 13)
                        .background(store.section == section ? Color.white.opacity(0.85) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 4)
                .accessibilityAddTraits(store.section == section ? .isSelected : [])
            }
            Spacer()
            if let session = store.state.session, session.phase(at: store.now) != .finished {
                Button { store.section = .focus } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(session.phase(at: store.now) == .paused ? "Taking a pause" : "One thing at a time", systemImage: "circle.dotted.circle")
                            .font(.system(size: 11, weight: .medium))
                        Text(AppStore.clockText(session.phase(at: store.now) == .paused ? session.breakRemaining(at: store.now) : session.remaining(at: store.now)))
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                        Text(session.taskTitle).font(.system(size: 11)).lineLimit(2)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.pale, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).padding(14)
            }
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "sparkle").foregroundStyle(Palette.teal)
                Text("You don't need to do\neverything at once.").font(.system(size: 15, design: .serif)).lineSpacing(4)
                Text("One small step is a start.").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }.padding(24).padding(.bottom, 18)
            Divider().overlay(Palette.line)
            Button { store.settingsVisible = true } label: {
                Label("Companion settings", systemImage: "slider.horizontal.3").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(22)
            }.buttonStyle(.plain)
        }.frame(width: 210).background(Palette.sidebar)
    }

    private var topbar: some View {
        HStack {
            Text("MY COMPANION").font(.system(size: 9, weight: .semibold)).tracking(1.6)
            Text("/").foregroundStyle(Palette.line).padding(.horizontal, 8)
            Text(store.section.rawValue).font(.system(size: 11))
            Spacer()
            Text(store.now, format: .dateTime.weekday(.wide).day().month(.abbreviated)).font(.system(size: 11))
        }.foregroundStyle(Palette.muted).padding(.horizontal, 36).frame(height: 58)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.section == .plan ? "A lighter kind of plan." : store.section.rawValue == "Focus" ? "A little space to focus." : store.section.rawValue)
                .font(.system(size: 34, weight: .regular, design: .serif))
            Text(store.section.subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted)
        }
    }
}

struct PlanView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Eyebrow(text: "Your priorities")
                    Text("\(store.state.priorities.count) of 3").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    Spacer()
                    Button { store.section = .capture } label: { Label("Add a thought", systemImage: "plus") }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.teal)
                }
                if store.state.priorities.isEmpty {
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "sun.horizon").font(.system(size: 32)).foregroundStyle(Palette.teal)
                            Text("What would make today a little lighter?").font(.system(size: 23, design: .serif))
                            Text("Start with a thought in Brain Dump, then bring one task here. Your plan has room for up to three.")
                                .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(4)
                            Button("Capture a first thought") { store.section = .capture }.buttonStyle(PrimaryButtonStyle())
                        }.padding(.vertical, 12)
                    }
                }
                ForEach(Array(store.state.priorities.enumerated()), id: \.element.id) { index, task in
                    priority(task, index: index)
                }
                if let task = store.selectedTask {
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: "Make it easier to start")
                            Text(task.title).font(.system(size: 18, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
                            Text("What's one physical action you can take in under five minutes?")
                                .font(.system(size: 12)).foregroundStyle(Palette.muted)
                            TextField("e.g. Open the document and write a title", text: Binding(
                                get: { store.state.captures.first { $0.id == task.id }?.nextAction ?? "" },
                                set: { store.updateTask(task.id, action: $0) }
                            ), axis: .vertical).textFieldStyle(.plain).font(.system(size: 14)).padding(13)
                                .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 9)).lineLimit(1...4)
                                .accessibilityLabel("Next action for \(task.title)")
                            HStack {
                                Button { store.askForStep(task) } label: { Label("Help me find a step", systemImage: "sparkles") }.buttonStyle(QuietButtonStyle())
                                Spacer()
                                Menu {
                                    Button("Mark task finished") { store.finishTask(task.id) }
                                    Button("Park for later") { store.park(task.id) }
                                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24).accessibilityLabel("Task options")
                            }
                            DisclosureGroup("Linear task link (optional)") {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("https://linear.app/…/issue/…", text: Binding(
                                        get: { store.state.captures.first { $0.id == task.id }?.linearLink ?? "" },
                                        set: { store.updateTask(task.id, link: $0) }
                                    )).textFieldStyle(.roundedBorder)
                                    if !task.linearLink.isEmpty && TaskLinks.linearURL(task.linearLink) == nil {
                                        Text("Use an HTTPS Linear issue link.").font(.caption).foregroundStyle(.orange)
                                    }
                                }.padding(.top, 8)
                            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Divider()
                            HStack {
                                DurationPicker(minutes: $store.focusMinutes)
                                Spacer()
                                Button { store.startFocus() } label: { Label(store.activeSession ? "Open focus" : "Start focus", systemImage: "play.fill") }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .disabled(!store.activeSession && task.nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
                let finished = store.state.captures.filter(\.completed)
                if !finished.isEmpty {
                    DisclosureGroup("Finished · \(finished.count)") {
                        ForEach(finished) { task in
                            HStack {
                                Label(task.title, systemImage: "checkmark.circle").lineLimit(2)
                                Spacer()
                                Button("Restore") {
                                    if let i = store.state.captures.firstIndex(where: { $0.id == task.id }) {
                                        store.state.captures[i].completed = false
                                        store.state.captures[i].planned = false
                                    }
                                }.buttonStyle(.plain).foregroundStyle(Palette.teal)
                            }.padding(.vertical, 8)
                        }
                    }.font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 20) {
                Surface(color: Palette.pale.opacity(0.75)) {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "leaf").font(.system(size: 36, weight: .ultraLight)).padding(.top, 6).foregroundStyle(Palette.teal)
                        Text("Small is\na good start.").font(.system(size: 27, design: .serif)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        Text("A starting point is enough. You can work out the rest when you get there.").font(.system(size: 12)).lineSpacing(5).foregroundStyle(Palette.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "Meet yourself where you are")
                    Text("How's your energy?").font(.system(size: 13, weight: .medium))
                    Picker("Energy", selection: $store.state.energy) {
                        Text("Low").tag("Low")
                        Text("Steady").tag("Steady")
                        Text("High").tag("High")
                    }.pickerStyle(.segmented).labelsHidden()
                    Text("Your companion uses this when suggesting a starting step.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
                }.padding(.horizontal, 4)
            }.frame(width: 218)
        }
    }

    private func priority(_ task: Capture, index: Int) -> some View {
        let selected = store.selectedTask?.id == task.id
        return Button { store.selectedTaskID = task.id } label: {
            HStack(alignment: .center, spacing: 14) {
                Text(String(format: "%02d", index + 1)).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Palette.muted)
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title).font(.system(size: 14, weight: .medium)).lineLimit(2)
                    Text(task.nextAction.isEmpty ? "Choose a small first step" : task.nextAction).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "arrow.up.right.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(selected ? Palette.teal : Palette.line)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? Palette.pale.opacity(0.6) : .white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Palette.teal.opacity(0.45) : Palette.line.opacity(0.6), lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct DurationPicker: View {
    @Binding var minutes: Int
    var body: some View {
        Menu {
            ForEach([5, 15, 25], id: \.self) { duration in
                Button("\(duration) minutes") { minutes = duration }
            }
        } label: {
            Label("\(minutes) min", systemImage: "timer")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.teal)
                .padding(.horizontal, 12).padding(.vertical, 9)
        }.menuStyle(.borderlessButton).frame(width: 110)
            .background(Palette.pale.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Focus duration").accessibilityValue("\(minutes) minutes")
    }
}

struct NoteEditor: View {
    @Binding var text: String
    let placeholder: String
    var height: CGFloat = 170
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty { Text(placeholder).foregroundStyle(Palette.muted.opacity(0.8)).padding(.horizontal, 7).padding(.vertical, 9).allowsHitTesting(false) }
            TextEditor(text: $text).scrollContentBackground(.hidden).padding(2).accessibilityLabel(placeholder)
        }.font(.system(size: 14)).lineSpacing(5).frame(minHeight: height).padding(12)
            .background(Palette.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line.opacity(0.6)))
    }
}

struct CaptureView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "No need to organize it yet")
                    NoteEditor(text: $store.state.brainDumpBuffer, placeholder: "A task, a thought, an entire tangle. Start anywhere…")
                    HStack {
                        Button { store.capture() } label: { Label("Save this thought", systemImage: "tray.and.arrow.down") }.buttonStyle(PrimaryButtonStyle())
                            .disabled(store.state.brainDumpBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button {
                            store.ask(title: "A little order", prompt: "Please organize this brain dump. Suggest at most three priorities, then a short parking lot. Do not invent deadlines or tasks. Keep it brief, and identify one easiest first action. These are suggestions for review.\n\n\(store.state.brainDumpBuffer)")
                        } label: { Label("Help me sort it", systemImage: "sparkles") }.buttonStyle(QuietButtonStyle())
                            .disabled(store.state.brainDumpBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        Text("Kept on this Mac").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }
                }
            }
            HStack {
                Eyebrow(text: "Safe for later")
                Text("\(store.state.parked.count)").font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                Text("Only bring it into your plan when you're ready.").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            if store.state.parked.isEmpty {
                Text("Your thoughts will be here. Nothing needs your attention yet.").font(.system(size: 13)).foregroundStyle(Palette.muted).padding(.vertical, 25)
            }
            ForEach(store.state.parked) { item in
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(item.text).font(.system(size: 14)).lineSpacing(4).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(item.createdAt, format: .dateTime.day().month(.abbreviated)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                            Spacer()
                            Button { store.promote(item.id) } label: { Label("Add to plan", systemImage: "arrow.up.right") }.buttonStyle(QuietButtonStyle())
                        }
                    }
                }
            }
        }
    }
}
