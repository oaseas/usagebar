import Foundation

enum GaugeLayout: Int, CaseIterable, Sendable {
    case fiveHour, weekly, both, countdown

    var title: String {
        switch self {
        case .fiveHour: "5-hour gauge"
        case .weekly: "Weekly gauge"
        case .both: "5-hour + weekly gauges"
        case .countdown: "5-hour gauge + countdown"
        }
    }

    func next(width: Int) -> GaugeLayout {
        let count = width >= 260 ? 4 : 2
        return GaugeLayout(rawValue: (rawValue + 1) % count) ?? .fiveHour
    }

    func fitted(width: Int) -> GaugeLayout {
        width < 260 && rawValue > 1 ? .fiveHour : self
    }

    static func countdownText(reset: Date?, now: Date = Date()) -> String {
        guard let reset else { return "--:--:--" }
        let seconds = max(0, Int(ceil(reset.timeIntervalSince(now))))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }
}
