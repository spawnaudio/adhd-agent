import Foundation

public struct SavedThought: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var text: String
    public var createdAt = Date()
    public init(text: String) { self.text = text }
}

public struct FocusSession: Codable, Equatable {
    public var task = ""
    public var nextAction = ""
    public var startedAt: Date?
    public var pauseUntil: Date?
    public var thoughts: [SavedThought] = []

    public init() {}
    public var isActive: Bool { startedAt != nil }
    public var canStart: Bool {
        !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public var linearURL: URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return detector.matches(in: task, range: NSRange(task.startIndex..., in: task))
            .compactMap(\.url).first { url in
                url.scheme == "https" && url.host?.lowercased() == "linear.app" && url.path.contains("/issue/")
            }
    }
    public mutating func start(now: Date = Date()) {
        guard canStart else { return }
        startedAt = now
        pauseUntil = nil
    }
    public mutating func pause(minutes: Int, now: Date = Date()) {
        guard isActive, [5, 10, 15].contains(minutes) else { return }
        pauseUntil = now.addingTimeInterval(TimeInterval(minutes * 60))
    }
    public mutating func resume() { pauseUntil = nil }
    public mutating func end() { startedAt = nil; pauseUntil = nil }
    @discardableResult
    public mutating func reconcile(now: Date = Date()) -> Bool {
        guard let expiry = pauseUntil, expiry <= now else { return false }
        pauseUntil = nil
        return true
    }
    public mutating func saveThought(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        thoughts.insert(SavedThought(text: trimmed), at: 0)
    }
}
