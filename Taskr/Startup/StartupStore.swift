//
//  StartupStore.swift
//  Taskr
//
//  Observable state behind the Startup apps page.
//

import SwiftUI

/// How much a startup item has weighed on the machine, as Windows words it.
enum StartupImpact: Int, Comparable {
    case notMeasured, none, low, medium, high

    var label: String {
        switch self {
        case .notMeasured: "Not measured"
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    static func < (a: StartupImpact, b: StartupImpact) -> Bool { a.rawValue < b.rawValue }
}

/// Columns the table can be sorted by.
enum StartupSort { case name, status, impact }

/// Owns the startup item list, the selection, and enable / disable.
@Observable
final class StartupStore {
    private(set) var items: [StartupItem] = []
    private(set) var loaded = false
    var selection: String?
    var sortKey: StartupSort = .impact

    /// Rescans in the background; cheap enough to call every few seconds while the page is open.
    func refresh() async {
        let found = await Task.detached { StartupScanner.scan() }.value
        if found != items { items = found }
        loaded = true
    }

    var selected: StartupItem? { items.first { $0.id == selection } }

    /// Turns the selected launch agent on or off for the next login.
    func toggleSelected() async {
        guard let item = selected, let label = item.label else { return }
        let enable = !item.isEnabled
        let error = await Task.detached { StartupScanner.setEnabled(enable, label: label) }.value
        if let error {
            ProcessActions.showError("Couldn’t \(enable ? "enable" : "disable") \(item.name)", error)
        }
        await refresh()
    }

    // MARK: Display

    /// Estimates impact from what App history has recorded for the item: average CPU cores busy while it ran.
    /// Taskr can't see the real login, so this is the item's ongoing weight, not its boot-time cost.
    func impact(of item: StartupItem, history: AppHistoryStore) -> StartupImpact {
        guard let id = item.processGroupID, let usage = history.apps[id], usage.runningSeconds >= 30 else { return .notMeasured }
        let cores = usage.cpuSeconds / usage.runningSeconds
        switch cores {
        case ..<0.005: return .none
        case ..<0.05: return .low
        case ..<0.25: return .medium
        default: return .high
        }
    }

    func rows(matching query: String, history: AppHistoryStore) -> [(item: StartupItem, impact: StartupImpact)] {
        let text = query.trimmingCharacters(in: .whitespaces)
        let rows = items
            .filter { text.isEmpty || $0.name.localizedCaseInsensitiveContains(text) || $0.developer.localizedCaseInsensitiveContains(text) }
            .map { (item: $0, impact: impact(of: $0, history: history)) }
        switch sortKey {
        case .name: return rows.sorted { $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending }
        case .status: return rows.sorted { $0.item.isEnabled && !$1.item.isEnabled }
        case .impact: return rows.sorted { $0.impact != $1.impact ? $0.impact > $1.impact
                                            : $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending }
        }
    }
}
