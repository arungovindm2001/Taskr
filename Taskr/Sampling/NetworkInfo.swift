//
//  NetworkInfo.swift
//  Taskr
//
//  The primary network adapter: name, addresses, and Wi-Fi details.
//

import Foundation
import CoreWLAN
import Darwin

/// Facts about the primary network adapter shown on the Network page.
nonisolated struct NetworkInfo: Sendable {
    /// BSD name, e.g. "en0".
    let interface: String
    /// "Wi-Fi" or "Ethernet".
    let connectionType: String
    /// Wi-Fi generation when known, e.g. "Wi-Fi 6".
    let standard: String?
    /// Network name. macOS only reveals it to apps with Location access, so this is often `nil`.
    let networkName: String?
    let ipv4: String?
    let ipv6: String?
    /// Wi-Fi signal strength in dBm.
    let signal: Int?

    /// Picks the first Ethernet/Wi-Fi interface (`en*`) that is up and has an IPv4 address, preferring `en0`.
    static func read() -> NetworkInfo? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }

        var addresses: [String: (v4: String?, v6: String?)] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let name = String(cString: entry.pointee.ifa_name)
            let flags = Int32(entry.pointee.ifa_flags)
            guard name.hasPrefix("en"), flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let sa = entry.pointee.ifa_addr else { continue }

            var current = addresses[name] ?? (nil, nil)
            switch Int32(sa.pointee.sa_family) {
            case AF_INET:
                current.v4 = numericHost(sa)
            case AF_INET6:
                // Keep the first IPv6 address (usually link-local); drop the "%en0" scope suffix.
                if current.v6 == nil { current.v6 = numericHost(sa)?.components(separatedBy: "%").first }
            default:
                break
            }
            addresses[name] = current
        }

        let candidates = addresses.filter { $0.value.v4 != nil }
        guard let name = candidates.keys.contains("en0") ? "en0" : candidates.keys.sorted().first else { return nil }
        let found = candidates[name]

        let wifi = CWWiFiClient.shared().interface(withName: name)
        let rssi = wifi?.rssiValue()
        let isWiFi = wifi != nil && (rssi ?? 0) != 0
        return NetworkInfo(interface: name,
                           connectionType: isWiFi ? "Wi-Fi" : "Ethernet",
                           standard: isWiFi ? wifiStandard(wifi?.activePHYMode()) : nil,
                           networkName: isWiFi ? wifi?.ssid() : nil,
                           ipv4: found?.v4, ipv6: found?.v6,
                           signal: isWiFi ? rssi : nil)
    }

    private static func numericHost(_ address: UnsafePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                                 nil, 0, NI_NUMERICHOST)
        return result == 0 ? String(cString: host) : nil
    }

    private static func wifiStandard(_ mode: CWPHYMode?) -> String? {
        switch mode {
        case .mode11ax: "Wi-Fi 6"
        case .mode11ac: "Wi-Fi 5"
        case .mode11n: "Wi-Fi 4"
        case .none, .modeNone: nil
        default: "Wi-Fi"
        }
    }
}
