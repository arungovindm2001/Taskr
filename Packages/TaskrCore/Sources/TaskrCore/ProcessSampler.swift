//
//  ProcessSampler.swift
//  TaskrCore
//
//  Samples every running process through libproc.
//

import Foundation
import Darwin

/// Samples every process via libproc (`proc_listallpids` + `proc_pid_rusage`).
///
/// Call `sample()` on a timer. Rates are deltas between consecutive calls, so the first call reports zero
/// rates; call it once to prime the sampler and then once per interval.
///
/// The sampler is an actor because it keeps state between calls (previous counters and a name cache).
public actor ProcessSampler {

    /// Cumulative counters from the previous sample, used to compute rates.
    private struct Counters {
        var cpuNanoseconds: UInt64
        var bytesRead: UInt64
        var bytesWritten: UInt64
    }

    private var previous: [Int32: Counters] = [:]
    private var previousTime: UInt64 = 0
    private var nameCache: [Int32: String] = [:]
    private let timebase: mach_timebase_info_data_t
    private let cores = Double(ProcessInfo.processInfo.activeProcessorCount)

    public init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebase = info
    }

    /// Reads every process that macOS lets us inspect. Processes that exit mid-sample, or that we aren't
    /// permitted to read, are skipped.
    public func sample() -> [ProcessSnapshot] {
        let now = mach_absolute_time()
        let elapsed = previousTime == 0 ? 0 : seconds(from: now &- previousTime)
        previousTime = now

        var current: [Int32: Counters] = [:]
        var snapshots: [ProcessSnapshot] = []

        for pid in allPIDs() where pid > 0 {
            guard let usage = resourceUsage(of: pid) else { continue }

            let cpuTicks = usage.ri_user_time &+ usage.ri_system_time
            let counters = Counters(cpuNanoseconds: nanoseconds(from: cpuTicks),
                                    bytesRead: usage.ri_diskio_bytesread,
                                    bytesWritten: usage.ri_diskio_byteswritten)
            current[pid] = counters

            var cpu = 0.0, readRate = 0.0, writeRate = 0.0
            if elapsed > 0, let before = previous[pid] {
                cpu = Double(counters.cpuNanoseconds &- before.cpuNanoseconds) / 1e9 / elapsed / cores * 100
                readRate = Double(counters.bytesRead &- before.bytesRead) / elapsed
                writeRate = Double(counters.bytesWritten &- before.bytesWritten) / elapsed
            }
            snapshots.append(ProcessSnapshot(pid: pid, name: name(for: pid), cpuPercent: max(0, cpu),
                                             memoryBytes: usage.ri_phys_footprint,
                                             diskReadBytesPerSec: readRate, diskWriteBytesPerSec: writeRate))
        }

        previous = current
        nameCache = nameCache.filter { current[$0.key] != nil }
        return snapshots
    }

    // MARK: - libproc helpers

    /// `proc_pid_rusage` (version 4) for one pid, or `nil` if the process is gone or not permitted.
    private func resourceUsage(of pid: Int32) -> rusage_info_v4? {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? usage : nil
    }

    private func allPIDs() -> [Int32] {
        let estimate = proc_listallpids(nil, 0)           // returns a pid count
        guard estimate > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(estimate) + 64)   // slack for processes started meanwhile
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard count > 0 else { return [] }
        return Array(pids.prefix(Int(count)))
    }

    /// The process name, cached until the pid disappears.
    private func name(for pid: Int32) -> String {
        if let cached = nameCache[pid] { return cached }
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        let raw = String(cString: buffer)
        let resolved = raw.isEmpty ? "pid \(pid)" : raw
        nameCache[pid] = resolved
        return resolved
    }

    // MARK: - Time conversion

    /// Mach absolute-time ticks to nanoseconds (the timebase differs between Intel and Apple silicon).
    private func nanoseconds(from ticks: UInt64) -> UInt64 {
        UInt64(Double(ticks) * Double(timebase.numer) / Double(timebase.denom))
    }

    private func seconds(from ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1e9
    }
}
