//
//  ProcessGrouping.swift
//  Taskr
//
//  Turns a flat list of process snapshots into the grouped, categorized structure the list displays.
//

import Foundation
import TaskrCore

/// Builds `ProcessGroup`s from raw samples.
enum ProcessGrouping {
    /// Path prefixes that identify operating-system executables.
    private static let systemPrefixes = ["/System/", "/usr/", "/sbin/", "/bin/", "/Library/Apple/", "/private/var/"]

    /// The outermost `.app` bundle containing an executable, e.g. `/Applications/Claude.app`, or `nil`.
    nonisolated static func bundlePath(_ executable: String) -> String? {
        guard let range = executable.range(of: ".app/") else { return nil }
        return String(executable[..<range.lowerBound]) + ".app"
    }

    /// Groups `snapshots` by app bundle (or executable) and assigns each group a category.
    ///
    /// - Parameter regularApps: Bundle path → display name for running Dock apps. A group whose bundle
    ///   is in this map is an app; otherwise it is classified by where its executable lives.
    static func build(_ snapshots: [ProcessSnapshot], regularApps: [String: String]) -> [ProcessGroup] {
        let alive = Set(snapshots.map(\.pid))
        ProcessPaths.prune(alive: alive)
        ProcessOwners.prune(alive: alive)
        var groups: [String: ProcessGroup] = [:]

        for snapshot in snapshots {
            let executable = ProcessPaths.path(for: snapshot.pid)
            let bundle = bundlePath(executable)
            let key = classify(snapshot, executable: executable, bundle: bundle, regularApps: regularApps)

            if groups[key.id] == nil {
                groups[key.id] = ProcessGroup(id: key.id, name: key.name, category: key.category,
                                              iconPath: key.iconPath, processes: [])
            }
            groups[key.id]?.processes.append(snapshot)
        }
        return Array(groups.values)
    }

    // MARK: - Classification

    private struct GroupKey {
        let id: String
        let name: String
        let category: ProcessCategory
        let iconPath: String?
    }

    private static func classify(_ snapshot: ProcessSnapshot, executable: String, bundle: String?,
                                 regularApps: [String: String]) -> GroupKey {
        if let bundle, let appName = regularApps[bundle] {
            return GroupKey(id: bundle, name: appName, category: .apps, iconPath: bundle)
        }
        if let bundle {
            let name = URL(fileURLWithPath: bundle).deletingPathExtension().lastPathComponent
            return GroupKey(id: bundle, name: name,
                            category: isSystem(executable) ? .macOS : .background, iconPath: bundle)
        }
        if executable.isEmpty {
            // Protected processes (kernel_task, launchd children, …): treat as macOS and group by name.
            return GroupKey(id: "name:\(snapshot.name)", name: snapshot.name, category: .macOS, iconPath: nil)
        }
        return GroupKey(id: executable, name: snapshot.name,
                        category: isSystem(executable) ? .macOS : .background, iconPath: executable)
    }

    private static func isSystem(_ executable: String) -> Bool {
        systemPrefixes.contains { executable.hasPrefix($0) }
    }
}
