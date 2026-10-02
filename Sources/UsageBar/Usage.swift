import Foundation

enum AIService: String, CaseIterable, Sendable {
    case chatGPT = "ChatGPT"
    case claude = "Claude"
}

enum UsageWindow: String, Sendable {
    case fiveHour, weekly
    var label: String { self == .fiveHour ? "5H" : "7D" }
}

struct UsageAllowance: Sendable {
    /// Normalized fraction remaining, from 0 to 1.
    let remaining: Double
    let resetsAt: Date?
    var normalizedRemaining: Double { remaining.isFinite ? min(1, max(0, remaining)) : 0 }
    func fraction(showUsed: Bool) -> Double {
        showUsed ? 1 - normalizedRemaining : normalizedRemaining
    }
}

struct UsageSnapshot: Sendable {
    let fiveHour: UsageAllowance
    let weekly: UsageAllowance
    let fetchedAt: Date
    let source: String
    var isCached: Bool = false
    var isStale: Bool { isCached && Date().timeIntervalSince(fetchedAt) > 600 }
    subscript(window: UsageWindow) -> UsageAllowance {
        window == .fiveHour ? fiveHour : weekly
    }
    func effectiveWindow(requested: UsageWindow) -> UsageWindow {
        weekly.normalizedRemaining == 0 && fiveHour.normalizedRemaining > 0 ? .weekly : requested
    }
}

/// Providers map their data to fractions remaining and absolute reset dates when available.
protocol UsageProvider: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}

struct MockUsageProvider: UsageProvider {
    enum Scenario: String, CaseIterable, Sendable {
        case normal, weeklyExhausted, fiveHourExhausted, bothExhausted
        var title: String {
            switch self {
            case .normal: "Normal (78% / 25%)"
            case .weeklyExhausted: "Weekly exhausted (78% / 0%)"
            case .fiveHourExhausted: "5-hour exhausted (0% / 25%)"
            case .bothExhausted: "Both exhausted (0% / 0%)"
            }
        }
    }
    let scenario: Scenario
    var service: AIService = .chatGPT
    private let createdAt = Date()
    func fetchUsage() async throws -> UsageSnapshot {
        UsageSnapshot(
            fiveHour: UsageAllowance(
                remaining: scenario == .fiveHourExhausted || scenario == .bothExhausted ? 0 : 0.78,
                resetsAt: createdAt.addingTimeInterval(3 * 3600)),
            weekly: UsageAllowance(
                remaining: scenario == .weeklyExhausted || scenario == .bothExhausted ? 0 : 0.25,
                resetsAt: createdAt.addingTimeInterval(4 * 86400)),
            fetchedAt: Date(), source: "\(service.rawValue) - Mock data")
    }
}
