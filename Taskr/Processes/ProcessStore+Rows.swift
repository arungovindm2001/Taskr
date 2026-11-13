//
//  ProcessStore+Rows.swift
//  Taskr
//
//  Turns the store's groups into the flat, sorted, filtered rows the list renders.
//

import Foundation
import TaskrCore

extension ProcessStore {

    /// Machine-wide totals for the column headers.
    var headerTotals: HeaderTotals {
        let count = groups.reduce(0) { $0 + $1.processes.count }
        // Totals come from whole-machine counters, as Activity Monitor reports them. Summing the rows would
        // be wrong for memory: footprints overlap (shared and compressed pages) and can exceed 100%.
        guard let system else { return HeaderTotals(processCount: count) }
        return HeaderTotals(cpu: system.cpu, memoryPercent: system.memPct, disk: system.disk,
                            network: system.net, processCount: count)
    }

    /// The visible rows: sections, then groups sorted by the active column, with expanded groups
    /// followed by their children. A non-empty `query` filters by name and expands everything.
    func rows(matching query: String) -> [ProcessRow] {
        let searching = !query.isEmpty
        let source = filtered(by: query)
        var rows: [ProcessRow] = []

        for category in ProcessCategory.allCases {
            let groups = source.filter { $0.category == category }
            guard !groups.isEmpty else { continue }

            let categoryOpen = searching || expanded.contains(category.id)
            rows.append(ProcessRow(id: category.id, kind: .category, title: "\(category.title) (\(groups.count))",
                                   iconPath: nil, expandable: true, expanded: categoryOpen))
            guard categoryOpen else { continue }

            for group in sorted(groups) {
                rows.append(groupRow(group, searching: searching))
                let hasChildren = group.processes.count > 1
                if hasChildren && (searching || expanded.contains(group.id)) {
                    rows += sorted(group.processes).map { childRow($0, iconPath: group.iconPath) }
                }
            }
        }
        return rows
    }

    // MARK: Row construction

    private func groupRow(_ group: ProcessGroup, searching: Bool) -> ProcessRow {
        let pids = group.processes.map(\.pid)
        let hasChildren = group.processes.count > 1
        var row = ProcessRow(
            id: group.id, kind: .group,
            title: hasChildren ? "\(group.name) (\(group.processes.count))" : group.name,
            iconPath: group.iconPath,
            expandable: hasChildren,
            expanded: hasChildren && (searching || expanded.contains(group.id)),
            metrics: .init(cpu: group.cpu, memory: group.memory, disk: group.disk,
                           network: network(pids), gpu: gpu(pids), watts: power(pids)))
        row.efficient = !pids.isEmpty && pids.allSatisfy { efficiency.contains($0) }
        row.unresponsive = pids.contains { unresponsive.contains($0) }
        return row
    }

    private func childRow(_ process: ProcessSnapshot, iconPath: String?) -> ProcessRow {
        var row = ProcessRow(
            id: "pid:\(process.pid)", kind: .child, title: process.name, iconPath: iconPath,
            expandable: false, expanded: false,
            metrics: .init(cpu: process.cpuPercent, memory: process.memoryBytes, disk: process.diskBytesPerSec,
                           network: networkBps[process.pid] ?? 0, gpu: gpuPct[process.pid] ?? 0,
                           watts: watts[process.pid] ?? 0))
        row.efficient = efficiency.contains(process.pid)
        row.unresponsive = unresponsive.contains(process.pid)
        return row
    }

    // MARK: Filtering and sorting

    /// Groups matching `query` by group name or any process name; matching groups keep only matching processes
    /// unless the group name itself matched.
    private func filtered(by query: String) -> [ProcessGroup] {
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            if group.name.localizedCaseInsensitiveContains(query) { return group }
            let hits = group.processes.filter { $0.name.localizedCaseInsensitiveContains(query) }
            guard !hits.isEmpty else { return nil }
            var copy = group
            copy.processes = hits
            return copy
        }
    }

    private func sorted(_ groups: [ProcessGroup]) -> [ProcessGroup] {
        groups.sorted { a, b in
            let pa = a.processes.map(\.pid), pb = b.processes.map(\.pid)
            switch sortKey {
            case .name: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .cpu: return a.cpu > b.cpu
            case .memory: return a.memory > b.memory
            case .disk: return a.disk > b.disk
            case .network: return network(pa) > network(pb)
            case .gpu: return gpu(pa) > gpu(pb)
            case .energy: return power(pa) > power(pb)
            }
        }
    }

    private func sorted(_ processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        processes.sorted { a, b in
            switch sortKey {
            case .name: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .cpu: return a.cpuPercent > b.cpuPercent
            case .memory: return a.memoryBytes > b.memoryBytes
            case .disk: return a.diskBytesPerSec > b.diskBytesPerSec
            case .network: return (networkBps[a.pid] ?? 0) > (networkBps[b.pid] ?? 0)
            case .gpu: return (gpuPct[a.pid] ?? 0) > (gpuPct[b.pid] ?? 0)
            case .energy: return (watts[a.pid] ?? 0) > (watts[b.pid] ?? 0)
            }
        }
    }
}
