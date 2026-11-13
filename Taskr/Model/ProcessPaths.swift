//
//  ProcessPaths.swift
//  Taskr
//
//  Executable-path lookup for running processes, cached per pid.
//

import Foundation
import Darwin

/// Executable paths by pid, read with `proc_pidpath` and cached until the pid disappears.
///
/// Path lookups are cheap but happen for ~500 processes every second, so caching matters.
/// Only touched from the main actor (the sampling loop and the row actions).
enum ProcessPaths {
    private static var cache: [Int32: String] = [:]

    /// The executable path for `pid`, or an empty string when macOS won't tell us (e.g. protected processes).
    static func path(for pid: Int32) -> String {
        if let hit = cache[pid] { return hit }
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        let path = length > 0 ? String(cString: buffer) : ""
        cache[pid] = path
        return path
    }

    /// Drops cache entries for processes that have exited, so a reused pid isn't given a stale path.
    static func prune(alive: Set<Int32>) {
        cache = cache.filter { alive.contains($0.key) }
    }
}
