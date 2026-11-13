//
//  PerformanceStore.swift
//  Taskr
//
//  Live machine-wide readings and their 60-second history, for the Performance page.
//

import SwiftUI

/// Owns the Performance page's data.
///
/// The store lives at the window's root and its loop runs for as long as the window does, so the 60-second
/// graphs are already filled in when you open the page. One reading per second.
@Observable
final class PerformanceStore {

    // MARK: History (oldest first, 60 readings)

    var cpu = MetricHistory()            // total %
    var cpuSystem = MetricHistory()      // system share, %
    var memory = MetricHistory()         // % of RAM in use
    /// Per-disk history, by BSD name ("disk0").
    var diskHistory: [String: DiskHistory] = [:]
    var netIn = MetricHistory()          // bytes per second
    var netOut = MetricHistory()
    var gpu = MetricHistory()            // %
    var gpuRenderer = MetricHistory()
    var gpuTiler = MetricHistory()
    var gpuMemory = MetricHistory()      // % of RAM (unified memory)

    // MARK: Latest readings

    var latest: SystemStats.Snapshot?
    var gpuStats: GPUDeviceStats?
    var processCount = 0
    var threadCount = 0
    var uptime: TimeInterval = 0

    // MARK: Slow-changing facts

    var network: NetworkInfo?
    /// Physical disks and their volumes; refreshed every few seconds so plugging a drive in shows up.
    var disks = PhysicalDisks.list()
    /// `nil` until `fdesetup` answers (or if it can't be read).
    var fileVault: Bool?

    let hardware = HardwareInfo.current
    let gpuInfo = GPUInfo.current

    /// Everything the device list shows, in order. Each physical disk gets its own entry.
    var devices: [PerformanceDevice] {
        [.cpu, .memory] + disks.map { .disk($0.id) } + [.network, .gpu]
    }

    private let stats = SystemStats()

    // MARK: Loop

    /// Samples once a second. Runs until cancelled.
    func run() async {
        network = NetworkInfo.read()
        Task { fileVault = await Task.detached { FileVault.isEnabled() }.value }

        var tick = 0
        while !Task.isCancelled {
            sample()
            if tick % 5 == 4 {   // addresses, signal and free space change slowly
                network = NetworkInfo.read()
                disks = await Task.detached { PhysicalDisks.list() }.value
                let present = Set(disks.map(\.id))
                diskHistory = diskHistory.filter { present.contains($0.key) }   // forget unplugged disks
            }
            tick += 1
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func sample() {
        if let s = stats.sample() {
            latest = s
            cpu.append(s.cpu)
            cpuSystem.append(s.cpuSystem)
            memory.append(s.memPct)
            for (id, sample) in s.disks { diskHistory[id, default: DiskHistory()].append(sample) }
            netIn.append(s.netIn)
            netOut.append(s.netOut)
        }

        if let g = GPUDeviceStats.read() {
            gpuStats = g
            gpu.append(g.utilization ?? 0)
            if let renderer = g.renderer { gpuRenderer.append(renderer) }
            if let tiler = g.tiler { gpuTiler.append(tiler) }
            if let used = g.memoryInUse {
                gpuMemory.append(Double(used) / Double(hardware.memoryBytes) * 100)
            }
        }

        let counts = ProcessCounts.read()
        processCount = counts.processes
        threadCount = counts.threads
        uptime = Sysctl.uptime() ?? uptime
    }
}
