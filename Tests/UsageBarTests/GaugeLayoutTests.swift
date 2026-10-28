import Foundation
import Testing
@testable import UsageBar

@Test func layoutCycleRespectsWidth() {
    #expect(GaugeLayout.fiveHour.next(width: 120) == .weekly)
    #expect(GaugeLayout.weekly.next(width: 180) == .fiveHour)
    #expect(GaugeLayout.weekly.next(width: 260) == .both)
    #expect(GaugeLayout.both.next(width: 320) == .countdown)
    #expect(GaugeLayout.countdown.next(width: 400) == .fiveHour)
    #expect(GaugeLayout.countdown.fitted(width: 120) == .fiveHour)
}
@Test func countdownHandlesMissingDueAndHours() {
    let now = Date(timeIntervalSince1970: 1000)
    #expect(GaugeLayout.countdownText(reset: nil, now: now) == "--:--:--")
    #expect(GaugeLayout.countdownText(reset: now.addingTimeInterval(-3), now: now) == "00:00:00")
    #expect(GaugeLayout.countdownText(reset: now.addingTimeInterval(8096), now: now) == "02:14:56")
}
