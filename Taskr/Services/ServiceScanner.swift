//
//  ServiceScanner.swift
//  Taskr
//
//  Lists launchd jobs and starts, stops and restarts them.
//

import Foundation

/// Reads and controls launchd services. Everything here blocks: call off the main thread.
nonisolated enum ServiceScanner {

    // MARK: Listing

    /// Jobs in the system domain and in the current user's GUI domain.
    static func scan() -> [ServiceItem] {
        let descriptions = descriptionsByLabel()
        let uid = getuid()
        var items: [ServiceItem] = []
        for domain in ["system", "gui/\(uid)"] {
            let output = run("/bin/launchctl", ["print", domain]).output
            for entry in parseServices(output) {
                items.append(ServiceItem(id: "\(domain)/\(entry.label)", label: entry.label, domain: domain, pid: entry.pid,
                                         description: descriptions[entry.label] ?? readableName(entry.label)))
            }
        }
        return items
    }

    /// Reads the `services = { … }` block of `launchctl print`: one `PID  status  label` line per job.
    static func parseServices(_ output: String) -> [(label: String, pid: Int32?)] {
        var result: [(String, Int32?)] = []
        var inBlock = false
        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if !inBlock { inBlock = line == "services = {"; continue }
            if line == "}" { break }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 3 else { continue }
            // launchd prints `-` or `0` for a job that isn't running.
            let label = String(parts[2])
            if label.hasPrefix("application.") { continue }   // one-off per-launch jobs for each open app
            result.append((label, Int32(parts[0]).flatMap { $0 > 0 ? $0 : nil }))
        }
        return result
    }

    // MARK: Control

    enum Action { case start, stop, restart }

    /// Runs `action` on `service`. System jobs need an administrator password, so they go through the standard
    /// macOS prompt. Returns an error message, or `nil` on success.
    static func perform(_ action: Action, on service: ServiceItem) -> String? {
        let arguments: [String]
        switch action {
        case .start: arguments = ["kickstart", service.target]
        case .restart: arguments = ["kickstart", "-k", service.target]
        case .stop: arguments = ["kill", "SIGTERM", service.target]
        }
        let result: (status: Int32, output: String)
        if service.isSystem {
            let command = (["/bin/launchctl"] + arguments).map { "'\($0)'" }.joined(separator: " ")
            result = run("/usr/bin/osascript", ["-e", "do shell script \"\(command)\" with administrator privileges"])
        } else {
            result = run("/bin/launchctl", arguments)
        }
        if result.status == 0 { return nil }
        return result.output.isEmpty ? "launchctl failed (\(result.status))." : result.output
    }

    // MARK: Descriptions

    /// Friendly names from the launchd property lists on disk: the app or program a job runs.
    private static func descriptionsByLabel() -> [String: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let directories = ["/System/Library/LaunchDaemons", "/Library/LaunchDaemons", "/System/Library/LaunchAgents",
                           "/Library/LaunchAgents", "\(home)/Library/LaunchAgents"]
        var map: [String: String] = [:]
        for directory in directories {
            for file in (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? [] where file.hasSuffix(".plist") {
                guard let plist = NSDictionary(contentsOfFile: "\(directory)/\(file)") as? [String: Any],
                      let label = plist["Label"] as? String else { continue }
                let program = (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
                guard let program else { continue }
                var name = URL(fileURLWithPath: program).lastPathComponent
                if let range = program.range(of: ".app/") {
                    name = URL(fileURLWithPath: String(program[..<range.lowerBound])).lastPathComponent
                        .replacingOccurrences(of: ".app", with: "")
                }
                map[label] = name
            }
        }
        return map
    }

    /// "com.docker.vmnetd" → "vmnetd" when nothing better is known.
    private static func readableName(_ label: String) -> String {
        let parts = label.split(separator: ".")
        return parts.count > 2 ? parts.dropFirst(2).joined(separator: ".") : label
    }

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
