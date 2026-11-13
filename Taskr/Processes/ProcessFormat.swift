//
//  ProcessFormat.swift
//  Taskr
//
//  Text formatting for the numbers shown in the Processes list.
//

import Foundation
import TaskrCore

/// Pure formatting helpers, kept out of the views so they are easy to test and reuse on other pages.
enum ProcessFormat {
    /// "12%" for whole-machine totals.
    static func percent(_ value: Double) -> String { String(format: "%.0f%%", value) }

    /// "0.4%" for a single row's CPU or GPU share.
    static func rowPercent(_ value: Double) -> String { String(format: "%.1f%%", value) }

    /// "1.2 MB/s", or "0 MB/s" when idle.
    static func disk(_ bytesPerSecond: Double) -> String {
        bytesPerSecond < 1 ? "0 MB/s" : String(format: "%.1f MB/s", bytesPerSecond / 1e6)
    }

    /// "3.4 Mbps", "306 Mbps" (no decimal from 100 up, like Windows), or "0 Mbps" below 0.05 Mbps.
    static func network(_ bytesPerSecond: Double) -> String {
        let mbps = bytesPerSecond * 8 / 1e6
        if mbps < 0.05 { return "0 Mbps" }
        return String(format: mbps >= 100 ? "%.0f Mbps" : "%.1f Mbps", mbps)
    }

    /// Memory either as a size ("1.5 GB") or as a share of installed RAM ("9.3%").
    static func memory(_ bytes: UInt64, asPercent: Bool, installed: Double) -> String {
        asPercent ? rowPercent(Double(bytes) / installed * 100) : Format.bytes(bytes)
    }

    // MARK: Energy impact

    /// Labels for the five energy levels, lowest first.
    static let energyLabels = ["Very low", "Low", "Moderate", "High", "Very high"]

    /// Maps a power draw in watts to an energy level, `0` (Very low) through `4` (Very high).
    static func energyLevel(watts: Double) -> Int {
        switch watts {
        case ..<0.05: 0
        case ..<0.3: 1
        case ..<1: 2
        case ..<3: 3
        default: 4
        }
    }
}
