//
//  Sysctl.swift
//  Taskr
//
//  Typed wrappers around `sysctlbyname` for reading kernel and hardware facts.
//

import Foundation
import Darwin

/// Reads values from the kernel's `sysctl` tree. Every call returns `nil` when the name doesn't exist
/// on this machine (for example `hw.perflevel0.*` on Intel Macs).
nonisolated enum Sysctl {
    /// An integer value (4- or 8-byte).
    static func int(_ name: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    /// A string value.
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    /// Swap usage (`vm.swapusage`): bytes in use and total.
    static func swapUsage() -> (used: UInt64, total: UInt64)? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return (usage.xsu_used, usage.xsu_total)
    }

    /// Seconds since the Mac booted (including time asleep), from `kern.boottime`.
    static func uptime() -> TimeInterval? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { return nil }
        return Date().timeIntervalSince1970 - TimeInterval(boot.tv_sec)
    }
}
