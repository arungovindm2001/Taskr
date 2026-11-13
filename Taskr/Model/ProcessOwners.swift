//
//  ProcessOwners.swift
//  Taskr
//
//  Which user account owns each process, cached per pid.
//

import Foundation
import Darwin

/// Owner user ids by pid, read with `proc_pidinfo` and cached until the pid disappears.
/// Only touched from the main actor.
enum ProcessOwners {
    private static var cache: [Int32: uid_t] = [:]

    /// The uid that owns `pid`, or 0 if macOS won't say.
    static func uid(for pid: Int32) -> uid_t {
        if let hit = cache[pid] { return hit }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let uid = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info.pbi_uid : 0
        cache[pid] = uid
        return uid
    }

    /// Drops entries for processes that have exited.
    static func prune(alive: Set<Int32>) {
        cache = cache.filter { alive.contains($0.key) }
    }
}
