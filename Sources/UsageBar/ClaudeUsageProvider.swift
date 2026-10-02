import Foundation

/// Reads only Claude Desktop's percentage history, never authentication data.
/// This undocumented versioned cache may change; fail closed on unknown formats.
actor ClaudeUsageProvider: UsageProvider {
    private let fileURL: URL
    private var lastModification: Date?
    private var lastSnapshot: UsageSnapshot?

    init(fileURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Claude/plan-usage-history.json")) {
        self.fileURL = fileURL
    }

    func fetchUsage() async throws -> UsageSnapshot {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let size = attributes[.size] as? NSNumber, size.intValue <= 5_000_000 else {
                throw UsageProviderError(message: "Claude usage history is too large or unreadable.")
            }
            let modification = attributes[.modificationDate] as? Date
            if let modification, modification == lastModification, let lastSnapshot { return lastSnapshot }
            let value = try Self.decode(Data(contentsOf: fileURL))
            lastModification = modification
            lastSnapshot = value
            return value
        } catch let error as UsageProviderError { throw error }
        catch { throw UsageProviderError(message: "Claude usage history unavailable. Open Claude and visit Settings → Usage.") }
    }

    static func decode(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        struct Sample: Decodable { let t: Double; let org: String?; let u: [String: Double] }
        struct History: Decodable { let version: Int; let samples: [Sample] }
        let history = try JSONDecoder().decode(History.self, from: data)
        guard history.version == 2 else { throw UsageProviderError(message: "Unsupported Claude usage-history version.") }
        guard Set(history.samples.compactMap(\.org)).count <= 1 else {
            throw UsageProviderError(message: "Multiple Claude organizations found. Account selection is required before displaying a reading.")
        }
        guard let latest = history.samples.max(by: { $0.t < $1.t }),
              let five = latest.u["fh"], let weekly = latest.u["sd"],
              five.isFinite, weekly.isFinite, (0...100).contains(five), (0...100).contains(weekly),
              latest.t.isFinite, latest.t > 0, latest.t / 1000 <= now.timeIntervalSince1970 + 60 else {
            throw UsageProviderError(message: "Claude history does not contain valid session and weekly percentages.")
        }
        return UsageSnapshot(
            fiveHour: UsageAllowance(remaining: 1 - five / 100, resetsAt: nil),
            weekly: UsageAllowance(remaining: 1 - weekly / 100, resetsAt: nil),
            fetchedAt: Date(timeIntervalSince1970: latest.t / 1000),
            source: "Claude Desktop local cache · updates at most every 4½ minutes",
            isCached: true)
    }
}
