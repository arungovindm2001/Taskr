//
//  PhysicalDisks.swift
//  Taskr
//
//  Finds the machine's physical disks (internal SSD, USB and Thunderbolt drives, SD cards), the volumes
//  mounted from each, and their cumulative I/O counters.
//

import Foundation
import IOKit
import DiskArbitration

/// A physical storage device and the volumes mounted from it.
nonisolated struct PhysicalDisk: Sendable, Identifiable, Equatable {
    /// BSD name of the whole disk, e.g. "disk0".
    let id: String
    /// Marketing name from the driver, e.g. "APPLE SSD AP0256Z". `nil` if the driver doesn't give one.
    let model: String?
    let sizeBytes: Int64
    let isInternal: Bool
    /// `true` for flash, `false` for spinning disks, `nil` if unknown.
    let isSolidState: Bool?
    /// How it's attached, as IOKit words it: "USB", "PCI-Express", "Apple Fabric", ...
    let interconnect: String?
    var volumes: [Volume]

    /// One mounted, user-visible volume.
    struct Volume: Sendable, Equatable {
        let name: String
        let path: String
        /// Format as macOS words it, e.g. "APFS".
        let format: String?
        let available: Int64
        let isEncrypted: Bool
    }

    /// Whether the startup volume lives on this disk.
    var isSystem: Bool { volumes.contains { $0.path == "/" } }

    /// Free space. APFS volumes share their container's space, so take the largest; otherwise add them up.
    var availableBytes: Int64 {
        if volumes.first?.format?.contains("APFS") == true { return volumes.map(\.available).max() ?? 0 }
        return volumes.reduce(0) { $0 + $1.available }
    }

    var isEncrypted: Bool { volumes.contains { $0.isEncrypted } }
}

/// Cumulative driver counters for one disk. Rates are differences between two readings.
nonisolated struct DiskCounters: Sendable {
    var bytesRead: UInt64 = 0, bytesWritten: UInt64 = 0
    var opsRead: UInt64 = 0, opsWritten: UInt64 = 0
    /// Summed time requests spent in flight. Concurrent requests add up, so this can exceed wall time.
    var busyNanoseconds: UInt64 = 0
}

/// One second of activity on one disk.
nonisolated struct DiskSample: Sendable {
    var read: Double            // bytes per second
    var write: Double
    /// % of the interval the disk had requests in flight (capped at 100).
    var active: Double
    /// Average time per request in milliseconds, if any requests completed.
    var latencyMs: Double?
}

/// Reads physical disks from the IORegistry and DiskArbitration.
nonisolated enum PhysicalDisks {

    // MARK: Public

    /// Every physical disk that has a volume mounted, internal disks first. Blocking: call off the main thread.
    static func list() -> [PhysicalDisk] {
        var disks: [UInt64: PhysicalDisk] = [:]
        forEachDriver { driver, media in
            var entryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(driver, &entryID)
            let device = searched(driver, "Device Characteristics") as? [String: Any]
            let protocolInfo = searched(driver, "Protocol Characteristics") as? [String: Any]
            let medium = device?["Medium Type"] as? String
            disks[entryID] = PhysicalDisk(
                id: media.name,
                model: (device?["Product Name"] as? String)?.trimmingCharacters(in: .whitespaces),
                sizeBytes: media.size,
                isInternal: (protocolInfo?["Physical Interconnect Location"] as? String) != "External",
                isSolidState: medium.map { $0 == "Solid State" },
                interconnect: protocolInfo?["Physical Interconnect"] as? String,
                volumes: [])
        }

        for (driverID, volume) in mountedVolumes() {
            disks[driverID]?.volumes.append(volume)
        }

        // A disk with nothing mounted (ejected, or unplugged but its driver hasn't left the registry yet) is gone
        // as far as the user is concerned, so it isn't listed.
        return disks.values.filter { !$0.volumes.isEmpty }.sorted {
            $0.isInternal != $1.isInternal ? $0.isInternal : $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }
    }

    /// Cumulative counters by whole-disk BSD name.
    static func counters() -> [String: DiskCounters] {
        var result: [String: DiskCounters] = [:]
        forEachDriver { driver, media in
            guard let stats = IORegistryEntryCreateCFProperty(driver, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { return }
            func value(_ key: String) -> UInt64 { (stats[key] as? NSNumber)?.uint64Value ?? 0 }
            result[media.name] = DiskCounters(
                bytesRead: value("Bytes (Read)"), bytesWritten: value("Bytes (Write)"),
                opsRead: value("Operations (Read)"), opsWritten: value("Operations (Write)"),
                busyNanoseconds: value("Total Time (Read)") + value("Total Time (Write)"))
        }
        return result
    }

    // MARK: Drivers

    /// Calls `body` for each real storage driver, skipping mounted disk images (virtual interface).
    private static func forEachDriver(_ body: (_ driver: io_registry_entry_t, _ media: (name: String, size: Int64)) -> Void) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        var driver = IOIteratorNext(iterator)
        while driver != 0 {
            defer { IOObjectRelease(driver); driver = IOIteratorNext(iterator) }
            let protocolInfo = searched(driver, "Protocol Characteristics") as? [String: Any]
            if (protocolInfo?["Physical Interconnect"] as? String) == "Virtual Interface" { continue }
            guard let media = wholeMedia(of: driver) else { continue }
            body(driver, media)
        }
    }

    /// The whole-disk `IOMedia` under a driver: its BSD name ("disk4") and size.
    private static func wholeMedia(of driver: io_registry_entry_t) -> (name: String, size: Int64)? {
        var children: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(driver, kIOServicePlane, &children) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(children) }

        var child = IOIteratorNext(children)
        while child != 0 {
            defer { IOObjectRelease(child); child = IOIteratorNext(children) }
            guard IOObjectConformsTo(child, "IOMedia") != 0,
                  (property(child, "Whole") as? Bool) == true,
                  let name = property(child, "BSD Name") as? String else { continue }
            return (name, (property(child, "Size") as? NSNumber)?.int64Value ?? 0)
        }
        return nil
    }

    // MARK: Volumes

    /// Mounted volumes paired with the registry ID of the physical driver they live on.
    private static func mountedVolumes() -> [(UInt64, PhysicalDisk.Volume)] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeLocalizedFormatDescriptionKey, .volumeIsEncryptedKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                               options: [.skipHiddenVolumes]),
              let session = DASessionCreate(kCFAllocatorDefault) else { return [] }

        var result: [(UInt64, PhysicalDisk.Volume)] = []
        for url in urls {
            guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
                  let description = DADiskCopyDescription(disk) as? [String: Any],
                  let bsdName = description[kDADiskDescriptionMediaBSDNameKey as String] as? String,
                  let driverID = physicalDriverID(forBSDName: bsdName) else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            // "Important usage" counts purgeable space, as Finder does for the startup disk, but the system
            // cache service fails (and logs) for external drives, so they use the plain free-space figure.
            let free: Int64? = url.path == "/"
                ? (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
                : (try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity.map(Int64.init)
            result.append((driverID, PhysicalDisk.Volume(
                name: values?.volumeName ?? url.lastPathComponent,
                path: url.path,
                format: values?.volumeLocalizedFormatDescription,
                available: free ?? 0,
                isEncrypted: values?.volumeIsEncrypted ?? false)))
        }
        return result
    }

    /// Follows a volume's IORegistry parents (APFS volume → container → partition → disk) up to its storage driver.
    private static func physicalDriverID(forBSDName bsdName: String) -> UInt64? {
        var current = IOServiceGetMatchingService(kIOMainPortDefault, IOBSDNameMatching(kIOMainPortDefault, 0, bsdName))
        guard current != 0 else { return nil }
        while true {
            if IOObjectConformsTo(current, "IOBlockStorageDriver") != 0 {
                var entryID: UInt64 = 0
                IORegistryEntryGetRegistryEntryID(current, &entryID)
                IOObjectRelease(current)
                return entryID
            }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else {
                IOObjectRelease(current)
                return nil
            }
            IOObjectRelease(current)
            current = parent
        }
    }

    // MARK: Registry properties

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// A property on the entry or any of its ancestors (the model name lives a few levels up).
    private static func searched(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key as CFString, kCFAllocatorDefault,
                                        IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
    }
}
