import Foundation

public enum CompanionStartupError: LocalizedError {
    case missingSource, failed(URL), timedOut(URL)
    public var errorDescription: String? {
        switch self {
        case .missingSource: return "The companion files are missing. Rebuild Focus & Flow from this repository."
        case .failed(let log): return "The companion could not start. Check \(log.path) for details."
        case .timedOut(let log): return "The companion is taking too long to start. Check \(log.path), then try again."
        }
    }
}

@MainActor
public final class CompanionServer {
    public let dataDirectory: URL
    private let sourceDirectory: URL
    private var process: Process?
    private var logHandle: FileHandle?
    private var startup: Task<Void, Error>?
    private var activePort: String?

    public init(sourceDirectory: URL? = nil, dataDirectory: URL? = nil) {
        let resources = Bundle.main.resourceURL?.appendingPathComponent("companion")
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("companion")
        self.sourceDirectory = sourceDirectory ?? (resources.flatMap {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("start.sh").path) ? $0 : nil
        } ?? repository)
        self.dataDirectory = dataDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FocusFlow/companion")
    }

    public func ensureRunning(port: String) async throws {
        _ = try CompanionClient(port: port)
        if let startup {
            try await startup.value
            if activePort == port { return }
        }
        if process != nil, activePort != port { stop() }
        let task = Task { try await start(port: port) }
        startup = task
        defer { startup = nil }
        try await task.value
    }

    private func start(port: String) async throws {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 2
        let client = try CompanionClient(port: port, session: URLSession(configuration: config))
        if (try? await client.checkConnection()) != nil {
            activePort = port
            return
        }
        try Task.checkCancellation()
        stopProcess()
        let script = sourceDirectory.appendingPathComponent("start.sh")
        guard FileManager.default.fileExists(atPath: script.path) else { throw CompanionStartupError.missingSource }
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dataDirectory.path)
        let log = dataDirectory.appendingPathComponent("server.log")
        if !FileManager.default.fileExists(atPath: log.path) {
            guard FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw CompanionStartupError.failed(log)
            }
        }
        logHandle = try FileHandle(forWritingTo: log)
        try logHandle?.seekToEnd()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sh")
        child.arguments = [script.path, port]
        child.currentDirectoryURL = dataDirectory
        child.environment = ProcessInfo.processInfo.environment.merging(["FOCUS_FLOW_DATA_DIR": dataDirectory.path]) { _, new in new }
        child.standardOutput = logHandle
        child.standardError = logHandle
        do { try child.run() }
        catch { stopProcess(); throw error }
        process = child
        activePort = port
        do {
            for _ in 0..<180 {
                try Task.checkCancellation()
                guard child.isRunning else { throw CompanionStartupError.failed(log) }
                if (try? await client.checkConnection()) != nil { return }
                try await Task.sleep(for: .seconds(1))
            }
            throw CompanionStartupError.timedOut(log)
        } catch {
            stopProcess()
            throw error
        }
    }

    public func stop() {
        startup?.cancel()
        stopProcess()
    }

    private func stopProcess() {
        // Only stop the process this app launched; an existing local server belongs to its caller.
        if process?.isRunning == true { process?.terminate() }
        process = nil
        try? logHandle?.close()
        logHandle = nil
        activePort = nil
    }
}
