//
//  ProcessActions.swift
//  Taskr
//
//  Everything the user can *do* to a process: end it, throttle it, sample it, reveal it, launch new ones.
//

import SwiftUI
import AppKit

/// Error surfaced to the user when launching a task fails.
struct RunError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Side-effecting operations on processes. Stateless; every method takes the target it acts on.
enum ProcessActions {

    // Darwin's PRIO_DARWIN_PROCESS / PRIO_DARWIN_BG, spelled out so they don't depend on macro import.
    private static let prioDarwinProcess: Int32 = 4
    private static let prioDarwinBackground: Int32 = 0x1000

    // MARK: - Alerts

    /// Shows `alert` as a sheet on the key window, or as a modal if there is none.
    private static func present(_ alert: NSAlert, _ handler: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    /// A simple warning alert with an OK button.
    static func showError(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        present(alert) { _ in }
    }

    /// Asks before ending a task. The "Force quit" checkbox is pre-ticked when `force` is `true`.
    static func confirmEnd(_ target: ProcessTarget, force: Bool = false) {
        guard AppPrefs.shared.confirmEnd else { end(target, force: force); return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to end “\(target.title)”?"
        alert.informativeText = "Unsaved data in this process will be lost. Processes it started may also stop."
        alert.addButton(withTitle: "End Task")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Force quit (ends the process immediately)"
        alert.suppressionButton?.state = force ? .on : .off
        present(alert) { response in
            guard response == .alertFirstButtonReturn else { return }
            end(target, force: alert.suppressionButton?.state == .on)
        }
    }

    /// Explains the trade-offs of Efficiency mode and calls `onConfirm` if the user accepts.
    static func confirmEfficiency(_ target: ProcessTarget, onConfirm: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Turn on Efficiency mode for “\(target.title)”?"
        alert.informativeText = "Efficiency mode lowers this process’s priority and limits its energy use. It can make the app slower or less responsive, and some apps may behave unexpectedly."
        alert.addButton(withTitle: "Turn On Efficiency Mode")
        alert.addButton(withTitle: "Cancel")
        present(alert) { response in
            if response == .alertFirstButtonReturn { onConfirm() }
        }
    }

    // MARK: - Ending and throttling

    /// Ends a task. Dock apps are asked to quit through `NSRunningApplication`; everything else gets a signal
    /// (`SIGTERM`, or `SIGKILL` when `force` is set).
    static func end(_ target: ProcessTarget, force: Bool) {
        var failed = false
        if let bundle = target.appBundlePath,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == bundle }) {
            let sent = force ? app.forceTerminate() : app.terminate()
            if !sent { failed = true }
        } else {
            for pid in target.pids where kill(pid, force ? SIGKILL : SIGTERM) != 0 { failed = true }
        }
        if failed {
            showError("Couldn’t end “\(target.title)”",
                      "macOS didn’t allow Taskr to end it. Processes owned by the system or another user can’t be ended from here.")
        }
    }

    /// Moves processes into (or out of) the background QoS class that Efficiency mode uses.
    /// - Returns: The pids that could not be changed (usually processes owned by another user).
    static func setEfficiency(_ pids: [Int32], on: Bool) -> [Int32] {
        pids.filter { setpriority(prioDarwinProcess, id_t($0), on ? prioDarwinBackground : 0) != 0 }
    }

    // MARK: - Inspecting

    /// Runs `/usr/bin/sample` against the target's main process for three seconds, then opens the report.
    static func sampleProcess(_ target: ProcessTarget) {
        guard let pid = target.primaryPid ?? target.pids.first else { return }
        let name = target.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)_sample_\(pid).txt")

        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
            process.arguments = ["\(pid)", "3", "-file", url.path, "-mayDie"]
            let errors = Pipe()
            process.standardError = errors
            process.standardOutput = Pipe()

            var failure: String?
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let text = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    failure = text.isEmpty ? "sample exited with status \(process.terminationStatus)." : text
                }
            } catch {
                failure = error.localizedDescription
            }

            let message = failure
            await MainActor.run {
                if let message { showError("Couldn’t sample “\(target.title)”", message) }
                else { NSWorkspace.shared.open(url) }
            }
        }
    }

    /// Selects the file in a Finder window.
    static func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// Opens a web search for the process name in the default browser.
    static func searchOnline(_ name: String) {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: name)]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    // MARK: - Launching

    /// "Run new task": opens a path with its default app, or runs anything else as a shell command.
    /// With `admin`, runs the command through AppleScript's administrator-privileges prompt.
    static func runTask(_ input: String, admin: Bool) throws {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let expanded = (text as NSString).expandingTildeInPath

        if admin {
            let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            var error: NSDictionary?
            NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&error)
            if let error { throw RunError(message: (error[NSAppleScript.errorMessage] as? String) ?? "The command failed.") }
            return
        }
        if FileManager.default.fileExists(atPath: expanded) {
            NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", text]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw RunError(message: error.localizedDescription) }
    }
}
