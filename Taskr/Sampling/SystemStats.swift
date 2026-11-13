//
//  SystemStats.swift
//  Taskr
//
//  Machine-wide CPU, memory, disk and network figures for the column headers.
//

import Foundation
import IOKit
import Darwin

/// Machine-wide totals for the column headers, from the same kernel counters Activity Monitor reads.
nonisolated final class SystemStats {
    nonisolated struct Snapshot: Sendable {
        var cpu: Double       // % of all cores busy
        var memPct: Double    // (app + wired + compressed) / installed RAM
        var disk: Double      // bytes per second, all physical storage
        var net: Double       // bytes per second, in + out over en* interfaces
    }

    private var prevCPU: (busy: UInt64, total: UInt64)?
    private var prevDisk: UInt64?
    private var prevNet: UInt64?
    private var prevTime: UInt64 = 0
    private let physical = Double(ProcessInfo.processInfo.physicalMemory)

    /// The first call only records baselines and returns nil.
    func sample() -> Snapshot? {
        let now = DispatchTime.now().uptimeNanoseconds
        let cpu = cpuTicks()
        let disk = diskBytes()
        let net = netBytes()
        defer { prevCPU = cpu; prevDisk = disk; prevNet = net; prevTime = now }

        guard let pc = prevCPU, let pd = prevDisk, let pn = prevNet, prevTime > 0 else { return nil }
        let secs = Double(now &- prevTime) / 1e9
        guard secs > 0 else { return nil }

        let dTotal = Double(cpu.total &- pc.total)
        let cpuPct = dTotal > 0 ? Double(cpu.busy &- pc.busy) / dTotal * 100 : 0
        return Snapshot(cpu: cpuPct,
                        memPct: memoryUsedFraction() * 100,
                        disk: Double(disk >= pd ? disk - pd : 0) / secs,
                        net: Double(net >= pn ? net - pn : 0) / secs)
    }

    // MARK: CPU

    private func cpuTicks() -> (busy: UInt64, total: UInt64) {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0) }
        let t = info.cpu_ticks
        let user = UInt64(t.0), system = UInt64(t.1), idle = UInt64(t.2), nice = UInt64(t.3)
        return (user + system + nice, user + system + nice + idle)
    }

    // MARK: Memory

    /// Activity Monitor's "Memory Used": App Memory + Wired + Compressed.
    private func memoryUsedFraction() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS, physical > 0 else { return 0 }
        let page = Double(getpagesize())
        let app = Double(stats.internal_page_count) - Double(stats.purgeable_count)
        let used = (max(app, 0) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        return min(used / physical, 1)
    }

    // MARK: Disk

    private func diskBytes() -> UInt64 {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }
        var total: UInt64 = 0
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if let stats = IORegistryEntryCreateCFProperty(entry, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] {
                total += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                total += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return total
    }

    // MARK: Network

    private func netBytes() -> UInt64 {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else { return 0 }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else { return 0 }

        var total: UInt64 = 0
        buf.withUnsafeBytes { raw in
            var off = 0
            while off + MemoryLayout<if_msghdr>.size <= len {
                let head = raw.loadUnaligned(fromByteOffset: off, as: if_msghdr.self)
                let size = Int(head.ifm_msglen)
                if size == 0 { break }
                if Int32(head.ifm_type) == RTM_IFINFO2, off + MemoryLayout<if_msghdr2>.size <= len {
                    let h2 = raw.loadUnaligned(fromByteOffset: off, as: if_msghdr2.self)
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(h2.ifm_index), &name) != nil, String(cString: name).hasPrefix("en") {
                        total += h2.ifm_data.ifi_ibytes + h2.ifm_data.ifi_obytes
                    }
                }
                off += size
            }
        }
        return total
    }
}
