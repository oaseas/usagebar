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
    private var readings: [AIService: UsageSnapshot] = [:]
    private var readingErrors: [AIService: String] = [:]
    private var lastSecondaryRefresh = Date.distantPast
    private var controlTimer: Timer?
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
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
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
        controlTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.processCommand() }
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        controlTimer?.invalidate()
        publishStatus(running: false)
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

    @objc private func refreshNow() { Task { await liveProvider.invalidateCache(); refresh() } }

    private var isMock: Bool { useMock }
    private func selectProvider() {
        if isMock {
            provider = MockUsageProvider(scenario: scenario, service: service)
            Task { await liveProvider.disconnect() }
        } else {
            provider = service == .chatGPT ? liveProvider : claudeProvider
        }
    }

    private func refresh() {
        guard refreshTask == nil else { return }
        let currentProvider = provider
        let currentService = service
        let currentMock = isMock
        refreshTask = Task { [weak self] in
            do {
                let value = try await currentProvider.fetchUsage()
                guard !Task.isCancelled, let self else { return }
                self.snapshot = value
                self.readings[currentService] = value
                self.readingErrors[currentService] = nil
                self.errorMessage = nil
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.errorMessage = error.localizedDescription
                self.readingErrors[currentService] = error.localizedDescription
            }
            guard let self else { return }
            if !currentMock, Date().timeIntervalSince(self.lastSecondaryRefresh) >= 30 {
                self.lastSecondaryRefresh = Date()
                let other: AIService = currentService == .chatGPT ? .claude : .chatGPT
                let otherProvider: any UsageProvider = other == .chatGPT ? self.liveProvider : self.claudeProvider
                do {
                    let value = try await otherProvider.fetchUsage()
                    guard !Task.isCancelled else { return }
                    self.readings[other] = value
                    self.readingErrors[other] = nil
                } catch { self.readingErrors[other] = error.localizedDescription }
            }
            guard !Task.isCancelled else { return }
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
        publishStatus()
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
        button.toolTip = detail + (snapshot?.isStale == true ? " Cached reading is over 10 minutes old. Open Claude Settings → Usage to update it." : "") + (forced ? " Weekly limit exhausted." : "") + (errorMessage.map { " Last refresh failed: \($0)" } ?? "") + " Left-click to toggle; right-click for settings."
        button.setAccessibilityLabel("UsageBar, " + detail)
    }

    private func add(_ title: String, to menu: NSMenu, action: Selector? = nil, tag: Int = 0, checked: Bool = false) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.tag = tag
        item.state = checked ? .on : .off
        menu.addItem(item)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        add("UsageBar: \(service.rawValue) \(isMock ? "MOCK DATA" : service == .claude ? "LOCAL CACHE" : "LIVE")", to: menu)
        if !isMock {
            add(service == .chatGPT ? "ChatGPT account ´ Codex allowance" : "Claude Desktop cached percentages", to: menu)
            if service == .claude { add("Claude records at most every 4Ž minutes", to: menu) }
        }
        let serviceMenu = NSMenu()
        for (index, value) in AIService.allCases.enumerated() {
            add(value.rawValue, to: serviceMenu, action: #selector(changeService(_:)), tag: index, checked: value == service)
        }
        let serviceItem = NSMenuItem(title: "AI service", action: nil, keyEquivalent: "")
        serviceItem.submenu = serviceMenu
        menu.addItem(serviceItem)

        for window in [UsageWindow.fiveHour, .weekly] {
            let name = window == .fiveHour ? "5-hour" : "Weekly"
            if let snapshot {
                let allowance = snapshot[window]
                add("\(name): \(Int((allowance.normalizedRemaining * 100).rounded()))% remaining", to: menu)
                if let reset = allowance.resetsAt {
                    add("Resets \(reset.formatted(date: .abbreviated, time: .shortened))", to: menu)
                } else { add("Reset time unavailable from local cache", to: menu) }
            } else { add("\(name): unavailable", to: menu) }
        }

        if let snapshot {
            add("\(snapshot.isCached ? "Claude sample" : "Updated") \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .standard))", to: menu)
            if snapshot.isStale { add("STALE: open Claude Settings → Usage", to: menu) }
            if snapshot.weekly.normalizedRemaining == 0 && snapshot.fiveHour.normalizedRemaining > 0 {
                add("Weekly limit exhausted: showing weekly", to: menu)
            }
        }
        if let errorMessage { add("Refresh failed: \(errorMessage)", to: menu) }
        menu.addItem(.separator())

        let widthMenu = NSMenu()
        for width in widths { add("\(width) pt", to: widthMenu, action: #selector(changeWidth(_:)), tag: width, checked: width == gaugeWidth) }
        let widthItem = NSMenuItem(title: "Gauge width", action: nil, keyEquivalent: "")
        widthItem.submenu = widthMenu
        menu.addItem(widthItem)

        let colorMenu = NSMenu()
        for (index, title) in ["Monochrome", "Single color (blue)", "Capacity colors (green → red)"].enumerated() {
            add(title, to: colorMenu, action: #selector(changeColor(_:)), tag: index, checked: colorStyle == index)
        }
        let colorItem = NSMenuItem(title: "Gauge color", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        let dataMenu = NSMenu()
        if service == .chatGPT { add("Live: existing ChatGPT/Codex session", to: dataMenu, action: #selector(changeDataMode(_:)), tag: 0, checked: !useMock) }
        if service == .claude { add("Real percentages: desktop local cache", to: dataMenu, action: #selector(changeDataMode(_:)), tag: 0, checked: !useMock) }
        add("Mock (demo)", to: dataMenu, action: #selector(changeDataMode(_:)), tag: 1, checked: isMock)
        let dataItem = NSMenuItem(title: "Data source", action: nil, keyEquivalent: "")
        dataItem.submenu = dataMenu
        menu.addItem(dataItem)

        let displayMenu = NSMenu()
        add("Remaining", to: displayMenu, action: #selector(changeDisplay(_:)), tag: 0, checked: !showUsed)
        add("Used", to: displayMenu, action: #selector(changeDisplay(_:)), tag: 1, checked: showUsed)
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        let intervalMenu = NSMenu()
        for interval in intervals {
            add(interval < 60 ? "\(interval) seconds" : "\(interval / 60) minute\(interval == 60 ? "" : "s")", to: intervalMenu, action: #selector(changeInterval(_:)), tag: interval, checked: interval == refreshInterval)
        }
        let intervalItem = NSMenuItem(title: "Display refresh interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        add("Refresh now", to: menu, action: #selector(refreshNow))
        add("Launch at login", to: menu, action: #selector(toggleStartup), checked: DesktopIntegration.startsAtLogin)

        let mockMenu = NSMenu()
        for (index, value) in MockUsageProvider.Scenario.allCases.enumerated() {
            add(value.title, to: mockMenu, action: #selector(changeScenario(_:)), tag: index, checked: value == scenario)
        }
        let mockItem = NSMenuItem(title: "Mock scenarios", action: nil, keyEquivalent: "")
        mockItem.submenu = mockMenu
        if isMock { menu.addItem(mockItem) }
        menu.addItem(.separator())
        add("About UsageBar", to: menu, action: #selector(about))
        add("Quit UsageBar", to: menu, action: #selector(quit))
        return menu
    }

    @objc private func changeWidth(_ sender: NSMenuItem) {
        gaugeWidth = sender.tag
        defaults.set(gaugeWidth, forKey: "gaugeWidth")
        render()
    }
    @objc private func changeDisplay(_ sender: NSMenuItem) {
        showUsed = sender.tag == 1
        defaults.set(showUsed, forKey: "showUsed")
        render()
    }
    @objc private func changeInterval(_ sender: NSMenuItem) {
        refreshInterval = sender.tag
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(true, forKey: "fastRefreshConfigured")
        scheduleTimer()
        render()
    }
    @objc private func changeScenario(_ sender: NSMenuItem) {
        refreshTask?.cancel()
        refreshTask = nil
        scenario = MockUsageProvider.Scenario.allCases[sender.tag]
        selectProvider()
        refresh()
    }
    @objc private func changeService(_ sender: NSMenuItem) {
        refreshTask?.cancel()
        refreshTask = nil
        snapshot = nil
        errorMessage = nil
        requestedWindow = .fiveHour
        service = AIService.allCases[sender.tag]
        defaults.set(service.rawValue, forKey: "service")
        selectProvider()
        render()
        refresh()
    }
    @objc private func changeColor(_ sender: NSMenuItem) {
        colorStyle = sender.tag
        defaults.set(colorStyle, forKey: "colorStyle")
        render()
    }
    @objc private func changeDataMode(_ sender: NSMenuItem) {
        refreshTask?.cancel()
        refreshTask = nil
        snapshot = nil
        errorMessage = nil
        useMock = sender.tag == 1
        defaults.set(useMock, forKey: "useMock")
        selectProvider()
        render()
        refresh()
    }
    @objc private func toggleStartup() {
        do {
            try DesktopIntegration.setStartsAtLogin(!DesktopIntegration.startsAtLogin)
            if DesktopIntegration.requiresLoginApproval {
                let alert = NSAlert()
                alert.messageText = "Approval required"
                alert.informativeText = "macOS requires approval before UsageBar can launch at login."
                alert.addButton(withTitle: "Open Login Items")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn {
                    DesktopIntegration.openLoginItemsSettings()
                }
            }
            render()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change startup setting"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func publishStatus(running: Bool = true) {
        func allowance(_ value: UsageAllowance) -> [String: Any] {
            ["remaining": value.normalizedRemaining * 100,
             "resetsAt": value.resetsAt.map { $0.timeIntervalSince1970 as Any } ?? NSNull()]
        }
        var services: [String: Any] = [:]
        for item in AIService.allCases {
            var row: [String: Any] = ["error": readingErrors[item] ?? ""]
            if let value = readings[item] {
                row.merge(["fiveHour": allowance(value.fiveHour), "weekly": allowance(value.weekly),
                           "sampleAt": value.fetchedAt.timeIntervalSince1970, "source": value.source,
                           "cached": value.isCached, "stale": value.isStale], uniquingKeysWith: { _, new in new })
            }
            services[item.rawValue] = row
        }
        DesktopIntegration.writeStatus(["version": 1, "running": running, "pid": ProcessInfo.processInfo.processIdentifier,
            "heartbeatAt": Date().timeIntervalSince1970, "services": services,
            "settings": ["service": service.rawValue, "width": gaugeWidth, "color": colorStyle,
                         "showUsed": showUsed, "interval": refreshInterval, "mock": useMock,
                         "startup": DesktopIntegration.startsAtLogin]])
    }

    private func processCommand() {
        guard let command = DesktopIntegration.takeCommand() else { return }
        func item(_ tag: Int) -> NSMenuItem { let value = NSMenuItem(); value.tag = tag; return value }
        if let name = command["service"] as? String, let value = AIService(rawValue: name),
           let index = AIService.allCases.firstIndex(of: value) { changeService(item(index)) }
        if let width = command["width"] as? Int, widths.contains(width) { changeWidth(item(width)) }
        if let color = command["color"] as? Int, (0...2).contains(color) { changeColor(item(color)) }
        if let used = command["showUsed"] as? Bool { changeDisplay(item(used ? 1 : 0)) }
        if let interval = command["interval"] as? Int, intervals.contains(interval) { changeInterval(item(interval)) }
        if let mock = command["mock"] as? Bool { changeDataMode(item(mock ? 1 : 0)) }
        if let startup = command["startup"] as? Bool {
            do { try DesktopIntegration.setStartsAtLogin(startup) }
            catch { errorMessage = "Startup setting could not be saved." }
        }
        if command["action"] as? String == "refresh" { refreshNow() }
        if command["action"] as? String == "quit" { quit() }
        render()
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"
        alert.messageText = "UsageBar \(version)"
        if let logo = Bundle.main.url(forResource: "UsageBarLogo", withExtension: "png"),
           let image = NSImage(contentsOf: logo) {
            alert.icon = image
        } else {
            alert.icon = NSApp.applicationIconImage
        }
        alert.informativeText = "Made by oaseas\n\nA lightweight native macOS menu bar gauge for keeping an eye on your AI usage limits.\n\nChatGPT shows the Codex allowance from your existing local session. Claude optionally reads cached percentages from Claude Desktop; Claude reset times are unavailable. No separate UsageBar account or AI model calls are required.\n\nUsageBar is independent software and is not affiliated with OpenAI or Anthropic.\n\nMIT License."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub")
        alert.addButton(withTitle: "X @oaseas")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn, let url = URL(string: "https://github.com/oaseas") {
            NSWorkspace.shared.open(url)
        } else if response == .alertThirdButtonReturn, let url = URL(string: "https://x.com/oaseas") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
