//
//  EnergySampler.swift
//  Taskr
//
//  Per-process power draw from the kernel's cumulative energy counter.
//

import Foundation
import Darwin

/// Per-process power draw in watts, from the kernel's cumulative energy counter (`ri_energy_nj`).
nonisolated final class EnergySampler {
    private var prev: [Int32: UInt64] = [:]
    private var prevTime: UInt64 = 0
    private var primed = false

    /// First call only records a baseline and returns nil.
    func sample(pids: [Int32]) -> [Int32: Double]? {
        let now = DispatchTime.now().uptimeNanoseconds
        var current: [Int32: UInt64] = [:]
        current.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            var ru = rusage_info_v6()
            let rc = withUnsafeMutablePointer(to: &ru) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
                }
            }
            if rc == 0 { current[pid] = ru.ri_energy_nj }
        }
        defer { prev = current; prevTime = now }
        guard primed else { primed = true; return nil }

        let elapsed = Double(now &- prevTime) / 1e9
        guard elapsed > 0 else { return nil }
        var watts: [Int32: Double] = [:]
        for (pid, cur) in current {
            guard let before = prev[pid], cur >= before else { continue }
            watts[pid] = Double(cur - before) / 1e9 / elapsed
        }
        return watts
    }
}
