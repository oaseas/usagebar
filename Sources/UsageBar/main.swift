import AppKit

if CommandLine.arguments.contains("--check-claude") {
    Task {
        do {
            let value = try await ClaudeUsageProvider().fetchUsage()
            print("Claude cache: 5H \(Int((value.fiveHour.normalizedRemaining * 100).rounded()))% remaining; weekly \(Int((value.weekly.normalizedRemaining * 100).rounded()))% remaining. Sample \(value.fetchedAt.formatted()).")
            exit(0)
        } catch {
            print("Claude check failed: \(error.localizedDescription)")
            exit(1)
        }
    }
    RunLoop.main.run()
}

if CommandLine.arguments.contains("--check-live") {
    Task {
        let provider = CodexUsageProvider()
        do {
            let value = try await provider.fetchUsage()
            print("Live check: 5H \(Int((value.fiveHour.normalizedRemaining * 100).rounded()))% remaining; weekly \(Int((value.weekly.normalizedRemaining * 100).rounded()))% remaining. \(value.source)")
            await provider.disconnect()
            exit(0)
        } catch {
            print("Live check failed: \(error.localizedDescription)")
            await provider.disconnect()
            exit(1)
        }
    }
    RunLoop.main.run()
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
