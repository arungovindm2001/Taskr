//
//  Heat.swift
//  Taskr
//
//  The four-step "heat" tint behind resource cells, plus the thresholds that decide each cell's tier.
//

import SwiftUI

/// Four-step tint used behind CPU / Memory / Disk / Network / GPU cells, like Windows Task Manager.
///
/// A tier is `0` (no tint) through `4` (hottest). Each metric has an ascending list of four
/// thresholds; a value's tier is the number of thresholds it has reached.
enum Heat {
    private static let light: [Color] = [Color(hex: 0xfff6d6), Color(hex: 0xffeaa0), Color(hex: 0xffd36b), Color(hex: 0xffb454)]
    private static let dark: [Color] = [Color(hex: 0x3d3416), Color(hex: 0x554510), Color(hex: 0x6e540e), Color(hex: 0x8a5f10)]

    /// Tier for `value`: 0 below the first threshold, up to 4 at or above the last.
    static func tier(_ value: Double, _ thresholds: [Double]) -> Int {
        var tier = 0
        for (index, threshold) in thresholds.enumerated() where value >= threshold { tier = index + 1 }
        return tier
    }

    /// The fill for a tier in the given appearance. Tier 0 is clear.
    static func color(_ tier: Int, dark isDark: Bool) -> Color {
        guard tier > 0 else { return .clear }
        return (isDark ? dark : light)[min(tier, 4) - 1]
    }

    // MARK: Per-row thresholds

    /// % of the whole machine's CPU.
    static let cpu: [Double] = [0.5, 3, 8, 12]
    static let memoryMB: [Double] = [100, 500, 1500, 2500]
    static let diskMBps: [Double] = [0.05, 1, 10, 30]
    static let networkMbps: [Double] = [0.1, 1, 5, 20]
    /// % of GPU time.
    static let gpu: [Double] = [0.5, 5, 20, 50]

    // MARK: Column-header (whole machine) thresholds

    static let cpuTotal: [Double] = [10, 25, 50, 75]
    static let memoryTotalPct: [Double] = [25, 50, 70, 90]
    static let diskTotalMBps: [Double] = [0.5, 5, 30, 100]
    static let networkTotalMbps: [Double] = [1, 10, 50, 200]
    static let gpuTotal: [Double] = [5, 20, 50, 80]
}
