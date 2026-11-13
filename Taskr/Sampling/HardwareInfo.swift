//
//  HardwareInfo.swift
//  Taskr
//
//  Static facts about this Mac's CPU and memory, read once.
//

import Foundation

/// What this Mac is made of. Values don't change while the app runs, so they are read once.
nonisolated struct HardwareInfo: Sendable {
    /// Marketing name of the processor, e.g. "Apple M2" or "Intel(R) Core(TM) i7".
    let processorName: String
    let physicalCores: Int
    let logicalCores: Int
    /// Core split on Apple silicon (performance / efficiency); `nil` on Intel.
    let performanceCores: Int?
    let efficiencyCores: Int?
    let isAppleSilicon: Bool
    /// Nominal clock in Hz. Only Intel Macs report one; Apple silicon doesn't expose its clock without root.
    let nominalFrequencyHz: Int?
    let virtualizationSupported: Bool
    let memoryBytes: UInt64
    let pageSize: Int

    static let current = HardwareInfo()

    private init() {
        processorName = Sysctl.string("machdep.cpu.brand_string") ?? "Processor"
        physicalCores = Sysctl.int("hw.physicalcpu") ?? ProcessInfo.processInfo.processorCount
        logicalCores = Sysctl.int("hw.logicalcpu") ?? ProcessInfo.processInfo.processorCount
        performanceCores = Sysctl.int("hw.perflevel0.physicalcpu")
        efficiencyCores = Sysctl.int("hw.perflevel1.physicalcpu")
        isAppleSilicon = Sysctl.int("hw.optional.arm64") == 1
        nominalFrequencyHz = Sysctl.int("hw.cpufrequency")
        virtualizationSupported = Sysctl.int("kern.hv_support") == 1
        memoryBytes = ProcessInfo.processInfo.physicalMemory
        pageSize = Int(getpagesize())
    }

    /// "Apple silicon (arm64)" or "Intel (x86_64)".
    var architecture: String { isAppleSilicon ? "Apple silicon (arm64)" : "Intel (x86_64)" }

    /// "8 (4 performance, 4 efficiency)" on Apple silicon, just the count elsewhere.
    var coreSummary: String {
        if let p = performanceCores, let e = efficiencyCores, p + e > 0 {
            return "\(physicalCores) (\(p)P + \(e)E)"
        }
        return "\(physicalCores)"
    }
}
