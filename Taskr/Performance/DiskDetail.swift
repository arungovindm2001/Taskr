//
//  DiskDetail.swift
//  Taskr
//
//  The Disk page for one physical disk: active-time and transfer-rate graphs, latency, and the disk's facts.
//

import SwiftUI

/// Disk detail panel. Shown once per physical disk (internal SSD, each external drive).
struct DiskDetail: View {
    let store: PerformanceStore
    /// BSD name of the disk to show, e.g. "disk0".
    let diskID: String

    var body: some View {
        if let disk = store.disks.first(where: { $0.id == diskID }) {
            content(for: disk)
        }
    }

    private func content(for disk: PhysicalDisk) -> some View {
        let history = store.diskHistory[disk.id] ?? DiskHistory()
        let transferMax = PerformanceFormat.niceMax(max(history.read.peak, history.write.peak), floor: 1_000_000)
        return PerformanceDetail(title: store.diskTitle(disk), subtitle: disk.model ?? (disk.isInternal ? "Internal disk" : "External disk"),
                                 stats: stats(history.latest), facts: facts(for: disk)) {
            VStack(spacing: 14) {
                GraphSection(title: "Active time", maxLabel: "100%", maxValue: 100,
                             series: [GraphSeries(values: history.active.values, line: GraphPalette.readLine,
                                                  fill: GraphPalette.readFill, fillOpacity: 0.22)],
                             minHeight: 110, border: GraphPalette.readFill)
                GraphSection(title: "Disk transfer rate",
                             legend: [LegendItem(color: GraphPalette.readFill, label: "Read"),
                                      LegendItem(color: GraphPalette.writeFill, label: "Write")],
                             maxLabel: PerformanceFormat.rate(transferMax), maxValue: transferMax,
                             series: [GraphSeries(values: history.read.values, line: GraphPalette.readLine,
                                                  fill: GraphPalette.readFill, fillOpacity: 0.2),
                                      GraphSeries(values: history.write.values, line: GraphPalette.writeLine,
                                                  fill: GraphPalette.writeFill, fillOpacity: 0.2)],
                             minHeight: 110, border: GraphPalette.readFill)
            }
        }
    }

    private func stats(_ latest: DiskSample?) -> [PerformanceStat] {
        [PerformanceStat(label: "Active time", value: PerformanceFormat.percent(latest?.active ?? 0)),
         PerformanceStat(label: "Avg response time", value: latest?.latencyMs.map { String(format: "%.1f ms", $0) } ?? "–"),
         PerformanceStat(label: "Read speed", value: PerformanceFormat.rate(latest?.read ?? 0)),
         PerformanceStat(label: "Write speed", value: PerformanceFormat.rate(latest?.write ?? 0))]
    }

    private func facts(for disk: PhysicalDisk) -> [PerformanceFact] {
        [PerformanceFact(label: "Capacity", value: PerformanceFormat.capacity(disk.sizeBytes)),
         PerformanceFact(label: "Available", value: PerformanceFormat.capacity(disk.availableBytes)),
         PerformanceFact(label: "System disk", value: disk.isSystem ? "Yes" : "No"),
         PerformanceFact(label: "Type", value: typeDescription(of: disk)),
         PerformanceFact(label: "Encryption", value: encryption(of: disk))]
    }

    /// "SSD (NVMe)" for the built-in drive on Apple silicon; otherwise "SSD (USB)", "HDD (USB)" and so on.
    private func typeDescription(of disk: PhysicalDisk) -> String {
        if disk.isInternal && store.hardware.isAppleSilicon { return "SSD (NVMe)" }
        let kind = disk.isSolidState.map { $0 ? "SSD" : "HDD" }
        switch (kind, disk.interconnect) {
        case let (kind?, link?): return "\(kind) (\(link))"
        case let (kind?, nil): return kind
        case let (nil, link?): return link
        default: return "–"
        }
    }

    /// FileVault state for the startup disk (from `fdesetup`); the volumes' own encryption flag for other disks.
    private func encryption(of disk: PhysicalDisk) -> String {
        if disk.isSystem { return store.fileVault.map { $0 ? "FileVault on" : "FileVault off" } ?? "–" }
        return disk.isEncrypted ? "Encrypted" : "Not encrypted"
    }
}
