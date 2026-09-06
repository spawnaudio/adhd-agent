import SwiftUI
import FocusFlowCore

struct FocusView: View {
    @ObservedObject var store: AppStore
    @State private var showingPause = false

    var body: some View {
        if let session = store.state.session {
            sessionView(session)
        } else {
            Surface {
                VStack(alignment: .leading, spacing: 22) {
                    Eyebrow(text: "One thing for a little while")
                    Text("Choose your starting point.").font(.system(size: 27, design: .serif))
                    if let task = store.selectedTask {
                        Picker("Task", selection: Binding(get: { store.selectedTask?.id ?? task.id }, set: { store.selectedTaskID = $0 })) {
                            ForEach(store.state.priorities) { Text($0.title).tag($0.id) }
                        }.frame(maxWidth: 520)
                        Text(task.nextAction.isEmpty ? "Add a next action in Plan before starting." : task.nextAction)
                            .font(.system(size: 16)).foregroundStyle(Palette.muted).lineSpacing(4)
                        HStack(spacing: 16) {
                            DurationPicker(minutes: $store.focusMinutes)
                            Button { store.startFocus() } label: { Label("Start focus", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle())
                                .disabled(task.nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button("Edit in Plan") { store.section = .plan }.buttonStyle(.plain).foregroundStyle(Palette.teal)
                        }
                    } else {
                        Text("Bring one task into your plan and give it a small next action. Then come back for a short focus session.")
                            .font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(5)
                        Button("Go to Plan") { store.section = .plan }.buttonStyle(PrimaryButtonStyle())
                    }
                    Divider()
                    Text("You can pause or finish at any time. The timer keeps its place when you close the window.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }.padding(.vertical, 12)
            }
        }
    }

    private func sessionView(_ session: FocusSession) -> some View {
        let phase = session.phase(at: store.now)
        let remaining = phase == .paused ? session.breakRemaining(at: store.now) : session.remaining(at: store.now)
        return VStack(spacing: 22) {
            Surface {
                HStack(alignment: .center, spacing: 36) {
                    ZStack {
                        Circle().stroke(Palette.pale, lineWidth: 10)
                        Circle().trim(from: 0, to: min(1, max(0, session.remaining(at: store.now) / session.duration)))
                            .stroke(Palette.teal, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 9) {
                            Eyebrow(text: phase == .paused ? "A little pause" : phase == .finished ? "A place to stop" : "Time for this")
                            Text(AppStore.clockText(remaining)).font(.system(size: 47, weight: .light, design: .monospaced)).monospacedDigit()
                            Text(phase == .paused ? "then back to your step" : phase == .finished ? "take a breath" : "one step at a time").font(.system(size: 11)).foregroundStyle(Palette.muted)
                        }
                    }.frame(width: 222, height: 222).padding(12)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(phase == .paused ? "Pause timer" : "Focus timer")
                        .accessibilityValue(AppStore.clockText(remaining))
                    VStack(alignment: .leading, spacing: 18) {
                        Eyebrow(text: phase == .finished ? "You made space for" : "Your one thing")
                        Text(session.taskTitle).font(.system(size: 28, design: .serif)).fixedSize(horizontal: false, vertical: true)
                        if phase == .finished {
                            Text("This block is complete. The task can be finished, or it can wait for another small step.")
                                .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                        } else {
                            Text(phase == .paused ? "Take your pause. Your next step will be here." : "You only need to do the action below.")
                                .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(4)
                        }
                        if phase == .paused {
                            Button { store.resume() } label: { Label("I'm ready to return", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle())
                        } else if phase == .running {
                            Button { showingPause = true } label: { Label("Pause focus", systemImage: "pause") }.buttonStyle(QuietButtonStyle())
                                .popover(isPresented: $showingPause) {
                                    VStack(alignment: .leading, spacing: 18) {
                                        Text("Make a little room.").font(.system(size: 22, design: .serif))
                                        Text("Choose a pause. Focus resumes when it ends.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                                        Picker("Pause length", selection: $store.pauseMinutes) {
                                            Text("5 min").tag(5); Text("10 min").tag(10); Text("15 min").tag(15)
                                        }.pickerStyle(.segmented).labelsHidden()
                                        Button("Confirm pause") { store.pause(); showingPause = false }.buttonStyle(PrimaryButtonStyle())
                                    }.padding(24).frame(width: 320)
                                }
                        } else {
                            HStack {
                                Button("Finish task") { store.finishTask(session.taskID) }.buttonStyle(PrimaryButtonStyle())
                                Button("Keep it in my plan") { store.endFocus(); store.section = .plan }.buttonStyle(QuietButtonStyle())
                            }
                        }
                        if session.completedSteps > 0 {
                            Text("\(session.completedSteps) small \(session.completedSteps == 1 ? "step" : "steps") taken.").font(.system(size: 11)).foregroundStyle(Palette.teal)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if phase != .finished {
                Surface(color: Palette.pale.opacity(0.55)) {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: session.nextAction.isEmpty ? "That step is done" : "The next small action")
                        if session.nextAction.isEmpty {
                            Text("A little progress. What comes next?").font(.system(size: 24, design: .serif))
                            TextField("One small next action…", text: $store.nextStepBuffer, axis: .vertical)
                                .textFieldStyle(.roundedBorder).font(.system(size: 14)).onSubmit { store.setNextStep() }
                            HStack {
                                Button("Use this step") { store.setNextStep() }.buttonStyle(PrimaryButtonStyle()).disabled(store.nextStepBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                Button("Finish the task") { store.finishTask(session.taskID) }.buttonStyle(QuietButtonStyle())
                            }
                        } else {
                            Text(session.nextAction).font(.system(size: 24, design: .serif)).fixedSize(horizontal: false, vertical: true).lineSpacing(4)
                            HStack {
                                Button { store.completeStep() } label: { Label("I did this step", systemImage: "checkmark") }.buttonStyle(PrimaryButtonStyle()).disabled(phase == .paused)
                                if let task = store.state.captures.first(where: { $0.id == session.taskID }), TaskLinks.linearURL(task.linearLink) != nil {
                                    Button { store.openTask(task) } label: { Label("Open task", systemImage: "arrow.up.right") }.buttonStyle(QuietButtonStyle())
                                }
                            }
                        }
                    }
                }
                HStack {
                    Button { store.resetVisible = true } label: { Label("I've drifted. Help me reset.", systemImage: "arrow.counterclockwise") }.buttonStyle(.plain).foregroundStyle(Palette.teal)
                    Spacer()
                    Button("End session") { store.endFocus() }.buttonStyle(.plain).foregroundStyle(Palette.muted)
                }.font(.system(size: 12)).padding(.horizontal, 4)
            }
        }
    }
}

struct ResetView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            Image(systemName: "wind").font(.system(size: 32, weight: .light)).foregroundStyle(Palette.teal)
            Text("You're here now.\nThat's a place to begin.").font(.system(size: 32, design: .serif))
            Text("If it helps, take a sip of water or loosen your shoulders. Give yourself a quiet moment.")
                .font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(6)
            Surface(color: Palette.pale.opacity(0.7)) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "When you're ready")
                    Text(store.state.session?.nextAction.isEmpty == false ? store.state.session!.nextAction : "Choose one small next action. That's enough.")
                        .font(.system(size: 21, design: .serif)).lineSpacing(4)
                }
            }
            HStack {
                Button("Back to my step") { store.resetVisible = false; store.section = .focus }.buttonStyle(PrimaryButtonStyle())
                Button("Close") { store.resetVisible = false }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
            }
        }.padding(36).frame(width: 465).background(Palette.canvas).foregroundStyle(Palette.ink)
    }
}

struct DraftsView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 22) {
                Surface {
                    VStack(alignment: .leading, spacing: 17) {
                        Eyebrow(text: "What you want to say")
                        Picker("Format", selection: $store.state.draftKind) {
                            ForEach(DraftKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        NoteEditor(text: $store.state.draftNotesBuffer, placeholder: "Rough notes are enough. Who is it for? What do they need to know?", height: 240)
                        Button {
                            store.ask(title: "A draft to make your own", prompt: "Draft a concise \(store.state.draftKind.rawValue.lowercased()) from these notes. Return only the draft. Keep it warm and professional. Do not invent facts, names, deadlines, progress, or commitments. Do not send anything.\n\n\(store.state.draftNotesBuffer)", isDraft: true)
                        } label: { Label("Help me write it", systemImage: "sparkles") }.buttonStyle(PrimaryButtonStyle())
                            .disabled(store.state.draftNotesBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.frame(maxWidth: .infinity)
                Surface {
                    VStack(alignment: .leading, spacing: 17) {
                        Eyebrow(text: "Your words, ready to go")
                        Text("Edit it until it sounds like you.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        NoteEditor(text: $store.state.draftBodyBuffer, placeholder: "Write here, or ask your companion for a first draft…", height: 255)
                        HStack {
                            Button { store.copy(store.state.draftBodyBuffer) } label: { Label("Copy", systemImage: "doc.on.doc") }.buttonStyle(PrimaryButtonStyle())
                            Button("Save a copy") { store.saveDraft() }.buttonStyle(QuietButtonStyle())
                        }.disabled(store.state.draftBodyBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.frame(maxWidth: .infinity)
            }
            Text("Nothing is sent from here. Review your draft, then copy it to the app you use.").font(.system(size: 12)).foregroundStyle(Palette.muted)
            if !store.state.drafts.isEmpty {
                Eyebrow(text: "Saved copies")
                ForEach(store.state.drafts) { draft in
                    Surface {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Text(draft.kind.rawValue).font(.system(size: 12, weight: .medium))
                                Text(draft.createdAt, format: .dateTime.day().month(.abbreviated)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                Spacer()
                                Button("Copy") { store.copy(draft.body) }.buttonStyle(QuietButtonStyle())
                            }
                            Text(draft.body).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}

struct SuggestionView: View {
    @ObservedObject var store: AppStore
    let request: Suggestion
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Eyebrow(text: "From your Focus & Flow agent")
            Text(request.title).font(.system(size: 27, design: .serif))
            if store.isThinking {
                VStack(spacing: 18) {
                    ProgressView().controlSize(.small)
                    Text("Making a little room to think…").font(.system(size: 13)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, minHeight: 220)
            } else if let error = store.suggestionError {
                Label(error, systemImage: "wifi.exclamationmark").font(.system(size: 14)).lineSpacing(5).frame(minHeight: 160)
            } else {
                Text("A suggestion for you to review. Edit it before using it.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                NoteEditor(text: $store.suggestionText, placeholder: "Suggestion", height: 230)
            }
            HStack {
                if !store.isThinking && store.suggestionError == nil {
                    if request.taskID != nil || request.isDraft {
                        Button(request.isDraft ? "Use this draft" : "Use as next action") { store.applySuggestion() }.buttonStyle(PrimaryButtonStyle())
                            .disabled(store.suggestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Button("Copy") { store.copy(store.suggestionText) }.buttonStyle(QuietButtonStyle())
                }
                Spacer()
                Button(store.isThinking ? "Cancel" : "Close") { store.cancelSuggestion() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
            }
        }.padding(30).frame(width: 540).background(Palette.canvas).foregroundStyle(Palette.ink)
    }
}

struct SettingsView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Eyebrow(text: "A little more help")
            Text("Your companion, connected.").font(.system(size: 29, design: .serif))
            Text("Capture, planning, drafts, and the timer work on this Mac. Connect your existing Focus Flow agent when you want help with the next step or the words.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
            Toggle("Enable agent suggestions", isOn: $store.state.agentEnabled).toggleStyle(.switch)
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("Local server port").font(.system(size: 12))
                    TextField("8000", text: $store.state.agentPort).textFieldStyle(.roundedBorder).frame(width: 85)
                        .disabled(store.checkingConnection)
                        .onChange(of: store.state.agentPort) { _, _ in store.connectionStatus = "Not checked" }
                    Spacer()
                    Button(store.checkingConnection ? "Checking…" : "Check connection") { store.checkConnection() }
                        .buttonStyle(QuietButtonStyle()).disabled(store.checkingConnection)
                }
                Text(store.connectionStatus).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                Text("Start the companion with the included “Start Companion.command” launcher, then check the connection here.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
            }.padding(18).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            Label {
                Text("When you ask for help, the relevant text goes to your existing agent and its Gemini service. Google Cloud processing and the agent's logging may apply. Other notes aren't attached automatically.")
                    .font(.system(size: 12)).lineSpacing(4)
            } icon: { Image(systemName: "arrow.up.right.square").foregroundStyle(Palette.teal) }
            Divider()
            Text("This version uses pasted Linear links and doesn't monitor your browsing.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
            HStack {
                Spacer()
                Button("Done") { store.settingsVisible = false }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 535).background(Palette.canvas).foregroundStyle(Palette.ink)
    }
}
