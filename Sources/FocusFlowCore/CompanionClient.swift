import Foundation

public enum CompanionError: LocalizedError, Equatable {
    case invalidPort, unavailable, timedOut, http(Int), emptyReply
    public var errorDescription: String? {
        switch self {
        case .invalidPort: return "Enter a local port between 1024 and 65535."
        case .unavailable: return "The companion isn't reachable. Try connecting again in Companion settings. Your work is saved here."
        case .timedOut: return "The companion took too long to reply. Try again; your work is saved."
        case .http(let code): return "The companion returned an error (\(code)). Check its server and Google connection, then try again."
        case .emptyReply: return "The companion didn't return a written suggestion. Try again with a little more context."
        }
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct CompanionClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    public init(port: String, session: URLSession? = nil) throws {
        guard let port = Int(port), (1024...65535).contains(port) else { throw CompanionError.invalidPort }
        baseURL = URL(string: "http://127.0.0.1:\(port)")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 120
        configuration.httpCookieStorage = nil
        self.session = session ?? URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }

    public func checkConnection() async throws {
        let data = try await send(path: "/list-apps", method: "GET")
        guard let apps = try? JSONDecoder().decode([String].self, from: data), apps.contains("app") else {
            throw CompanionError.unavailable
        }
    }

    public func suggest(prompt: String) async throws -> String {
        // Isolate requests: a brain dump is never implicitly attached to a later draft.
        let sessionID = UUID().uuidString
        let path = "/apps/app/users/focus-flow-mac/sessions/\(sessionID)"
        _ = try await send(path: path, method: "POST", body: [:])
        do {
            let reply = try await run(prompt: prompt, sessionID: sessionID)
            // Best effort cleanup; it does not remove the source backend's telemetry.
            _ = try? await send(path: path, method: "DELETE")
            return reply
        } catch {
            _ = try? await send(path: path, method: "DELETE")
            throw error
        }
    }

    public func chat(prompt: String, conversationID: UUID) async throws -> String {
        let sessionID = conversationID.uuidString
        let path = "/apps/app/users/focus-flow-mac/sessions/\(sessionID)"
        do { _ = try await send(path: path, method: "GET") }
        catch CompanionError.http(404) { _ = try await send(path: path, method: "POST", body: [:]) }
        return try await run(prompt: prompt, sessionID: sessionID)
    }

    private func run(prompt: String, sessionID: String) async throws -> String {
        let data = try await send(path: "/run", method: "POST", body: [
            "app_name": "app", "user_id": "focus-flow-mac", "session_id": sessionID,
            "new_message": ["role": "user", "parts": [["text": prompt]]]
        ])
        return try Self.writtenReply(from: data)
    }

    public static func writtenReply(from data: Data) throws -> String {
        let events = try JSONDecoder().decode([AgentEvent].self, from: data)
        let replies = events.compactMap { event -> String? in
            guard event.content?.role == "model", event.partial != true,
                  let parts = event.content?.parts,
                  !parts.contains(where: { $0.functionCall != nil }) else { return nil }
            let text = parts.filter { $0.thought != true }.compactMap(\.text).joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        guard let reply = replies.last else { throw CompanionError.emptyReply }
        return reply
    }

    private func send(path: String, method: String, body: [String: Any]? = nil) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            if (error as? URLError)?.code == .timedOut { throw CompanionError.timedOut }
            throw CompanionError.unavailable
        }
        guard let http = response as? HTTPURLResponse else { throw CompanionError.unavailable }
        guard (200..<300).contains(http.statusCode) else { throw CompanionError.http(http.statusCode) }
        return data
    }
}

private struct AgentEvent: Decodable {
    struct Content: Decodable {
        struct Part: Decodable {
            struct FunctionCall: Decodable {}
            var text: String?
            var thought: Bool?
            var functionCall: FunctionCall?
        }
        var role: String?
        var parts: [Part]?
    }
    var content: Content?
    var partial: Bool?
}
