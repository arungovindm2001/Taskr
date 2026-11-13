//
//  StorageInfo.swift
//  Taskr
//
//  Capacity, format and encryption of the startup volume.
//

import Foundation

/// Facts about the startup volume shown on the Disk page.
nonisolated struct StorageInfo: Sendable {
    let capacity: Int64?
    let available: Int64?
    /// Volume format as macOS words it, e.g. "APFS".
    let format: String?
    let isInternal: Bool?

    /// Reads the startup volume (`/`).
    static func read() -> StorageInfo {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
                                         .volumeLocalizedFormatDescriptionKey, .volumeIsInternalKey]
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys)
        return StorageInfo(capacity: values?.volumeTotalCapacity.map(Int64.init),
                           available: values?.volumeAvailableCapacityForImportantUsage,
                           format: values?.volumeLocalizedFormatDescription,
                           isInternal: values?.volumeIsInternal)
    }

    /// Whether FileVault is on, from `fdesetup status`. `nil` if the tool can't be run or its output isn't understood.
    /// Blocking: call off the main thread.
    static func fileVaultEnabled() -> Bool? {
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
