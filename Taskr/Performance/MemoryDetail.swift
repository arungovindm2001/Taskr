//
//  MemoryDetail.swift
//  Taskr
//
//  The Memory page: usage graph plus the in-use / wired / compressed / cached breakdown.
//

import SwiftUI
import TaskrCore

/// Memory detail panel.
struct MemoryDetail: View {
    let store: PerformanceStore

    var body: some View {
        let hardware = store.hardware
        PerformanceDetail(title: "Memory",
                          subtitle: "\(PerformanceFormat.gigabytes(hardware.memoryBytes)) \(hardware.isAppleSilicon ? "unified memory" : "memory")",
                          stats: stats, facts: facts) {
            GraphSection(title: "Memory usage", maxLabel: PerformanceFormat.gigabytes(hardware.memoryBytes),
                         maxValue: 100,
                         series: [GraphSeries(values: store.memory.values, line: GraphPalette.memoryLine,
                                              fill: GraphPalette.memoryFill, fillOpacity: 0.22)],
                         height: 230, border: GraphPalette.memoryFill)
        }
    }

    private var stats: [PerformanceStat] {
        let memory = store.latest?.memory ?? SystemStats.Memory()
        let total = store.hardware.memoryBytes
        return [PerformanceStat(label: "In use", value: PerformanceFormat.gigabytes(memory.used)),
                PerformanceStat(label: "Available", value: PerformanceFormat.gigabytes(total > memory.used ? total - memory.used : 0)),
                PerformanceStat(label: "Swap used", value: PerformanceFormat.gigabytes(memory.swapUsed)),
                PerformanceStat(label: "Cached", value: PerformanceFormat.gigabytes(memory.cached)),
                PerformanceStat(label: "Wired", value: PerformanceFormat.gigabytes(memory.wired)),
                PerformanceStat(label: "Compressed", value: PerformanceFormat.gigabytes(memory.compressed))]
    }

    private var facts: [PerformanceFact] {
        let memory = store.latest?.memory ?? SystemStats.Memory()
        return [PerformanceFact(label: "Memory pressure", value: pressureName(memory.pressure)),
                PerformanceFact(label: "Memory type", value: store.hardware.isAppleSilicon ? "Unified" : "DRAM"),
                PerformanceFact(label: "Page size", value: "\(store.hardware.pageSize / 1024) KB"),
                PerformanceFact(label: "Compression", value: memory.compressed > 0 ? "Active" : "Idle")]
    }

    private func pressureName(_ pressure: SystemStats.MemoryPressure) -> String {
        switch pressure {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}
