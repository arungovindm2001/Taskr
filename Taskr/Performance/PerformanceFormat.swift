//
//  PerformanceFormat.swift
//  Taskr
//
//  Text formatting and axis scaling for the Performance page.
//

import Foundation

/// Formatting helpers for the Performance page.
enum PerformanceFormat {
    /// "34%".
    static func percent(_ value: Double) -> String { String(format: "%.0f%%", value) }

    /// A transfer rate with a unit that fits its size: "0 KB/s", "812 KB/s", "3.1 MB/s", "1.2 GB/s".
    static func rate(_ bytesPerSecond: Double) -> String {
        switch bytesPerSecond {
        case ..<1_000: "0 KB/s"
        case ..<1_000_000: String(format: "%.0f KB/s", bytesPerSecond / 1e3)
        case ..<1_000_000_000: String(format: "%.1f MB/s", bytesPerSecond / 1e6)
        default: String(format: "%.1f GB/s", bytesPerSecond / 1e9)
        }
    }

    /// A size in binary gigabytes with one decimal: "11.2 GB" (matches how Activity Monitor reports RAM).
    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    /// A disk capacity in decimal units, as Finder reports it: "494.4 GB".
    static func capacity(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// "3:12:44", or "2:03:12:44" once the Mac has been up for a day.
    static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400, hours = total % 86_400 / 3_600
        let minutes = total % 3_600 / 60, secs = total % 60
        return days > 0
            ? String(format: "%d:%02d:%02d:%02d", days, hours, minutes, secs)
            : String(format: "%d:%02d:%02d", hours, minutes, secs)
    }

    /// The smallest "nice" axis maximum (1, 2, 5 × a power of ten) that is at least `value`, and at least `floor`.
    static func niceMax(_ value: Double, floor minimum: Double) -> Double {
        let target = max(value, minimum)
        let magnitude = pow(10, (log10(target)).rounded(.down))
        for step in [1.0, 2.0, 5.0, 10.0] where step * magnitude >= target { return step * magnitude }
        return 10 * magnitude
    }

    /// "Nominal", "Fair", "Serious" or "Critical".
    static func thermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }
}
