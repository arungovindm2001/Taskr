//
//  SystemStats.swift
//  Taskr
//
//  Machine-wide CPU, memory, disk and network figures, from the kernel counters Activity Monitor reads.
//

import Foundation
import IOKit
import Darwin

/// Samples machine-wide counters. Feeds the Processes column headers and the Performance page.
///
/// Rates are differences between two readings, so the first call to `sample()` only records baselines.
nonisolated final class SystemStats {

    /// How stressed the memory system is, as the kernel reports it.
    nonisolated enum MemoryPressure: Sendable {
        case normal, warning, critical
    }

    /// Where the Mac's RAM is going, in bytes.
    nonisolated struct Memory: Sendable {
        /// Application memory + wired + compressed: Activity Monitor's "Memory Used".
        var used: UInt64 = 0
        var app: UInt64 = 0
        var wired: UInt64 = 0
        var compressed: UInt64 = 0
        /// File-backed and purgeable pages that can be reclaimed ("Cached Files").
        var cached: UInt64 = 0
        var swapUsed: UInt64 = 0
        var pressure: MemoryPressure = .normal
    }

    /// One reading of the whole machine.
    nonisolated struct Snapshot: Sendable {
        /// % of all cores that were busy, split into user and system time.
        var cpu: Double
        var cpuUser: Double
        var cpuSystem: Double
        /// `memory.used` as a share of installed RAM, in percent.
        var memPct: Double
        var memory: Memory
        /// Bytes per second across all physical storage.
        var disk: Double
        /// Activity on each physical disk, by BSD name ("disk0").
        var disks: [String: DiskSample]
        /// Bytes per second over Ethernet / Wi-Fi (`en*`) interfaces.
        var net: Double
        var netIn: Double
        var netOut: Double
    }

    // MARK: Counters

    private struct CPUTicks { var user: UInt64, system: UInt64, idle: UInt64, nice: UInt64 }
    private struct NetCounters { var received: UInt64 = 0, sent: UInt64 = 0 }

    private var prevCPU: CPUTicks?
    private var prevDisk: [String: DiskCounters]?
    private var prevNet: NetCounters?
    private var prevTime: UInt64 = 0
    private let physical = Double(ProcessInfo.processInfo.physicalMemory)

    /// The first call only records baselines and returns nil.
    func sample() -> Snapshot? {
        let now = DispatchTime.now().uptimeNanoseconds
        let cpu = cpuTicks()
        let disk = PhysicalDisks.counters()
        let net = netCounters()
        defer { prevCPU = cpu; prevDisk = disk; prevNet = net; prevTime = now }

        guard let pc = prevCPU, let pd = prevDisk, let pn = prevNet, prevTime > 0 else { return nil }
        let nanos = Double(now &- prevTime)
        let secs = nanos / 1e9
        guard secs > 0 else { return nil }

        // CPU
        let dTotal = Double((cpu.user &- pc.user) &+ (cpu.system &- pc.system) &+ (cpu.idle &- pc.idle) &+ (cpu.nice &- pc.nice))
        let userPct = dTotal > 0 ? Double((cpu.user &- pc.user) &+ (cpu.nice &- pc.nice)) / dTotal * 100 : 0
        let systemPct = dTotal > 0 ? Double(cpu.system &- pc.system) / dTotal * 100 : 0

        // Memory
        let memory = memoryBreakdown()

        // Disk, per physical disk
        var disks: [String: DiskSample] = [:]
        for (id, counters) in disk {
            guard let before = pd[id] else { continue }
            let ops = delta(counters.opsRead, before.opsRead) + delta(counters.opsWritten, before.opsWritten)
            let busy = Double(delta(counters.busyNanoseconds, before.busyNanoseconds))
            disks[id] = DiskSample(read: Double(delta(counters.bytesRead, before.bytesRead)) / secs,
                                   write: Double(delta(counters.bytesWritten, before.bytesWritten)) / secs,
                                   active: min(busy / nanos * 100, 100),
                                   latencyMs: ops > 0 ? busy / Double(ops) / 1e6 : nil)
        }
        let diskTotal = disks.values.reduce(0) { $0 + $1.read + $1.write }

        // Network
        let rx = Double(delta(net.received, pn.received)) / secs
        let tx = Double(delta(net.sent, pn.sent)) / secs

        return Snapshot(cpu: userPct + systemPct, cpuUser: userPct, cpuSystem: systemPct,
                        memPct: physical > 0 ? min(Double(memory.used) / physical, 1) * 100 : 0, memory: memory,
                        disk: diskTotal, disks: disks,
                        net: rx + tx, netIn: rx, netOut: tx)
    }

    /// A counter's growth, treating a decrease (reset or wrap) as zero.
    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    // MARK: CPU

    private func cpuTicks() -> CPUTicks {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return CPUTicks(user: 0, system: 0, idle: 0, nice: 0) }
        let t = info.cpu_ticks   // (user, system, idle, nice)
        return CPUTicks(user: UInt64(t.0), system: UInt64(t.1), idle: UInt64(t.2), nice: UInt64(t.3))
    }

    // MARK: Memory

    /// Activity Monitor's breakdown: App Memory + Wired + Compressed is "Memory Used".
    private func memoryBreakdown() -> Memory {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return Memory() }

        let page = UInt64(getpagesize())
        let appPages = UInt64(max(Int64(stats.internal_page_count) - Int64(stats.purgeable_count), 0))
        var memory = Memory()
        memory.app = appPages * page
        memory.wired = UInt64(stats.wire_count) * page
        memory.compressed = UInt64(stats.compressor_page_count) * page
        memory.used = memory.app + memory.wired + memory.compressed
        memory.cached = (UInt64(stats.external_page_count) + UInt64(stats.purgeable_count)) * page
        memory.swapUsed = Sysctl.swapUsage()?.used ?? 0
        switch Sysctl.int("kern.memorystatus_vm_pressure_level") {
        case 2: memory.pressure = .warning
        case 4: memory.pressure = .critical
        default: memory.pressure = .normal
        }
        return memory
    }

    // MARK: Network

    /// Cumulative bytes in and out over `en*` interfaces, from `sysctl(NET_RT_IFLIST2)`.
    private func netCounters() -> NetCounters {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return NetCounters() }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return NetCounters() }

        var total = NetCounters()
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let size = Int(header.ifm_msglen)
                if size == 0 { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(info.ifm_index), &name) != nil, String(cString: name).hasPrefix("en") {
                        total.received += info.ifm_data.ifi_ibytes
                        total.sent += info.ifm_data.ifi_obytes
                    }
                }
                offset += size
            }
        }
        return total
    }
}
