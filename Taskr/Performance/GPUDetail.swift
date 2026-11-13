//
//  GPUDetail.swift
//  Taskr
//
//  The GPU page: utilization, renderer, tiler and memory graphs (those the driver reports).
//

import SwiftUI
import AppKit

/// GPU detail panel.
struct GPUDetail: View {
    let store: PerformanceStore

    var body: some View {
        let info = store.gpuInfo
        PerformanceDetail(title: "GPU",
                          subtitle: info.coreCount.map { "\(info.name), \($0) cores" } ?? info.name,
                          stats: stats, facts: facts) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                graph("Utilization", store.gpu)
                if store.gpuStats?.renderer != nil { graph("Renderer", store.gpuRenderer) }
                if store.gpuStats?.tiler != nil { graph("Tiler", store.gpuTiler) }
                if store.gpuStats?.memoryInUse != nil { graph("GPU memory", store.gpuMemory) }
            }
        }
    }

    private func graph(_ title: String, _ history: MetricHistory) -> some View {
        GraphSection(title: title, maxLabel: "100%", maxValue: 100,
                     series: [GraphSeries(values: history.values, line: GraphPalette.gpuLine,
                                          fill: GraphPalette.gpuFill, fillOpacity: 0.22)],
                     height: 120, border: GraphPalette.gpuFill)
    }

    private var stats: [PerformanceStat] {
        var stats = [PerformanceStat(label: "Utilization", value: PerformanceFormat.percent(store.gpuStats?.utilization ?? 0))]
        if let used = store.gpuStats?.memoryInUse {
            stats.append(PerformanceStat(label: "GPU memory", value: PerformanceFormat.gigabytes(used)))
        }
        return stats
    }

    private var facts: [PerformanceFact] {
        let info = store.gpuInfo
        var facts = [PerformanceFact(label: "Metal support", value: info.metalSupport)]
        if let cores = info.coreCount { facts.append(PerformanceFact(label: "Cores", value: "\(cores)")) }
        facts.append(PerformanceFact(label: "Memory type", value: info.unifiedMemory ? "Unified" : "Dedicated"))
        if let display = NSScreen.main?.localizedName { facts.append(PerformanceFact(label: "Display", value: display)) }
        return facts
    }
}
