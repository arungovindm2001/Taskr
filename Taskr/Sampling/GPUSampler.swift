//
//  GPUSampler.swift
//  Taskr
//
//  Per-process GPU utilization from the IORegistry (IOAccelerator clients).
//

import Foundation
import IOKit

/// Per-process GPU time from the IORegistry (the same source Activity Monitor uses).
///
/// Each GPU client (`IOAccelerator` child) names its owning process in `IOUserClientCreator`
/// ("pid 410, WindowServer") and carries cumulative `accumulatedGPUTime` in `AppUsage`.
nonisolated final class GPUSampler {
    struct Result {
        var perPid: [Int32: Double] = [:]   // percent of one GPU's time, 0...100
        var device: Double?                 // whole-GPU utilization %, if the driver reports it
    }

    private var prev: [Int32: UInt64] = [:]
    private var prevTime: UInt64 = 0
    private var primed = false

    /// First call only records a baseline and returns nil.
    func sample() -> Result? {
        let now = DispatchTime.now().uptimeNanoseconds
        let (totals, device) = readRegistry()
        defer { prev = totals; prevTime = now }
        guard primed else { primed = true; return nil }

        let elapsed = Double(now &- prevTime)
        guard elapsed > 0 else { return nil }
        var out = Result(perPid: [:], device: device)
        for (pid, cur) in totals {
            guard let before = prev[pid], cur >= before else { continue }
            let pct = Double(cur - before) / elapsed * 100
            if pct > 0 { out.perPid[pid] = min(pct, 100) }
        }
        return out
    }

    private func readRegistry() -> ([Int32: UInt64], Double?) {
        var totals: [Int32: UInt64] = [:]
        var device: Double?

        var accelerators: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &accelerators) == KERN_SUCCESS else {
            return (totals, device)
        }
        defer { IOObjectRelease(accelerators) }

        var service = IOIteratorNext(accelerators)
        while service != 0 {
            if let perf = property(service, "PerformanceStatistics") as? [String: Any],
               let util = perf["Device Utilization %"] as? NSNumber {
                device = max(device ?? 0, util.doubleValue)
            }

            var children: io_iterator_t = 0
            if IORegistryEntryGetChildIterator(service, kIOServicePlane, &children) == KERN_SUCCESS {
                var child = IOIteratorNext(children)
                while child != 0 {
                    if let creator = property(child, "IOUserClientCreator") as? String,
                       let pid = Self.pid(from: creator),
                       let usage = property(child, "AppUsage") as? [[String: Any]] {
                        let t = usage.reduce(UInt64(0)) { $0 + (($1["accumulatedGPUTime"] as? NSNumber)?.uint64Value ?? 0) }
                        totals[pid, default: 0] += t
                    }
                    IOObjectRelease(child)
                    child = IOIteratorNext(children)
                }
                IOObjectRelease(children)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(accelerators)
        }
        return (totals, device)
    }

    private func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// "pid 410, WindowServer" -> 410
    private static func pid(from creator: String) -> Int32? {
        guard creator.hasPrefix("pid ") else { return nil }
        let digits = creator.dropFirst(4).prefix(while: { $0.isNumber })
        return Int32(digits)
    }
}
