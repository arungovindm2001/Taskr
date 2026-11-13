//
//  ProcessArchitecture.swift
//  Taskr
//
//  Which CPU architecture a process runs as, cached per pid.
//

import Foundation
import Darwin

/// "Apple" for native Apple-silicon code, "Intel" for x86-64 code (natively on an Intel Mac, or translated by Rosetta).
enum ProcessArchitecture {
    private static var cache: [Int32: String] = [:]
    private static let translatedFlag: Int32 = 0x00020000   // P_TRANSLATED
    private static let isAppleSilicon: Bool = {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }()

    static func label(for pid: Int32) -> String {
        if let hit = cache[pid] { return hit }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let label: String
        if sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 {
            let translated = info.kp_proc.p_flag & translatedFlag != 0
            label = (isAppleSilicon && !translated) ? "Apple" : "Intel"
        } else {
            label = "–"
        }
        cache[pid] = label
        return label
    }

    static func prune(alive: Set<Int32>) { cache = cache.filter { alive.contains($0.key) } }
}
