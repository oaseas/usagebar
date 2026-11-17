import AppKit
import CryptoKit

@MainActor
final class AppUpdater {
    private var checking = false
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    var automatic: Bool { defaults.bool(forKey: "automaticUpdates") }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 6*3600, repeats: true) { [weak self] _ in
            Task { @MainActor in if self?.automatic == true { await self?.check(interactive: false) } }
        }
        if automatic { Task { await check(interactive: false) } }
    }
    func toggle() {
        defaults.set(!automatic, forKey: "automaticUpdates")
        if automatic { Task { await check(interactive: false) } }
    }
    struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL; let size: Int }
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }
    nonisolated static func isNewer(_ proposed: String, than current: String) -> Bool {
        func components(_ s: String) -> [Int]? {
            let clean = s.hasPrefix("v") ? String(s.dropFirst()) : s
            let parts = clean.split(separator: ".", omittingEmptySubsequences: false)
            guard (2...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
            let result = parts.compactMap { Int($0) }
            return result.count == parts.count ? result + Array(repeating: 0, count: 3-result.count) : nil
        }
        guard let a = components(proposed), let b = components(current) else { return false }
        return b.lexicographicallyPrecedes(a)
    }
    private func message(_ title: String, _ body: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = body; alert.runModal()
    }
    private func fetch(_ url: URL, limit: Int) async throws -> Data {
        var request = URLRequest(url: url); request.timeoutInterval = 60
        request.setValue("UsageBar", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count <= limit else {
            throw UsageProviderError(message: "Update download failed or exceeded its size limit.")
        }
        return data
    }
    private func run(_ executable: String, _ arguments: [String]) throws -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        try p.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UsageProviderError(message: "Update validation failed: " + executable) }
        return String(decoding: data, as: UTF8.self)
    }
    private func validateLinks(_ app: URL) throws {
        if let files = FileManager.default.enumerator(at: app, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            for case let url as URL in files {
                if try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true { throw UsageProviderError(message: "Update contains unsupported symbolic links.") }
            }
        }
    }
    func check(interactive: Bool) async {
        guard !checking else { return }
        checking = true; defer { checking = false }
        do {
            let api = URL(string: "https://api.github.com/repos/oaseas/usagebar/releases/latest")!
            let release = try JSONDecoder().decode(Release.self, from: await fetch(api, limit: 1_000_000))
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
            guard !release.draft, !release.prerelease, Self.isNewer(release.tag_name, than: current) else {
                if interactive { message("No newer release", "Installed: \(current). Latest GitHub release: \(release.tag_name). Local development builds are never downgraded.") }
                return
            }
            let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
            let filename = "UsageBar-\(version)-macos-universal.zip"
            guard let asset = release.assets.first(where: { $0.name == filename }), asset.size <= 20_000_000,
                  let checksum = release.assets.first(where: { $0.name == filename + ".sha256" }) else {
                throw UsageProviderError(message: "Release has no supported Universal app ZIP and SHA-256 checksum.")
            }
            for item in [asset, checksum] {
                guard item.browser_download_url.scheme == "https", item.browser_download_url.host == "github.com",
                      item.browser_download_url.path.hasPrefix("/oaseas/usagebar/releases/download/") else {
                    throw UsageProviderError(message: "Update asset is outside the official UsageBar repository.")
                }
            }
            if interactive {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert(); alert.messageText = "UsageBar \(version) is available"
                alert.informativeText = "Download, verify and install the official GitHub release, then restart UsageBar? Settings will be retained."
                alert.addButton(withTitle: "Install and Restart"); alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
            let target = Bundle.main.bundleURL
            guard target.pathExtension == "app", FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
                throw UsageProviderError(message: "Move UsageBar to a writable Applications folder before using in-app updates.")
            }
            let data = try await fetch(asset.browser_download_url, limit: 20_000_000)
            let hashData = try await fetch(checksum.browser_download_url, limit: 4096)
            let expected = String(decoding: hashData, as: UTF8.self).split(whereSeparator: \.isWhitespace).first.map(String.init)?.lowercased()
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard expected == actual else { throw UsageProviderError(message: "Update checksum does not match; nothing was installed.") }
            let stage = FileManager.default.temporaryDirectory.appendingPathComponent("usagebar-update-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let zip = stage.appendingPathComponent("update.zip"); try data.write(to: zip)
            let entries = try run("/usr/bin/unzip", ["-Z1", zip.path]).split(separator: "\n")
            guard !entries.isEmpty, entries.allSatisfy({ entry in
                !entry.hasPrefix("/") && !entry.split(separator: "/").contains("..") && (entry.hasPrefix("UsageBar.app/") || entry.hasPrefix("__MACOSX/"))
            }) else { throw UsageProviderError(message: "Unsafe update archive paths.") }
            let listing = try run("/usr/bin/unzip", ["-Z", "-l", zip.path])
            guard !listing.split(separator: "\n").contains(where: { $0.hasPrefix("l") }) else {
                throw UsageProviderError(message: "Update archive contains unsupported symbolic links.")
            }
            let extracted = stage.appendingPathComponent("extracted")
            try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
            _ = try run("/usr/bin/ditto", ["-x", "-k", zip.path, extracted.path])
            let app = extracted.appendingPathComponent("UsageBar.app")
            try validateLinks(app)
            let info = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
            guard let plist = try PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any],
                  plist["CFBundleIdentifier"] as? String == "io.github.oaseas.usagebar",
                  plist["CFBundleShortVersionString"] as? String == version,
                  plist["CFBundleExecutable"] as? String == "UsageBar" else { throw UsageProviderError(message: "Update app identity or version mismatch.") }
            _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
            if let settings = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") {
                defaults.setPersistentDomain(settings, forName: "io.github.oaseas.usagebar")
            }
            let backup = target.deletingLastPathComponent().appendingPathComponent("UsageBar-backup-" + UUID().uuidString + ".app")
            let helper = Process(); helper.executableURL = URL(fileURLWithPath: "/bin/sh")
            helper.arguments = ["-c", #"i=0; while kill -0 "$1" 2>/dev/null && [ "$i" -lt 30 ]; do sleep 1; i=$((i+1)); done; kill -0 "$1" 2>/dev/null && exit 1; /bin/mv "$2" "$3" || exit 1; if /bin/mv "$4" "$2"; then /usr/bin/open "$2"; else /bin/mv "$3" "$2"; /usr/bin/open "$2"; fi"#, "usagebar-update", String(ProcessInfo.processInfo.processIdentifier), target.path, backup.path, app.path]
            helper.standardOutput = FileHandle.nullDevice; helper.standardError = FileHandle.nullDevice
            try helper.run()
            NSApp.terminate(nil)
        } catch {
            if interactive { message("Could not update UsageBar", error.localizedDescription) }
        }
    }
}
