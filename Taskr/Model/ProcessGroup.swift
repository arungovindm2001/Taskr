//
//  ProcessGroup.swift
//  Taskr
//
//  One row's worth of related processes, e.g. an app plus all of its helper processes.
//

import Foundation
import TaskrCore

/// Processes that belong together, shown as one expandable row.
///
/// Grouping follows the outermost `.app` bundle, so "Google Chrome Helper (Renderer)" rolls up under
/// "Google Chrome". Executables outside any bundle become single-process groups.
struct ProcessGroup: Identifiable {
    /// The bundle path, executable path, or `name:<name>` for processes whose path can't be read.
    let id: String
    let name: String
    let category: ProcessCategory
    /// Path used to look up the row icon (bundle, executable, or `nil` for the generic icon).
    let iconPath: String?
    var processes: [ProcessSnapshot]

    /// Share of the whole machine's CPU, summed over the group.
    var cpu: Double { processes.reduce(0) { $0 + $1.cpuPercent } }
    /// Summed physical footprint in bytes.
    var memory: UInt64 { processes.reduce(0) { $0 + $1.memoryBytes } }
    /// Summed disk read + write rate in bytes per second.
    var disk: Double { processes.reduce(0) { $0 + $1.diskBytesPerSec } }
}
