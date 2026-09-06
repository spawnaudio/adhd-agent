import Foundation

public struct Capture: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var nextAction: String
    public var linearLink: String
    public var planned: Bool
    public var completed: Bool
    public var createdAt: Date

    public var title: String {
        String(text.split(whereSeparator: \.isNewline).first.map(String.init)?.prefix(120) ?? "Untitled thought")
    }

    public init(text: String, nextAction: String = "", linearLink: String = "", planned: Bool = false) {
        id = UUID()
        self.text = text
        self.nextAction = nextAction
        self.linearLink = linearLink
        self.planned = planned
        completed = false
        createdAt = Date()
    }
}

public enum DraftKind: String, Codable, CaseIterable, Sendable {
    case email = "Email"
    case update = "Team update"
    case meeting = "Meeting notes"
}

public struct CommunicationDraft: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var kind: DraftKind
    public var notes: String
    public var body: String
    public var createdAt = Date()

    public init(kind: DraftKind, notes: String, body: String) {
        self.kind = kind
        self.notes = notes
        self.body = body
    }
}

public enum FocusPhase: String, Sendable {
    case running, paused, finished
}

public struct FocusSession: Codable, Equatable, Sendable {
    public var id = UUID()
    public var taskID: UUID
    public var taskTitle: String
    public var nextAction: String
    public var startedAt: Date
    public var deadline: Date
    public var duration: TimeInterval
    public var pausedUntil: Date?
    public var completedSteps: Int = 0

    public init(task: Capture, minutes: Int, now: Date = Date()) throws {
        guard !task.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !task.nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              minutes > 0, minutes <= 180 else { throw FlowError.invalidFocus }
        taskID = task.id
        taskTitle = task.title
        nextAction = task.nextAction
        startedAt = now
        duration = TimeInterval(minutes * 60)
        deadline = now.addingTimeInterval(duration)
    }

    public func phase(at now: Date) -> FocusPhase {
        if let pausedUntil, now < pausedUntil { return .paused }
        return now < deadline ? .running : .finished
    }

    public func remaining(at now: Date) -> TimeInterval {
        let reference = max(now, pausedUntil ?? now)
        return max(0, deadline.timeIntervalSince(reference))
    }

    public func breakRemaining(at now: Date) -> TimeInterval {
        max(0, pausedUntil?.timeIntervalSince(now) ?? 0)
    }

    public mutating func pause(minutes: Int, now: Date = Date()) throws {
        guard phase(at: now) == .running, [5, 10, 15].contains(minutes) else { throw FlowError.invalidPause }
        let seconds = TimeInterval(minutes * 60)
        pausedUntil = now.addingTimeInterval(seconds)
        deadline = deadline.addingTimeInterval(seconds)
    }

    public mutating func resume(now: Date = Date()) {
        if let pausedUntil, pausedUntil > now {
            deadline = deadline.addingTimeInterval(-pausedUntil.timeIntervalSince(now))
        }
        pausedUntil = nil
    }

    public mutating func completeStep() {
        guard !nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        completedSteps += 1
        nextAction = ""
    }
}

public struct WorkspaceState: Codable, Equatable, Sendable {
    public var version = 1
    public var captures: [Capture] = []
    public var drafts: [CommunicationDraft] = []
    public var session: FocusSession?
    public var brainDumpBuffer = ""
    public var draftNotesBuffer = ""
    public var draftBodyBuffer = ""
    public var draftKind: DraftKind = .email
    public var energy = "Steady"
    public var agentEnabled = false
    public var agentPort = "8000"

    public init() {}

    public var priorities: [Capture] { captures.filter { $0.planned && !$0.completed } }
    public var parked: [Capture] { captures.filter { !$0.planned && !$0.completed } }

    public mutating func promote(_ id: UUID) throws {
        guard let index = captures.firstIndex(where: { $0.id == id }) else { return }
        guard !captures[index].completed else { return }
        if captures[index].planned { return }
        guard priorities.count < 3 else { throw FlowError.planFull }
        captures[index].planned = true
    }

    public mutating func capture(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FlowError.emptyCapture }
        // Preserve the exact raw input rather than rewriting a brain dump.
        captures.insert(Capture(text: text), at: 0)
    }
}

public enum FlowError: LocalizedError, Equatable {
    case emptyCapture, planFull, invalidFocus, invalidPause, unsupportedVersion

    public var errorDescription: String? {
        switch self {
        case .emptyCapture: return "Write a thought first. A few words are enough."
        case .planFull: return "Your plan already has three priorities. Park or finish one to make room."
        case .invalidFocus: return "Choose a task and add one small next action before starting."
        case .invalidPause: return "Choose a 5, 10, or 15 minute pause during an active session."
        case .unsupportedVersion: return "This saved workspace needs a newer version of Focus & Flow."
        }
    }
}

public enum TaskLinks {
    public static func linearURL(_ string: String) -> URL? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              url.host?.lowercased() == "linear.app",
              let issueIndex = url.pathComponents.firstIndex(of: "issue"),
              issueIndex + 1 < url.pathComponents.count,
              !url.pathComponents[issueIndex + 1].isEmpty else { return nil }
        return url
    }
}

public struct WorkspaceRepository {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> WorkspaceState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return WorkspaceState() }
        let state = try JSONDecoder().decode(WorkspaceState.self, from: Data(contentsOf: fileURL))
        guard state.version == 1 else { throw FlowError.unsupportedVersion }
        return state
    }

    public func save(_ state: WorkspaceState) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
