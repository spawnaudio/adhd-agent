import AppKit
import Combine
import FocusFlowCore
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case plan = "Plan", capture = "Brain Dump", focus = "Focus", drafts = "Drafts", companion = "Companion"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .plan: return "sun.max"
        case .capture: return "tray"
        case .focus: return "circle.dotted.circle"
        case .drafts: return "square.and.pencil"
        case .companion: return "bubble.left.and.bubble.right"
        }
    }
    var subtitle: String {
        switch self {
        case .plan: return "A little direction. Room to breathe."
        case .capture: return "Get it out of your head. Give it a place."
        case .focus: return "Just this task. Just the next step."
        case .drafts: return "Find the words. Make them yours."
        case .companion: return "A small next step. Someone to think with."
        }
    }
}

struct Suggestion: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let taskID: UUID?
    let isDraft: Bool
}

@MainActor
final class AppStore: ObservableObject {
    @Published var state: WorkspaceState { didSet { save() } }
    @Published var section: AppSection = .plan
    @Published var selectedTaskID: UUID?
    @Published var now = Date()
    @Published var error: String?
    @Published var notice: String?
    @Published var settingsVisible = false
    @Published var resetVisible = false
    @Published var suggestion: Suggestion?
    @Published var suggestionText = ""
    @Published var suggestionError: String?
    @Published var isThinking = false
    @Published var connectionStatus = "Not checked"
    @Published var checkingConnection = false
    @Published var focusMinutes = 15
    @Published var pauseMinutes = 5
    @Published var nextStepBuffer = ""
    @Published var chatInput = ""
    @Published var chatThinking = false
    @Published var chatError: String?
    let companionServer = CompanionServer()
    var chatTask: Task<Void, Never>?

    private let repository: WorkspaceRepository?
    private var savingAllowed = true
    private var ticker: AnyCancellable?
    private var requestTask: Task<Void, Never>?

    init(repository: WorkspaceRepository? = nil, sample: Bool = false) {
        self.repository = repository
        if sample {
            var initial = WorkspaceState()
            initial.captures = [
                Capture(text: "Send the first mix to Alex", nextAction: "Open the session and listen to the last chorus.", planned: true),
                Capture(text: "Tidy up the project handover", nextAction: "Write the names of the three files to include.", planned: true),
                Capture(text: "Book a haircut", nextAction: "Find the salon's booking page.", planned: true),
                Capture(text: "Look into that new synth plugin — it can wait."),
                Capture(text: "An idea for the portfolio: a short before-and-after audio clip.")
            ]
            initial.brainDumpBuffer = "Invoice for last week's session\nFind a better way to label the stems\nThat ambient track idea from the walk…"
            initial.draftNotesBuffer = "First mix is almost ready. Sending it tomorrow. Ask Alex to collect feedback in one place."
            initial.draftBodyBuffer = "Hi Alex,\n\nThe first mix is nearly ready. I'll send it over tomorrow.\n\nWhen you've had a listen, could you collect your feedback in one place? That'll help me keep the next round focused.\n\nThanks!"
            state = initial
        } else {
            do { state = try repository?.load() ?? WorkspaceState() }
            catch {
                state = WorkspaceState()
                savingAllowed = false
                self.error = "Your saved workspace couldn't be opened. It has been left untouched. Quit and check the saved file before continuing."
            }
        }
        selectedTaskID = state.priorities.first?.id
        if state.agentEnabled && !sample { checkConnection() }
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in self?.now = date }
    }

    var selectedTask: Capture? { state.priorities.first { $0.id == selectedTaskID } ?? state.priorities.first }
    var activeSession: Bool { state.session.map { $0.phase(at: now) != .finished } ?? false }
    var canSave: Bool { savingAllowed }

    func save() {
        guard savingAllowed, let repository else { return }
        do { try repository.save(state) }
        catch { self.error = "Your latest changes couldn't be saved. Keep the app open and check available disk space or folder access." }
    }

    func capture() {
        do {
            try state.capture(state.brainDumpBuffer)
            state.brainDumpBuffer = ""
            notice = "Saved. You don't have to decide what to do with it yet."
        } catch { self.error = error.localizedDescription }
    }

    func promote(_ id: UUID) {
        do {
            try state.promote(id)
            selectedTaskID = id
            notice = "Added to your plan."
        } catch { self.error = error.localizedDescription }
    }

    func park(_ id: UUID) {
        guard state.session?.taskID != id || !activeSession else {
            error = "End this task's focus session before parking it."
            return
        }
        if let i = state.captures.firstIndex(where: { $0.id == id }) { state.captures[i].planned = false }
        selectedTaskID = state.priorities.first?.id
    }

    func finishTask(_ id: UUID) {
        if let i = state.captures.firstIndex(where: { $0.id == id }) { state.captures[i].completed = true }
        if state.session?.taskID == id { state.session = nil }
        selectedTaskID = state.priorities.first?.id
        notice = "Task finished. That's one less thing to hold."
    }

    func updateTask(_ id: UUID, action: String? = nil, link: String? = nil) {
        guard let i = state.captures.firstIndex(where: { $0.id == id }) else { return }
        if let action {
            state.captures[i].nextAction = action
            if state.session?.taskID == id { state.session?.nextAction = action }
        }
        if let link { state.captures[i].linearLink = link }
    }

    func startFocus() {
        guard !activeSession else { section = .focus; return }
        guard let task = selectedTask else { section = .plan; return }
        do {
            state.session = try FocusSession(task: task, minutes: focusMinutes)
            nextStepBuffer = ""
            section = .focus
        } catch { self.error = error.localizedDescription }
    }

    func pause() {
        do { try state.session?.pause(minutes: pauseMinutes) }
        catch { self.error = error.localizedDescription }
    }

    func resume() { state.session?.resume() }
    func endFocus() { state.session = nil }

    func completeStep() {
        guard let session = state.session, !session.nextAction.isEmpty else { return }
        state.session?.completeStep()
        if let i = state.captures.firstIndex(where: { $0.id == session.taskID }) { state.captures[i].nextAction = "" }
        nextStepBuffer = ""
    }

    func setNextStep() {
        guard let id = state.session?.taskID, !nextStepBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        updateTask(id, action: nextStepBuffer)
        nextStepBuffer = ""
    }

    func openTask(_ task: Capture) {
        guard let url = TaskLinks.linearURL(task.linearLink) else {
            error = "Add a valid https://linear.app/…/issue/… task link in Plan first."
            return
        }
        NSWorkspace.shared.open(url)
    }

    func saveDraft() {
        guard !state.draftBodyBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state.drafts.insert(CommunicationDraft(kind: state.draftKind, notes: state.draftNotesBuffer, body: state.draftBodyBuffer), at: 0)
        notice = "A copy of this draft is saved."
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice = "Copied. Ready when you are."
    }

    func ask(title: String, prompt: String, taskID: UUID? = nil, isDraft: Bool = false) {
        guard state.agentEnabled else { settingsVisible = true; return }
        requestTask?.cancel()
        let request = Suggestion(title: title, prompt: prompt, taskID: taskID, isDraft: isDraft)
        suggestion = request
        suggestionText = ""
        suggestionError = nil
        isThinking = true
        let port = state.agentPort
        requestTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await self.companionServer.ensureRunning(port: port)
                try Task.checkCancellation()
                let reply = try await CompanionClient(port: port).suggest(prompt: prompt)
                guard !Task.isCancelled, self.suggestion?.id == request.id else { return }
                self.suggestionText = reply
            } catch {
                guard !Task.isCancelled, self?.suggestion?.id == request.id else { return }
                self?.suggestionError = error.localizedDescription
            }
            if self?.suggestion?.id == request.id { self?.isThinking = false }
        }
    }

    func cancelSuggestion() {
        requestTask?.cancel()
        requestTask = nil
        suggestion = nil
        isThinking = false
    }

    func applySuggestion() {
        guard let suggestion else { return }
        let text = suggestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let id = suggestion.taskID { updateTask(id, action: text) }
        if suggestion.isDraft { state.draftBodyBuffer = text }
        cancelSuggestion()
        notice = "Applied. You can edit it any time."
    }

    func checkConnection() {
        checkingConnection = true
        connectionStatus = "Starting your companion…"
        let port = state.agentPort
        Task {
            do {
                try await companionServer.ensureRunning(port: port)
                connectionStatus = "Your companion is ready."
            } catch { connectionStatus = error.localizedDescription }
            checkingConnection = false
        }
    }

    func askForStep(_ task: Capture) {
        ask(title: "A smaller starting step", prompt: "Help me begin this task. Energy: \(state.energy). Task: \(task.text)\nCurrent next action: \(task.nextAction)\nGive only ONE concrete physical starter action that takes under five minutes. Use one short sentence, no introduction or numbered list. Do not start a timer.", taskID: task.id)
    }

    static func clockText(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
