//
//  ProcessRow.swift
//  Taskr
//
//  The flattened, display-ready rows of the Processes list.
//

import Foundation

/// One line of the list: a section header, an app/group row, or one of a group's child processes.
struct ProcessRow: Identifiable {
    enum Kind {
        /// "Apps (4)", "Background processes (10)", …
        case category
        /// An app or process group; expandable when it has more than one process.
        case group
        /// A single process inside an expanded group.
        case child
    }

    /// The values shown in the metric columns. Section headers have none.
    struct Metrics {
        var cpu: Double
        var memory: UInt64
        var disk: Double          // bytes per second
        var network: Double       // bytes per second
        var gpu: Double           // percent of GPU time
        var watts: Double         // power draw
    }

    let id: String
    let kind: Kind
    let title: String
    let iconPath: String?
    let expandable: Bool
    let expanded: Bool
    var metrics: Metrics?
    var efficient = false
    var unresponsive = false
}

/// Machine-wide figures shown at the top of each column.
struct HeaderTotals {
    var cpu: Double = 0
    var memoryPercent: Double = 0
    var disk: Double = 0
    var network: Double?
    var processCount: Int = 0
}
