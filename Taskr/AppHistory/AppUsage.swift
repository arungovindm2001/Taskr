//
//  AppUsage.swift
//  Taskr
//
//  What App history remembers about one app: running totals of the resources it has used.
//

import Foundation

/// Cumulative resource use of one app (or other process group) since the history began.
struct AppUsage: Codable, Identifiable, Equatable {
    /// The group id from `ProcessGroup`: a bundle path, an executable path, or `name:<name>`.
    let id: String
    var name: String
    /// `ProcessCategory.rawValue` at the last sighting, used by the "Show: Apps" filter.
    var category: String
    var iconPath: String?

    /// Core-seconds of CPU time (one core busy for one second = 1).
    var cpuSeconds: Double = 0
    /// Bytes sent plus received.
    var networkBytes: Double = 0
    var diskWrittenBytes: Double = 0
    /// Energy used, in joules (watt-seconds).
    var joules: Double = 0
    /// Seconds the app was running while Taskr was recording; the divisor for its average power.
    var runningSeconds: Double = 0

    /// Average power over the time the app ran, in watts.
    var averageWatts: Double { runningSeconds > 0 ? joules / runningSeconds : 0 }
}

/// What gets written to disk.
struct AppHistoryFile: Codable {
    var since: Date
    var apps: [String: AppUsage]
}
