//
//  GPUDevice.swift
//  Taskr
//
//  Whole-GPU utilization and static GPU facts from the IORegistry and Metal.
//

import Foundation
import IOKit
import Metal
import AppKit

/// Live whole-GPU readings from an `IOAccelerator` service's `PerformanceStatistics`.
/// Keys the driver doesn't report are `nil` (Apple GPUs report renderer and tiler; others may not).
nonisolated struct GPUDeviceStats: Sendable {
    var utilization: Double?
    var renderer: Double?
    var tiler: Double?
    /// Bytes of system memory the GPU is using.
    var memoryInUse: UInt64?

    /// Reads the current statistics, or `nil` if there is no accelerator or it reports nothing.
    static func read() -> GPUDeviceStats? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var best: GPUDeviceStats?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            guard let stats = GPUDevice.property(service, "PerformanceStatistics") as? [String: Any] else { continue }
            func number(_ key: String) -> Double? { (stats[key] as? NSNumber)?.doubleValue }
            let candidate = GPUDeviceStats(utilization: number("Device Utilization %"),
                                           renderer: number("Renderer Utilization %"),
                                           tiler: number("Tiler Utilization %"),
                                           memoryInUse: number("In use system memory").map { UInt64($0) })
            if best == nil || (candidate.utilization ?? 0) > (best?.utilization ?? 0) { best = candidate }
        }
        return best
    }
}

/// Static facts about the GPU, read once.
nonisolated struct GPUInfo: Sendable {
    let name: String
    let coreCount: Int?
    /// "Metal 3" or just "Metal".
    let metalSupport: String
    let unifiedMemory: Bool

    static let current = GPUInfo()

    private init() {
        let device = MTLCreateSystemDefaultDevice()
        name = device?.name ?? "GPU"
        unifiedMemory = device?.hasUnifiedMemory ?? false
        metalSupport = (device?.supportsFamily(.metal3) ?? false) ? "Metal 3" : (device == nil ? "Unavailable" : "Metal")
        coreCount = GPUDevice.coreCount()
    }
}

/// Registry helpers shared by the GPU readers.
nonisolated enum GPUDevice {
    static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// GPU core count (`gpu-core-count`), reported by Apple GPUs.
    static func coreCount() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            if let cores = property(service, "gpu-core-count") as? NSNumber { return cores.intValue }
        }
        return nil
    }
}
