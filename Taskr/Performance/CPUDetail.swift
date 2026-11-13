//
//  CPUDetail.swift
//  Taskr
//
//  The CPU page: utilization graph (user + system), counts, uptime and core layout.
//

import SwiftUI

/// CPU detail panel.
struct CPUDetail: View {
    let store: PerformanceStore

    var body: some View {
        let hardware = store.hardware
        PerformanceDetail(title: "CPU",
                          subtitle: "\(hardware.processorName), \(hardware.physicalCores)-core processor",
                          stats: stats, facts: facts) {
            GraphSection(title: "% Utilization over 60 seconds",
                         legend: [LegendItem(color: GraphPalette.systemFill, label: "System"),
                                  LegendItem(color: GraphPalette.cpuFill, label: "User")],
                         maxLabel: "100%", maxValue: 100,
                         series: [GraphSeries(values: store.cpu.values, line: GraphPalette.cpuLine,
                                              fill: GraphPalette.cpuFill, fillOpacity: 0.45),
                                  GraphSeries(values: store.cpuSystem.values, line: GraphPalette.systemLine,
                                              fill: GraphPalette.systemFill, fillOpacity: 0.55)],
                         height: 320, border: GraphPalette.cpuLine)
        }
    }

    private var stats: [PerformanceStat] {
        [PerformanceStat(label: "Utilization", value: PerformanceFormat.percent(store.latest?.cpu ?? 0)),
         speedOrLoad,
         PerformanceStat(label: "Up time", value: PerformanceFormat.uptime(store.uptime)),
         PerformanceStat(label: "Processes", value: store.processCount.formatted()),
         PerformanceStat(label: "Threads", value: store.threadCount.formatted()),
         PerformanceStat(label: "Thermal state", value: PerformanceFormat.thermalState(ProcessInfo.processInfo.thermalState))]
    }

    /// Intel Macs report a clock speed. Apple silicon doesn't expose one without root, so show the load average.
    private var speedOrLoad: PerformanceStat {
        if let hz = store.hardware.nominalFrequencyHz {
            return PerformanceStat(label: "Speed", value: String(format: "%.1f GHz", Double(hz) / 1e9))
        }
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        return PerformanceStat(label: "Load average", value: String(format: "%.2f", load[0]))
    }

    private var facts: [PerformanceFact] {
        let hardware = store.hardware
        return [PerformanceFact(label: "Cores", value: hardware.coreSummary),
                PerformanceFact(label: "Logical processors", value: "\(hardware.logicalCores)"),
                PerformanceFact(label: "Architecture", value: hardware.architecture),
                PerformanceFact(label: "Virtualization", value: hardware.virtualizationSupported ? "Enabled" : "Not supported")]
    }
}
