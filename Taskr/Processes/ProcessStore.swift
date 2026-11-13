//
//  ProcessStore.swift
//  Taskr
//
//  The observable state behind the Processes page: live samples, grouping, selection and per-process modes.
//

import SwiftUI
import AppKit
import TaskrCore

/// Which column the list is sorted by (always descending, except Name).
enum SortKey { case name, cpu, memory, disk, network, gpu, energy }

/// Owns all the live data for the Processes page.
///
/// `run()` is the heartbeat: once a second it takes a fresh sample from every data source, regroups
/// the processes and publishes the results. Views read the published properties; SwiftUI's
/// observation re-renders only what changed.
@Observable
final class ProcessStore {

    // MARK: Published state

    /// Processes grouped by app / executable, refreshed every second.
    var groups: [ProcessGroup] = []
    /// Ids of the section and group rows that are currently expanded.
    var expanded: Set<String> = [ProcessCategory.apps.id, ProcessCategory.background.id]
    var selection: String?
    var sortKey: SortKey = .cpu
    /// When `true` the Memory column shows a share of installed RAM instead of a size.
    var memoryAsPercent = false

    /// Pids currently in Efficiency mode (background QoS).
    var efficiency: Set<Int32> = []
    /// GUI apps that aren't answering events ("Not responding").
    var unresponsive: Set<Int32> = []

    /// Bytes per second by pid, from `nettop`.
    var networkBps: [Int32: Double] = [:]
    var networkReady = false
    /// Percent of GPU time by pid, plus the whole-GPU figure when the driver reports one.
    var gpuPct: [Int32: Double] = [:]
    var gpuDevice: Double?
    var gpuReady = false
    /// Power draw in watts by pid.
    var watts: [Int32: Double] = [:]
    var energyReady = false
    /// Machine-wide totals for the column headers; `nil` until the second sample.
    var system: SystemStats.Snapshot?

    /// Installed RAM in bytes, used to turn memory into a percentage.
    let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)

    // MARK: Data sources

    private let sampler = ProcessSampler()
    private let netSampler = NetworkSampler()
    private let gpuSampler = GPUSampler()
    private let energySampler = EnergySampler()
    private let systemStats = SystemStats()

    // MARK: Sampling loop

    /// Runs while the page is on screen; SwiftUI cancels it when the page disappears.
    func run() async {
        netSampler.start()
        _ = await sampler.sample()   // prime the per-process deltas
        while !Task.isCancelled {
            guard await AppPrefs.shared.tick() else { continue }
            let snapshots = await sampler.sample()
            refresh(with: snapshots)
        }
        netSampler.stop()
    }

    /// Pulls the latest reading from every secondary source and regroups the processes.
    private func refresh(with snapshots: [ProcessSnapshot]) {
        networkBps = netSampler.rates()
        networkReady = netSampler.hasData
        unresponsive = Responsiveness.unresponsivePids()
        if let s = systemStats.sample() { system = s }
        if let g = gpuSampler.sample() { gpuPct = g.perPid; gpuDevice = g.device; gpuReady = true }
        if let w = energySampler.sample(pids: snapshots.map(\.pid)) { watts = w; energyReady = true }

        groups = ProcessGrouping.build(snapshots, regularApps: Self.runningDockApps())
        efficiency.formIntersection(Set(snapshots.map(\.pid)))
    }

    /// Bundle path → display name for apps that appear in the Dock.
    private static func runningDockApps() -> [String: String] {
        var apps: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let url = app.bundleURL else { continue }
            apps[url.path] = app.localizedName ?? url.deletingPathExtension().lastPathComponent
        }
        return apps
    }

    // MARK: Aggregation

    /// Total network bytes per second across `pids`.
    func network(_ pids: [Int32]) -> Double { pids.reduce(0) { $0 + (networkBps[$1] ?? 0) } }
    /// Total GPU share across `pids`, capped at 100%.
    func gpu(_ pids: [Int32]) -> Double { min(100, pids.reduce(0) { $0 + (gpuPct[$1] ?? 0) }) }
    /// Total power draw across `pids`, in watts.
    func power(_ pids: [Int32]) -> Double { pids.reduce(0) { $0 + (watts[$1] ?? 0) } }

    // MARK: Expansion

    func expandAll() { expanded = Set(ProcessCategory.allCases.map(\.id) + groups.map(\.id)) }
    func collapseAll() { expanded = [] }

    func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    // MARK: Targets

    /// Resolves a row id (a group id or `pid:<n>`) to something an action can operate on.
    func target(for id: String?) -> ProcessTarget? {
        guard let id else { return nil }

        if let group = groups.first(where: { $0.id == id }) {
            var main = group.processes.max(by: { $0.memoryBytes < $1.memoryBytes })?.pid
            if group.category == .apps,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == group.id }) {
                main = app.processIdentifier
            }
            return ProcessTarget(title: group.name, pids: group.processes.map(\.pid),
                                 appBundlePath: group.category == .apps ? group.id : nil,
                                 revealPath: group.iconPath, primaryPid: main)
        }

        if id.hasPrefix("pid:"), let pid = Int32(id.dropFirst(4)) {
            for group in groups {
                if let process = group.processes.first(where: { $0.pid == pid }) {
                    return ProcessTarget(title: process.name, pids: [pid], appBundlePath: nil,
                                         revealPath: ProcessPaths.path(for: pid), primaryPid: pid)
                }
            }
        }
        return nil
    }

    // MARK: Efficiency mode

    /// `true` when every process in the target is already in Efficiency mode.
    func isEfficient(_ target: ProcessTarget) -> Bool {
        !target.pids.isEmpty && target.pids.allSatisfy { efficiency.contains($0) }
    }

    /// Turns Efficiency mode off immediately, or asks for confirmation before turning it on.
    func toggleEfficiency(_ target: ProcessTarget) {
        if isEfficient(target) {
            apply(target, on: false)
        } else {
            ProcessActions.confirmEfficiency(target) { [self] in apply(target, on: true) }
        }
    }

    private func apply(_ target: ProcessTarget, on: Bool) {
        let failed = Set(ProcessActions.setEfficiency(target.pids, on: on))
        for pid in target.pids where !failed.contains(pid) {
            if on { efficiency.insert(pid) } else { efficiency.remove(pid) }
        }
        if !failed.isEmpty {
            ProcessActions.showError("Couldn’t change Efficiency mode for “\(target.title)”",
                                     "macOS only lets Taskr change processes that you own.")
        }
    }
}
