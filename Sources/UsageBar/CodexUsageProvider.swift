import Foundation

struct UsageProviderError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// One persistent local helper. Codex owns authentication; UsageBar never reads tokens.
actor CodexUsageProvider: UsageProvider {
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<Data, any Error>] = [:]
    private var timeoutTasks: [Int: Task<Void, Never>] = [:]
    private var connectionID = 0
    private var initialized = false
    private var lastReading: UsageSnapshot?
    func invalidateCache() { lastReading = nil; retryAfter = .distantPast }
    private var failures = 0
    private var retryAfter = Date.distantPast

    func fetchUsage() async throws -> UsageSnapshot {
        if let lastReading, Date().timeIntervalSince(lastReading.fetchedAt) < 30 { return lastReading }
        guard Date() >= retryAfter else {
            throw UsageProviderError(message: "Connection paused after an error; retrying shortly.")
        }
        do {
            try await connect()
            let data = try await request(method: "account/rateLimits/read")
            let value = try Self.decode(data)
            failures = 0
            lastReading = value
            return value
        } catch {
            failures += 1
            retryAfter = Date().addingTimeInterval(min(60, pow(2, Double(min(failures, 6)))))
            disconnect()
            throw error
        }
    }

    private func connect() async throws {
        if initialized, process?.isRunning == true { return }
        let candidates = [
            ProcessInfo.processInfo.environment["USAGEBAR_CODEX_PATH"],
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex"
        ].compactMap { $0 }
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw UsageProviderError(message: "Install ChatGPT/Codex or set USAGEBAR_CODEX_PATH. No local session helper found.")
        }
        connectionID += 1
        let currentConnection = connectionID
        let child = Process()
        let stdin = Pipe(), stdout = Pipe()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = ["app-server", "-c", "analytics.enabled=false"]
        child.standardInput = stdin
        child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            Task { await self?.receive(data, connection: currentConnection) }
        }
        process = child
        input = stdin.fileHandleForWriting
        do { try child.run() } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            disconnect()
            throw UsageProviderError(message: "Could not start the local Codex helper.")
        }
        let params: [String: Any] = ["clientInfo": ["name": "usagebar", "title": "UsageBar", "version": "0.3.0"]]
        let encoded = try JSONSerialization.data(withJSONObject: params)
        _ = try await request(method: "initialize", params: encoded)
        try write(["method": "initialized", "params": [:]])
        initialized = true
    }

    private func request(method: String, params: Data? = nil) async throws -> Data {
        nextID += 1
        let id = nextID
        var object: [String: Any] = ["id": id, "method": method]
        if let params { object["params"] = try JSONSerialization.jsonObject(with: params) }
        let payload = try JSONSerialization.data(withJSONObject: object) + Data([10])
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            timeoutTasks[id] = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                await self?.timeout(id)
            }
            do {
                guard let input else { throw UsageProviderError(message: "Local session disconnected.") }
                try input.write(contentsOf: payload)
            } catch { finish(id, result: .failure(UsageProviderError(message: "Local session disconnected."))) }
        }
    }

    private func write(_ value: [String: Any]) throws {
        guard let input else { throw UsageProviderError(message: "Local session disconnected.") }
        try input.write(contentsOf: JSONSerialization.data(withJSONObject: value) + Data([10]))
    }

    private func receive(_ data: Data, connection: Int) {
        guard connection == connectionID else { return }
        guard !data.isEmpty else {
            disconnect()
            return
        }
        buffer.append(data)
        while let end = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<end])
            buffer.removeSubrange(...end)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = object["id"] as? Int, pending[id] != nil else { continue }
            if object["error"] != nil {
                // Do not display upstream bodies, which could contain account details.
                finish(id, result: .failure(UsageProviderError(message: "Usage unavailable. Check that ChatGPT/Codex is signed in with your ChatGPT account.")))
            } else if let result = object["result"], let encoded = try? JSONSerialization.data(withJSONObject: result) {
                finish(id, result: .success(encoded))
            } else {
                finish(id, result: .failure(UsageProviderError(message: "Unexpected usage response.")))
            }
        }
    }

    private func timeout(_ id: Int) {
        finish(id, result: .failure(UsageProviderError(message: "Usage request timed out. Try Refresh now.")))
    }
    private func finish(_ id: Int, result: Result<Data, any Error>) {
        timeoutTasks.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(with: result)
    }
    func disconnect() {
        connectionID += 1
        initialized = false
        if let handle = (process?.standardOutput as? Pipe)?.fileHandleForReading { handle.readabilityHandler = nil }
        try? input?.close()
        if process?.isRunning == true { process?.terminate() }
        process = nil
        input = nil
        buffer.removeAll()
        for id in Array(pending.keys) {
            finish(id, result: .failure(UsageProviderError(message: "Local session disconnected.")))
        }
    }

    static func decode(_ data: Data) throws -> UsageSnapshot {
        struct Window: Decodable { let usedPercent: Double; let windowDurationMins: Int; let resetsAt: Double }
        struct Bucket: Decodable { let limitId: String?; let primary: Window?; let secondary: Window? }
        struct Response: Decodable { let rateLimits: Bucket?; let rateLimitsByLimitId: [String: Bucket]? }
        let response = try JSONDecoder().decode(Response.self, from: data)
        // Never substitute an unrelated model bucket or fabricate a missing allowance.
        let bucket = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        guard let bucket, bucket.limitId == nil || bucket.limitId == "codex" else {
            throw UsageProviderError(message: "The Codex allowance bucket is unavailable.")
        }
        let windows = [bucket.primary, bucket.secondary].compactMap { $0 }
        guard let five = windows.first(where: { $0.windowDurationMins == 300 }),
              let weekly = windows.first(where: { $0.windowDurationMins == 10080 }) else {
            throw UsageProviderError(message: "This account did not return both 5-hour and weekly limits.")
        }
        func allowance(_ window: Window) throws -> UsageAllowance {
            guard window.usedPercent.isFinite, (0...100).contains(window.usedPercent), window.resetsAt.isFinite, window.resetsAt > 0 else {
                throw UsageProviderError(message: "Invalid usage data received.")
            }
            return UsageAllowance(remaining: 1 - window.usedPercent / 100, resetsAt: Date(timeIntervalSince1970: window.resetsAt))
        }
        return try UsageSnapshot(fiveHour: allowance(five), weekly: allowance(weekly), fetchedAt: Date(), source: "Live ChatGPT account · Codex allowance")
    }
}
