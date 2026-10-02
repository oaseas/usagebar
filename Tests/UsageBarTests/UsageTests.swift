import Foundation
import Testing
@testable import UsageBar

@Test func weeklyOverrideAndRecovery() {
    let date = Date()
    let five = UsageAllowance(remaining: 0.78, resetsAt: date)
    let exhausted = UsageSnapshot(fiveHour: five, weekly: UsageAllowance(remaining: 0, resetsAt: date), fetchedAt: date, source: "Test")
    #expect(exhausted.effectiveWindow(requested: .fiveHour) == .weekly)
    let recovered = UsageSnapshot(fiveHour: five, weekly: UsageAllowance(remaining: 0.25, resetsAt: date), fetchedAt: date, source: "Test")
    #expect(recovered.effectiveWindow(requested: .fiveHour) == .fiveHour)
    #expect(recovered.effectiveWindow(requested: .weekly) == .weekly)
}

@Test func fractionsAreSafeAndUsedIsComplement() {
    let date = Date()
    #expect(UsageAllowance(remaining: -1, resetsAt: date).normalizedRemaining == 0)
    #expect(UsageAllowance(remaining: 2, resetsAt: date).normalizedRemaining == 1)
    #expect(UsageAllowance(remaining: .nan, resetsAt: date).normalizedRemaining == 0)
    #expect(abs(UsageAllowance(remaining: 0.78, resetsAt: date).fraction(showUsed: true) - 0.22) < 0.00001)
}

@Test func liveResponseMappingAndBucketSelection() throws {
    let data = Data(#"{"rateLimits":{"limitId":"other","primary":null},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":20,"windowDurationMins":300,"resetsAt":1790960125},"secondary":{"usedPercent":77,"windowDurationMins":10080,"resetsAt":1791071744}}}}"#.utf8)
    let value = try CodexUsageProvider.decode(data)
    #expect(abs(value.fiveHour.normalizedRemaining - 0.8) < 0.00001)
    #expect(abs(value.weekly.normalizedRemaining - 0.23) < 0.00001)
    #expect(value.fiveHour.resetsAt?.timeIntervalSince1970 == 1790960125)
}

@Test func missingLiveWindowIsRejected() {
    let data = Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":20,"windowDurationMins":300,"resetsAt":1790960125},"secondary":null}}"#.utf8)
    #expect(throws: (any Error).self) { try CodexUsageProvider.decode(data) }
}

@Test func claudeCacheMappingAndTimestamp() throws {
    let data = Data(#"{"version":2,"samples":[{"t":1790946000000,"org":"test","u":{"fh":20,"sd":75}}]}"#.utf8)
    let value = try ClaudeUsageProvider.decode(data, now: Date(timeIntervalSince1970: 1790946001))
    #expect(abs(value.fiveHour.normalizedRemaining - 0.8) < 0.00001)
    #expect(value.weekly.normalizedRemaining == 0.25)
    #expect(value.fetchedAt.timeIntervalSince1970 == 1790946000)
    #expect(value.fiveHour.resetsAt == nil)
    #expect(value.isCached)
}

@Test func claudeCacheRejectsAmbiguousOrganizationsAndMissingData() {
    let ambiguous = Data(#"{"version":2,"samples":[{"t":1000,"org":"a","u":{"fh":0,"sd":0}},{"t":2000,"org":"b","u":{"fh":0,"sd":0}}]}"#.utf8)
    #expect(throws: (any Error).self) { try ClaudeUsageProvider.decode(ambiguous) }
    let missing = Data(#"{"version":2,"samples":[{"t":1000,"org":"a","u":{"fh":0}}]}"#.utf8)
    #expect(throws: (any Error).self) { try ClaudeUsageProvider.decode(missing) }
}
