import Foundation
import ServiceManagement

@MainActor
enum DesktopIntegration {
    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/UsageBar")

    static var startsAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresLoginApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setStartsAtLogin(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func writeStatus(_ data: [String: Any]) {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let url = directory.appendingPathComponent("status.json")
            try JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])
                .write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            // Companion status is optional and must never stop the menu bar gauge.
        }
    }

    static func takeCommand() -> [String: Any]? {
        let file = directory.appendingPathComponent("command.json")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0,
              size.intValue < 8192,
              let data = try? Data(contentsOf: file) else { return nil }

        try? FileManager.default.removeItem(at: file)
        guard let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let allowed = Set(["service", "width", "color", "showUsed", "interval", "mock", "startup", "action"])
        guard Set(command.keys).isSubset(of: allowed) else { return nil }
        if let action = command["action"] as? String, !["refresh", "quit"].contains(action) { return nil }
        return command
    }
}
