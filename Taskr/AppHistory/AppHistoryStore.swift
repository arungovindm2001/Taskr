//
//  AppHistoryStore.swift
//  Taskr
//
//  Accumulates per-app resource use over time and keeps it across launches.
//

import SwiftUI
import AppKit
import TaskrCore

/// Which apps the history lists.
enum AppHistoryScope: String, CaseIterable, Identifiable {
    case apps = "Apps"
    case all = "All processes"
    var id: String { rawValue }
}

/// Columns the history can be sorted by (always descending, except Name).
enum AppHistorySort { case name, cpuTime, network, diskWritten, energy }

/// Owns the usage history shown on the App history page.
///
/// Once a second it reads the live `ProcessStore` and adds that second's CPU time, network traffic,
/// disk writes and energy to each app's running totals. Totals are saved to Application Support every
/// 30 seconds and when the app quits. Usage is only recorded while Taskr is running.
@Observable
final class AppHistoryStore {

    // MARK: State

    private(set) var apps: [String: AppUsage] = [:]
    /// When recording began (or was last cleared).
    private(set) var since = Date()
    var scope: AppHistoryScope = .apps
    var sortKey: AppHistorySort = .cpuTime

    // MARK: Private

    private let logicalCores = Double(HardwareInfo.current.logicalCores)
    private let fileURL: URL
    private var lastTick: UInt64 = 0
    private var dirty = false

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = support.appendingPathComponent("Taskr", isDirectory: true).appendingPathComponent("app-history.json")
        load()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil,
                                               queue: .main) { [weak self] _ in self?.save(wait: true) }
    }

    // MARK: Recording loop

    /// Records once a second from `source` until cancelled.
    func run(from source: ProcessStore) async {
        lastTick = DispatchTime.now().uptimeNanoseconds
        var ticks = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let now = DispatchTime.now().uptimeNanoseconds
            record(source, seconds: Double(now - lastTick) / 1e9)
            lastTick = now
            ticks += 1
            if ticks % 30 == 0 { save() }
        }
    }

    /// Adds `seconds` of the store's current rates to every group.
    private func record(_ source: ProcessStore, seconds: Double) {
        guard seconds > 0, seconds < 5 else { return }   // skip gaps from sleep or a stalled loop
        for group in source.groups {
            var usage = apps[group.id] ?? AppUsage(id: group.id, name: group.name,
                                                   category: group.category.rawValue, iconPath: group.iconPath)
            let pids = group.processes.map(\.pid)
            usage.name = group.name
            usage.category = group.category.rawValue
            usage.iconPath = group.iconPath
            usage.cpuSeconds += group.cpu / 100 * logicalCores * seconds
            usage.networkBytes += source.network(pids) * seconds
            usage.diskWrittenBytes += group.processes.reduce(0) { $0 + $1.diskWriteBytesPerSec } * seconds
            usage.joules += source.power(pids) * seconds
            usage.runningSeconds += seconds
            apps[group.id] = usage
        }
        dirty = true
    }

    // MARK: Display

    /// Rows for the table: filtered by scope and search text, sorted by `sortKey`.
    func rows(matching query: String) -> [AppUsage] {
        let text = query.trimmingCharacters(in: .whitespaces)
        let visible = apps.values.filter { usage in
            (scope == .all || usage.category == ProcessCategory.apps.rawValue)
                && (text.isEmpty || usage.name.localizedCaseInsensitiveContains(text))
        }
        switch sortKey {
        case .name: return visible.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .cpuTime: return visible.sorted { $0.cpuSeconds > $1.cpuSeconds }
        case .network: return visible.sorted { $0.networkBytes > $1.networkBytes }
        case .diskWritten: return visible.sorted { $0.diskWrittenBytes > $1.diskWrittenBytes }
        case .energy: return visible.sorted { $0.averageWatts > $1.averageWatts }
        }
    }

    /// Forgets everything and starts again from now.
    func deleteHistory() {
        apps = [:]
        since = Date()
        dirty = true
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(AppHistoryFile.self, from: data) else { return }
        apps = file.apps
        since = file.since
    }

    /// Writes the history to disk. `wait` makes it synchronous, for the moment the app is quitting.
    private func save(wait: Bool = false) {
        guard dirty else { return }
        dirty = false
        let file = AppHistoryFile(since: since, apps: apps)
        let url = fileURL
        let write = {
            guard let data = try? JSONEncoder().encode(file) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        if wait { write() } else { Task.detached(priority: .utility) { write() } }
    }
}
