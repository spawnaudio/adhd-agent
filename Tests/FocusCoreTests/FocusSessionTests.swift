import XCTest
@testable import FocusCore

final class FocusSessionTests: XCTestCase {
    func testEmptyTaskCannotStart() {
        var session = FocusSession()
        session.task = "  \n "
        session.nextAction = "Open draft"
        session.start()
        XCTAssertFalse(session.isActive)
    }
    func testPauseSurvivesPersistenceAndExpiresAfterSleep() throws {
        var session = FocusSession()
        session.task = "Write proposal"
        session.nextAction = "Open draft"
        let start = Date(timeIntervalSince1970: 1000)
        session.start(now: start)
        session.pause(minutes: 5, now: start)
        var restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        XCTAssertFalse(restored.reconcile(now: start.addingTimeInterval(299)))
        XCTAssertTrue(restored.reconcile(now: start.addingTimeInterval(500)))
        XCTAssertNil(restored.pauseUntil)
        XCTAssertTrue(restored.isActive)
        XCTAssertFalse(restored.reconcile(now: start.addingTimeInterval(501)))
    }
    func testOnlyLinearIssueLinksAreOpened() {
        var session = FocusSession()
        session.task = "See https://example.com and https://linear.app/team/issue/ABC-12/task"
        XCTAssertEqual(session.linearURL?.host, "linear.app")
        session.task = "https://linear.app.evil.example/team/issue/ABC-12"
        XCTAssertNil(session.linearURL)
    }
    func testEndKeepsTaskAndIdeasButClearsPause() {
        var session = FocusSession()
        session.task = "Proposal"
        session.nextAction = "Open draft"
        session.start()
        session.pause(minutes: 10)
        session.saveThought("  Look at that app later  ")
        session.saveThought("  ")
        session.end()
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.pauseUntil)
        XCTAssertEqual(session.task, "Proposal")
        XCTAssertEqual(session.thoughts.map(\.text), ["Look at that app later"])
    }
}
