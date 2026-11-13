//
//  ProcessCounts.swift
//  Taskr
//
//  How many processes and threads are running.
//

import Foundation
import Darwin

/// Counts processes and threads through libproc.
nonisolated enum ProcessCounts {
    /// Total processes, and the threads of every process macOS lets us inspect.
    static func read() -> (processes: Int, threads: Int) {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return (0, 0) }
        var pids = [Int32](repeating: 0, count: Int(estimate) + 64)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size)))
        guard count > 0 else { return (0, 0) }

        var threads = 0
        for pid in pids.prefix(count) where pid > 0 {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            if proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size {
                threads += Int(info.pti_threadnum)
            }
        }
        return (count, threads)
    }
}
