import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var appearanceObservation: NSKeyValueObservation?
    private let liveProvider = CodexUsageProvider()
    private let claudeProvider = ClaudeUsageProvider()
    private var useMock = false
    private var colorStyle = 0
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var snapshot: UsageSnapshot?
    private var errorMessage: String?
    private var requestedWindow: UsageWindow = .fiveHour
    private var service: AIService = .chatGPT
    private var scenario: MockUsageProvider.Scenario = .normal
    private var provider: any UsageProvider = MockUsageProvider(scenario: .normal)
    private let defaults = UserDefaults.standard
    private let widths = [120, 180, 260, 320]
    private let intervals = [1, 5, 10, 30, 60, 300, 900]
    private var gaugeWidth: Int = 260
    private var refreshInterval: Int = 5
    private var showUsed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let saved = defaults.string(forKey: "service"), let value = AIService(rawValue: saved) {
            service = value
            provider = MockUsageProvider(scenario: scenario, service: service)
        }
        useMock = defaults.bool(forKey: "useMock")
        colorStyle = min(2, max(0, defaults.integer(forKey: "colorStyle")))
        selectProvider()
        let savedWidth = defaults.integer(forKey: "gaugeWidth")
        if widths.contains(savedWidth) { gaugeWidth = savedWidth }
        let savedInterval = defaults.integer(forKey: "refreshInterval")
        if defaults.bool(forKey: "fastRefreshConfigured"), intervals.contains(savedInterval) { refreshInterval = savedInterval }
        showUsed = defaults.bool(forKey: "showUsed")
        statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(gaugeWidth))
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.render() }
            }
        }
        render()
        scheduleTimer()
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        refreshTask?.cancel()
        Task { await liveProvider.disconnect() }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = makeMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            requestedWindow = requestedWindow == .fiveHour ? .weekly : .fiveHour
            render()
        }
    }

    @objc private func refreshNow() { refresh() }

    private var isMock: Bool { useMock }
    private func selectProvider() {
        if isMock {
            provider = MockUsageProvider(scenario: scenario, service: service)
            Task { await liveProvider.disconnect() }
        } else if service == .chatGPT {
            provider = liveProvider
        } else {
            provider = claudeProvider
            Task { await liveProvider.disconnect() }
        }
    }

    private func refresh() {
        guard refreshTask == nil else { return }
        let currentProvider = provider
        refreshTask = Task { [weak self] in
            do {
                let value = try await currentProvider.fetchUsage()
                guard !Task.isCancelled, let self else { return }
                self.snapshot = value
                self.errorMessage = nil
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.errorMessage = error.localizedDescription
            }
            guard let self else { return }
            self.refreshTask = nil
            self.render()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(refreshInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let window = snapshot?.effectiveWindow(requested: requestedWindow) ?? requestedWindow
        let fraction = snapshot?[window].fraction(showUsed: showUsed)
        let percentage = fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "N/A"
        let label = window.label + (showUsed ? " U" : " R")
        let image = NSImage(size: NSSize(width: CGFloat(gaugeWidth), height: 22))
        image.lockFocus()
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
        let ink = colorStyle == 0 ? NSColor.black : NSColor.labelColor
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: ink
        ]
        let badgeAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8, weight: .semibold), .foregroundColor: ink]
        ink.withAlphaComponent(0.4).setStroke()
        NSBezierPath(roundedRect: NSRect(x: 5, y: 5, width: 13, height: 12), xRadius: 3, yRadius: 3).stroke()
        ((service == .chatGPT ? "G" : "C") as NSString).draw(at: NSPoint(x: 8, y: 6), withAttributes: badgeAttributes)
        (label as NSString).draw(at: NSPoint(x: 23, y: 5), withAttributes: textAttributes)
        let percentSize = (percentage as NSString).size(withAttributes: textAttributes)
        (percentage as NSString).draw(at: NSPoint(x: CGFloat(gaugeWidth) - percentSize.width - 7, y: 5), withAttributes: textAttributes)
        let bar = NSRect(x: 61, y: 7, width: CGFloat(gaugeWidth) - 102, height: 8)
        let capacityColor = NSColor(calibratedHue: CGFloat((snapshot?[window].normalizedRemaining ?? 0) / 3), saturation: 0.85, brightness: 0.8, alpha: 1)
        (colorStyle == 2 ? capacityColor : ink).withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: bar, xRadius: 3, yRadius: 3).fill()
        if let fraction, fraction > 0 {
            let remaining = snapshot?[window].normalizedRemaining ?? 0
            let fillColor: NSColor = colorStyle == 0 ? .black : colorStyle == 1 ? .systemBlue : NSColor(calibratedHue: CGFloat(remaining / 3), saturation: 0.85, brightness: 0.8, alpha: 1)
            fillColor.setFill()
            let fill = NSRect(x: bar.minX, y: bar.minY, width: bar.width * fraction, height: bar.height)
            NSBezierPath(roundedRect: fill, xRadius: min(3, fill.width / 2), yRadius: 3).fill()
        }
        if errorMessage != nil || snapshot?.isStale == true {
            ink.setFill()
            NSBezierPath(ovalIn: NSRect(x: 1, y: 9, width: 3, height: 3)).fill()
        }
        }
        image.unlockFocus()
        image.isTemplate = colorStyle == 0
        statusItem.length = CGFloat(gaugeWidth)
        button.image = image
        let mode = showUsed ? "used" : "remaining"
        let forced = snapshot?.effectiveWindow(requested: .fiveHour) == .weekly
        let detail = "\(window == .fiveHour ? "5-hour" : "Weekly") usage: \(percentage) \(mode). \(snapshot?.source ?? (isMock ? "Mock data" : "Live data pending"))."

