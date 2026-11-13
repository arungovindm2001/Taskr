//
//  Format.swift
//  TaskrCore
//
//  Human-readable sizes and rates.
//

import Foundation

/// Formatting helpers shared by the app and the command-line sampler.
public enum Format {
    /// A memory size in the style Activity Monitor uses, e.g. "1.5 GB".
    public static func bytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    /// A transfer rate, e.g. "3.2 MB/s", or "0 MB/s" when idle.
    public static func rate(_ bytesPerSecond: Double) -> String {
        bytesPerSecond < 1
            ? "0 MB/s"
            : ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }
}
