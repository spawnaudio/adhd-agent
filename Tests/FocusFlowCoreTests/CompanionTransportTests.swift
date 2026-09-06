import XCTest
@testable import FocusFlowCore

private final class AgentStub: URLProtocol, @unchecked Sendable {
    // Each test class instance runs these tests sequentially with an isolated URLSession.
    static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class CompanionTransportTests: XCTestCase {
    func client() throws -> CompanionClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AgentStub.self]
        return try CompanionClient(port: "8000", session: URLSession(configuration: configuration))
    }

    override func tearDown() { AgentStub.handler = nil; super.tearDown() }

    func testRequestCreatesSessionRunsAgentAndCleansUp() async throws {
        var paths: [(String, String)] = []
        AgentStub.handler = { request in
            paths.append((request.httpMethod!, request.url!.path))
            XCTAssertEqual(request.url?.host, "127.0.0.1")
            if request.url?.path == "/run" {
                return (200, #"[{"content":{"role":"model","parts":[{"text":"Open your session."}]}}]"#)
            }
            return (200, "{}")
        }
        let result = try await client().suggest(prompt: "Help me start")
        XCTAssertEqual(result, "Open your session.")
        XCTAssertEqual(paths.count, 3)
        XCTAssertTrue(paths[0].1.hasPrefix("/apps/app/users/focus-flow-mac/sessions/"))
        XCTAssertEqual(paths[0].0, "POST")
        XCTAssertEqual(paths[1].1, "/run")
        XCTAssertEqual(paths[2].0, "DELETE")
        XCTAssertEqual(paths[2].1, paths[0].1)
    }

    func testHTTPFailureIsNotTreatedAsSuggestion() async throws {
        AgentStub.handler = { _ in (503, "Service unavailable") }
        do { _ = try await client().suggest(prompt: "Help"); XCTFail("Expected error") }
        catch { XCTAssertEqual(error as? CompanionError, .http(503)) }
    }

    func testUnavailableServerHasUsefulError() async throws {
        AgentStub.handler = { _ in throw URLError(.cannotConnectToHost) }
        do { try await client().checkConnection(); XCTFail("Expected error") }
        catch { XCTAssertEqual(error as? CompanionError, .unavailable) }
    }

    func testConnectionMustContainExpectedAgent() async throws {
        AgentStub.handler = { _ in (200, "[\"different_app\"]") }
        do { try await client().checkConnection(); XCTFail("Expected error") }
        catch { XCTAssertEqual(error as? CompanionError, .unavailable) }
        AgentStub.handler = { _ in (200, "[\"app\"]") }
        try await client().checkConnection()
    }

    func testRunFailureStillCleansUpSession() async throws {
        var deleted = false
        AgentStub.handler = { request in
            if request.httpMethod == "DELETE" { deleted = true }
            return request.url?.path == "/run" ? (500, "{}") : (200, "{}")
        }
        do { _ = try await client().suggest(prompt: "Help"); XCTFail("Expected error") }
        catch { XCTAssertEqual(error as? CompanionError, .http(500)) }
        XCTAssertTrue(deleted)
    }
}
