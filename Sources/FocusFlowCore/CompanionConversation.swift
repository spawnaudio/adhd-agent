import Foundation

public struct CompanionMessage: Codable, Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, Sendable { case user, model }
    public var id = UUID()
    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

public struct CompanionConversation: Codable, Equatable, Sendable {
    public var id = UUID()
    public var messages: [CompanionMessage] = []
    public init() {}
}
