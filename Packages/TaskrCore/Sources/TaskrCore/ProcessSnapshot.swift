//
//  ProcessSnapshot.swift
//  TaskrCore
//
//  One process's readings at a single moment, as produced by `ProcessSampler`.
//

import Foundation

/// A process's resource usage at one sampling instant.
///
/// Rates (CPU, disk) are measured over the interval since the previous sample, so they are zero in the
/// first sample a `ProcessSampler` returns.
public struct ProcessSnapshot: Identifiable, Sendable, Hashable {
    public let pid: Int32
    /// The short process name from the kernel (`proc_name`), or `pid <n>` when it can't be read.
    public let name: String
    /// Share of the whole machine, like Windows Task Manager (100% = every core busy).
    public let cpuPercent: Double
    /// Physical footprint (what Activity Monitor calls "Memory").
    public let memoryBytes: UInt64
    public let diskReadBytesPerSec: Double
    public let diskWriteBytesPerSec: Double

    /// Disk read + write rate in bytes per second.
    public var diskBytesPerSec: Double { diskReadBytesPerSec + diskWriteBytesPerSec }
    public var id: Int32 { pid }
}
