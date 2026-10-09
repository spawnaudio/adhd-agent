import XCTest
@testable import FocusFlowCore

final class CompanionConversationTests: XCTestCase {
    func testOlderWorkspaceLoadsWithoutConversation() throws {
        let data = try JSONEncoder().encode(WorkspaceState())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "conversation")
        let restored = try JSONDecoder().decode(WorkspaceState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.conversation)
        XCTAssertEqual(restored.agentPort, "8000")
    }

    func testConversationPersistsWithoutChangingTasksAndTimers() throws {
        var workspace = WorkspaceState()
        try workspace.capture("Keep this thought")
        var conversation = CompanionConversation()
        conversation.messages = [CompanionMessage(role: .user, text: "Help me start"), CompanionMessage(role: .model, text: "Open your document.")]
        workspace.conversation = conversation
        let restored = try JSONDecoder().decode(WorkspaceState.self, from: JSONEncoder().encode(workspace))
        XCTAssertEqual(restored, workspace)
        XCTAssertEqual(restored.captures.first?.text, "Keep this thought")
        XCTAssertEqual(restored.conversation?.id, conversation.id)
    }

    @MainActor func testInvalidPortDoesNotLaunchServer() async {
        let server = CompanionServer()
        do { try await server.ensureRunning(port: "22"); XCTFail("Expected invalid port") }
        catch { XCTAssertEqual(error as? CompanionError, .invalidPort) }
        server.stop()
    }
}
