//
//  PerformanceStore+Summary.swift
//  Taskr
//
//  What each device card in the list shows: a name, a one-line summary and a mini graph.
//

import Foundation
import TaskrCore

/// The content of one device card.
struct DeviceSummary {
    let name: String
    let subtitle: String
    let values: [Double]
    let maxValue: Double
}

extension PerformanceStore {

    func summary(for device: PerformanceDevice) -> DeviceSummary {
        switch device {
        case .cpu: cpuSummary
        case .memory: memorySummary
        case .disk: diskSummary
        case .network: networkSummary
        case .gpu: gpuSummary
        }
    }

    // MARK: Per device

    private var cpuSummary: DeviceSummary {
        var subtitle = PerformanceFormat.percent(cpu.last ?? 0)
        if let hz = hardware.nominalFrequencyHz { subtitle += String(format: "  %.1f GHz", Double(hz) / 1e9) }
        return DeviceSummary(name: "CPU", subtitle: subtitle, values: cpu.values, maxValue: 100)
    }

    private var memorySummary: DeviceSummary {
        let used = latest?.memory.used ?? 0
        let subtitle = String(format: "%.1f/%.1f GB (%@)", Double(used) / 1_073_741_824,
                              Double(hardware.memoryBytes) / 1_073_741_824, PerformanceFormat.percent(memory.last ?? 0))
        return DeviceSummary(name: "Memory", subtitle: subtitle, values: memory.values, maxValue: 100)
    }

    private var diskSummary: DeviceSummary {
        DeviceSummary(name: diskTitle, subtitle: PerformanceFormat.percent(diskActive.last ?? 0),
                      values: diskActive.values, maxValue: 100)
    }

    private var networkSummary: DeviceSummary {
        let combined = zip(netIn.values, netOut.values).map { $0 + $1 }
        let subtitle = "S \(PerformanceFormat.rate(netOut.last ?? 0))  R \(PerformanceFormat.rate(netIn.last ?? 0))"
        return DeviceSummary(name: networkTitle, subtitle: subtitle, values: combined,
                             maxValue: PerformanceFormat.niceMax(combined.max() ?? 0, floor: 100_000))
    }

    private var gpuSummary: DeviceSummary {
        DeviceSummary(name: "GPU", subtitle: PerformanceFormat.percent(gpu.last ?? 0), values: gpu.values, maxValue: 100)
    }

    // MARK: Titles

    /// "Disk 0 (APFS)".
    var diskTitle: String { "Disk 0 (\(storage.format ?? "Disk"))" }

    /// "Wi-Fi (en0)", "Ethernet (en0)", or just "Network" with no adapter.
    var networkTitle: String {
        guard let network else { return "Network" }
        return "\(network.connectionType) (\(network.interface))"
    }
}
