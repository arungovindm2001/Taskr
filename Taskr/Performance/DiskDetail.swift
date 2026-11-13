//
//  DiskDetail.swift
//  Taskr
//
//  The Disk page: active-time and transfer-rate graphs, latency, and the startup volume's facts.
//

import SwiftUI

/// Disk detail panel.
struct DiskDetail: View {
    let store: PerformanceStore

    var body: some View {
        let transferMax = PerformanceFormat.niceMax(max(store.diskRead.peak, store.diskWrite.peak), floor: 1_000_000)
        PerformanceDetail(title: store.diskTitle, subtitle: kind, stats: stats, facts: facts) {
            VStack(spacing: 14) {
                GraphSection(title: "Active time", maxLabel: "100%", maxValue: 100,
                             series: [GraphSeries(values: store.diskActive.values, line: GraphPalette.readLine,
                                                  fill: GraphPalette.readFill, fillOpacity: 0.22)],
                             height: 150, border: GraphPalette.readFill)
                GraphSection(title: "Disk transfer rate",
                             legend: [LegendItem(color: GraphPalette.readFill, label: "Read"),
                                      LegendItem(color: GraphPalette.writeFill, label: "Write")],
                             maxLabel: PerformanceFormat.rate(transferMax), maxValue: transferMax,
                             series: [GraphSeries(values: store.diskRead.values, line: GraphPalette.readLine,
                                                  fill: GraphPalette.readFill, fillOpacity: 0.2),
                                      GraphSeries(values: store.diskWrite.values, line: GraphPalette.writeLine,
                                                  fill: GraphPalette.writeFill, fillOpacity: 0.2)],
                             height: 150, border: GraphPalette.readFill)
            }
        }
    }

    /// Internal Apple silicon storage is always NVMe flash; elsewhere we only know internal vs external.
    private var kind: String {
        let internalDisk = store.storage.isInternal ?? true
        if internalDisk && store.hardware.isAppleSilicon { return "Internal SSD" }
        return internalDisk ? "Internal disk" : "External disk"
    }

    private var stats: [PerformanceStat] {
        let s = store.latest
        return [PerformanceStat(label: "Active time", value: PerformanceFormat.percent(s?.diskActive ?? 0)),
                PerformanceStat(label: "Avg response time", value: s?.diskLatencyMs.map { String(format: "%.1f ms", $0) } ?? "–"),
                PerformanceStat(label: "Read speed", value: PerformanceFormat.rate(s?.diskRead ?? 0)),
                PerformanceStat(label: "Write speed", value: PerformanceFormat.rate(s?.diskWrite ?? 0))]
    }

    private var facts: [PerformanceFact] {
        let storage = store.storage
        return [PerformanceFact(label: "Capacity", value: storage.capacity.map(PerformanceFormat.capacity) ?? "–"),
                PerformanceFact(label: "Available", value: storage.available.map(PerformanceFormat.capacity) ?? "–"),
                PerformanceFact(label: "System disk", value: "Yes"),
                PerformanceFact(label: "Type", value: store.hardware.isAppleSilicon && (storage.isInternal ?? true) ? "SSD (NVMe)" : kind),
                PerformanceFact(label: "Encryption", value: store.fileVault.map { $0 ? "FileVault on" : "FileVault off" } ?? "–")]
    }
}
