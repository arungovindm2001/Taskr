//
//  UserNames.swift
//  Taskr
//
//  Account names for display: the short login name or the full name, per the Settings page.
//

import Foundation
import Darwin

/// Looks up account names by uid.
enum UserNames {
    private static var cache: [uid_t: (short: String, full: String)] = [:]

    static func display(_ uid: uid_t) -> String {
        let names = lookup(uid)
        return AppPrefs.shared.fullUserNames ? names.full : names.short
    }

    private static func lookup(_ uid: uid_t) -> (short: String, full: String) {
        if let hit = cache[uid] { return hit }
        var names = (short: "uid \(uid)", full: "uid \(uid)")
        if let entry = getpwuid(uid) {
            let short = String(cString: entry.pointee.pw_name)
            let gecos = entry.pointee.pw_gecos.map { String(cString: $0) } ?? ""
            let full = gecos.split(separator: ",").first.map(String.init) ?? ""
            names = (short, full.isEmpty ? short : full)
        }
        cache[uid] = names
        return names
    }
}
