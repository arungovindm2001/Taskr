//
//  StartupScanner.swift
//  Taskr
//
//  Finds startup items on disk and asks launchd which of them are switched off.
//

import Foundation
import Security

/// Reads startup items. Everything here blocks (file reads, `launchctl`, `osascript`): call off the main thread.
nonisolated enum StartupScanner {

    // MARK: Public

    /// Every launch agent that runs at login, plus the user's login items.
    static func scan() -> [StartupItem] {
        let disabled = disabledLabels()
        return launchAgents(disabled: disabled) + loginItems()
    }

    /// Switches a launch agent on or off for the next login, via launchd's per-user override database.
    /// - Returns: An error message, or `nil` on success.
    static func setEnabled(_ enabled: Bool, label: String) -> String? {
        let result = run("/bin/launchctl", [enabled ? "enable" : "disable", "gui/\(getuid())/\(label)"])
        return result.status == 0 ? nil : (result.output.isEmpty ? "launchctl failed (\(result.status))." : result.output)
    }

    // MARK: Launch agents

    private static func launchAgents(disabled: Set<String>) -> [StartupItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var items: [StartupItem] = []
        for directory in ["\(home)/Library/LaunchAgents", "/Library/LaunchAgents"] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
            for file in names.sorted() where file.hasSuffix(".plist") {
                let path = "\(directory)/\(file)"
                guard let plist = NSDictionary(contentsOfFile: path) as? [String: Any],
                      let label = plist["Label"] as? String,
                      startsAtLogin(plist) else { continue }

                let program = (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
                let target = program.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
                let app = target.flatMap { ProcessGrouping.bundlePath($0) }
                items.append(StartupItem(
                    id: path,
                    name: app.map(displayName(ofApp:)) ?? target.map { URL(fileURLWithPath: $0).lastPathComponent } ?? readableName(fromLabel: label),
                    developer: target.map(developer(ofItemAt:)) ?? "Unknown",
                    kind: .launchAgent,
                    isEnabled: !disabled.contains(label) && (plist["Disabled"] as? Bool) != true,
                    label: label, plistPath: path, targetPath: app ?? target))
            }
        }
        return items
    }

    /// An agent starts at login if it asks to run at load or to be kept alive.
    private static func startsAtLogin(_ plist: [String: Any]) -> Bool {
        if (plist["RunAtLoad"] as? Bool) == true { return true }
        if let keepAlive = plist["KeepAlive"] as? Bool { return keepAlive }
        return plist["KeepAlive"] is [String: Any]
    }

    /// Labels the user has switched off, from `launchctl print-disabled gui/<uid>`.
    private static func disabledLabels() -> Set<String> {
        let output = run("/bin/launchctl", ["print-disabled", "gui/\(getuid())"]).output
        var labels = Set<String>()
        for line in output.split(separator: "\n") where line.contains("=>") {
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2, parts[1].contains("disabled") || parts[1].contains("true") else { continue }
            labels.insert(parts[0].trimmingCharacters(in: CharacterSet(charactersIn: " \t\"")))
        }
        return labels
    }

    // MARK: Login items

    /// Items under "Open at Login", from System Events. The first call makes macOS ask for permission;
    /// if it's refused there are simply no login items listed.
    private static func loginItems() -> [StartupItem] {
        let script = "Application('System Events').loginItems().map(function(i){return i.name()+'\\t'+i.path()}).join('\\n')"
        let result = run("/usr/bin/osascript", ["-l", "JavaScript", "-e", script])
        guard result.status == 0 else { return [] }
        return result.output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", maxSplits: 1).map(String.init)
            guard fields.count == 2 else { return nil }
            return StartupItem(id: fields[1], name: fields[0], developer: developer(ofItemAt: fields[1]),
                               kind: .loginItem, isEnabled: true, label: nil, plistPath: nil, targetPath: fields[1])
        }
    }

    // MARK: Helpers

    /// A friendlier name for an agent whose program isn't in an app: drops the "com.vendor." prefix of its label.
    private static func readableName(fromLabel label: String) -> String {
        let parts = label.split(separator: ".")
        return parts.count > 2 ? parts.dropFirst(2).joined(separator: ".") : label
    }

    private static func displayName(ofApp path: String) -> String {
        let info = Bundle(path: path)?.infoDictionary
        return (info?["CFBundleDisplayName"] as? String) ?? (info?["CFBundleName"] as? String)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    /// The signer's name from the code signature, e.g. "Docker Inc." from "Developer ID Application: Docker Inc. (ABC123)".
    private static func developer(ofItemAt path: String) -> String {
        let url = URL(fileURLWithPath: ProcessGrouping.bundlePath(path) ?? path) as CFURL
        var code: SecStaticCode?
        var info: CFDictionary?
        guard SecStaticCodeCreateWithPath(url, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let certificates = (info as? [String: Any])?[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first,
              var name = SecCertificateCopySubjectSummary(leaf) as String? else { return "Unknown" }

        if name == "Software Signing" || name.hasPrefix("Apple") && !name.contains(":") { return "Apple" }
        if let colon = name.range(of: ": ") { name = String(name[colon.upperBound...]) }     // drop "Developer ID Application: "
        if let open = name.range(of: " (", options: .backwards), name.hasSuffix(")") { name = String(name[..<open.lowerBound]) }   // drop team id
        return name
    }

    /// Runs a tool and returns its exit status and combined output.
    private static func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
