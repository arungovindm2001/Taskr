//
//  FileVault.swift
//  Taskr
//
//  Whether FileVault disk encryption is on for the startup disk.
//

import Foundation

/// FileVault status, read from `fdesetup`.
nonisolated enum FileVault {

    /// Whether FileVault is on, from `fdesetup status`. `nil` if the tool can't be run or its output isn't understood.
    /// Blocking: call off the main thread.
    static func isEnabled() -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
        process.arguments = ["status"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        if text.contains("FileVault is On") { return true }
        if text.contains("FileVault is Off") { return false }
        return nil
    }
}
