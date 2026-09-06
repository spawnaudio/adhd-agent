import XCTest
@testable import FocusFlowCore

final class FocusFlowCoreTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func task() -> Capture { Capture(text: "Send the mix", nextAction: "Open the session", planned: true) }

    func testCaptureKeepsOriginalTextAndRejectsWhitespace() throws {
        var state = WorkspaceState()
        let raw = "  first thought\nsecond thought\n "
        try state.capture(raw)
        XCTAssertEqual(state.parked.first?.text, raw)
        XCTAssertThrowsError(try state.capture(" \n\t"))
        XCTAssertEqual(state.captures.count, 1)
    }

    func testPlanLimitAndParkingFreeSpace() throws {
        var state = WorkspaceState()
        for i in 1...4 { try state.capture("Task \(i)") }
        for item in state.captures.prefix(3) { try state.promote(item.id) }
        XCTAssertThrowsError(try state.promote(state.captures[3].id)) { XCTAssertEqual($0 as? FlowError, .planFull) }
        try state.promote(state.captures[0].id)
        XCTAssertEqual(state.priorities.count, 3)
        state.captures[0].planned = false
        try state.promote(state.captures[3].id)
        XCTAssertEqual(state.priorities.count, 3)
    }

    func testFocusRequiresTaskAndNextAction() throws {
        XCTAssertThrowsError(try FocusSession(task: Capture(text: "Something"), minutes: 15))
        XCTAssertThrowsError(try FocusSession(task: task(), minutes: 0))
        XCTAssertThrowsError(try FocusSession(task: Capture(text: "  ", nextAction: "Open a file"), minutes: 15))
    }

    func testPauseAndEarlyResumePreserveFocusTime() throws {
        var session = try FocusSession(task: task(), minutes: 15, now: start)
        let pausedAt = start.addingTimeInterval(120)
        try session.pause(minutes: 5, now: pausedAt)
        XCTAssertEqual(session.remaining(at: pausedAt.addingTimeInterval(100)), 780)
        XCTAssertEqual(session.phase(at: pausedAt.addingTimeInterval(100)), .paused)
        session.resume(now: pausedAt.addingTimeInterval(100))
        XCTAssertEqual(session.phase(at: pausedAt.addingTimeInterval(100)), .running)
        XCTAssertEqual(session.remaining(at: pausedAt.addingTimeInterval(100)), 780)
        XCTAssertEqual(session.remaining(at: pausedAt.addingTimeInterval(160)), 720)
    }

    func testPauseExpiryAcrossSleepAndRelaunch() throws {
        var session = try FocusSession(task: task(), minutes: 15, now: start)
        try session.pause(minutes: 5, now: start.addingTimeInterval(120))
        let restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.phase(at: start.addingTimeInterval(419)), .paused)
        XCTAssertEqual(restored.phase(at: start.addingTimeInterval(420)), .running)
        XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(480)), 720)
        XCTAssertEqual(restored.phase(at: start.addingTimeInterval(2000)), .finished)
        XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(2000)), 0)
    }

    func testCannotStackPausesOrPauseFinishedTimer() throws {
        var session = try FocusSession(task: task(), minutes: 5, now: start)
        XCTAssertThrowsError(try session.pause(minutes: 2, now: start))
        try session.pause(minutes: 5, now: start)
        XCTAssertThrowsError(try session.pause(minutes: 10, now: start))
        XCTAssertThrowsError(try session.pause(minutes: 5, now: start.addingTimeInterval(900)))
    }

    func testResumeAfterBreakExpiryDoesNotAddTime() throws {
        var session = try FocusSession(task: task(), minutes: 15, now: start)
        try session.pause(minutes: 5, now: start)
        let deadline = session.deadline
        session.resume(now: start.addingTimeInterval(400))
        XCTAssertEqual(session.deadline, deadline)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(400)), 800)
    }

    func testCompletedStepCannotBeCountedTwice() throws {
        var session = try FocusSession(task: task(), minutes: 15, now: start)
        session.completeStep()
        session.completeStep()
        XCTAssertEqual(session.completedSteps, 1)
        XCTAssertTrue(session.nextAction.isEmpty)
        XCTAssertEqual(session.phase(at: start), .running)
    }

    func testLinearLinksOnlyOpenExpectedIssueURLs() {
        XCTAssertNotNil(TaskLinks.linearURL("https://linear.app/studio/issue/ABC-123/send-the-mix"))
        for link in ["javascript:alert(1)", "file:///etc/passwd", "https://linear.app.evil.test/issue/X", "https://evil.test/issue/X", "https://linear.app@evil.test/issue/X", "http://linear.app/team/issue/X", "https://linear.app/settings", "https://linear.app/team/issue"] {
            XCTAssertNil(TaskLinks.linearURL(link), link)
        }
    }

    func testWorkspaceRoundTripIncludesBuffersAndSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceRepository(fileURL: directory.appendingPathComponent("workspace.json"))
        var state = WorkspaceState()
        try state.capture("A thought")
        state.brainDumpBuffer = "Still writing…"
        state.draftNotesBuffer = "Notes not yet drafted"
        state.draftBodyBuffer = "An unfinished draft"
        state.session = try FocusSession(task: task(), minutes: 15, now: start)
        try repository.save(state)
        XCTAssertEqual(try repository.load(), state)
        let attributes = try FileManager.default.attributesOfItem(atPath: repository.fileURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testCorruptAndNewerWorkspaceIsNotSilentlyReset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = WorkspaceRepository(fileURL: directory.appendingPathComponent("workspace.json"))
        try Data("broken".utf8).write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try String(contentsOf: repository.fileURL), "broken")
        var state = WorkspaceState(); state.version = 999
        try repository.save(state)
        XCTAssertThrowsError(try repository.load()) { XCTAssertEqual($0 as? FlowError, .unsupportedVersion) }
    }

    func testAgentParserIgnoresThoughtsToolsAndPartialEvents() throws {
        let payload = #"[{"content":{"role":"user","parts":[{"text":"Private prompt"}]}},{"content":{"role":"model","parts":[{"text":"Internal reasoning","thought":true}]}},{"content":{"role":"model","parts":[{"text":"Calling a tool"},{"functionCall":{"name":"focus_session_tracker"}}]}},{"partial":true,"content":{"role":"model","parts":[{"text":"Unfinished"}]}},{"content":{"role":"model","parts":[{"text":"Open the document."}]}}]"#
        XCTAssertEqual(try CompanionClient.writtenReply(from: Data(payload.utf8)), "Open the document.")
        XCTAssertThrowsError(try CompanionClient.writtenReply(from: Data("[]".utf8)))
    }

    func testRejectInvalidLocalPort() {
        for port in ["0", "22", "65536", "https://remote.test", "8000/path"] {
            XCTAssertThrowsError(try CompanionClient(port: port))
        }
    }
}
