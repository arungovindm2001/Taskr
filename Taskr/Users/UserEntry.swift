//
//  UserEntry.swift
//  Taskr
//
//  The processes of one user account, as shown on the Users page.
//

import Foundation
import Darwin
import TaskrCore

/// One row of the Users page: an account and the app groups it is running.
struct UserEntry: Identifiable {
    /// Real accounts are keyed by uid; everything below uid 500 (root and the `_` service accounts) is one "System" entry.
    let id: uid_t
    let name: String
    let status: String
    let groups: [ProcessGroup]

    var processCount: Int { groups.reduce(0) { $0 + $1.processes.count } }
    var cpu: Double { groups.reduce(0) { $0 + $1.cpu } }
    var memory: UInt64 { groups.reduce(0) { $0 + $1.memory } }
    var disk: Double { groups.reduce(0) { $0 + $1.disk } }

    /// First uid that belongs to a person rather than the system.
    private static let firstRealUID: uid_t = 500

    /// Splits the store's groups by owner. A group whose processes belong to several users (an app and its
    /// root-owned helper) appears under each of them with only that user's processes.
    static func build(from groups: [ProcessGroup]) -> [UserEntry] {
        var byUser: [uid_t: [ProcessGroup]] = [:]
        for group in groups {
            let owners = Dictionary(grouping: group.processes) { process -> uid_t in
                let uid = ProcessOwners.uid(for: process.pid)
                return uid >= firstRealUID ? uid : 0
            }
            for (uid, processes) in owners {
                var part = group
                part.processes = processes
                byUser[uid, default: []].append(part)
            }
        }

        let console = consoleUID()
        return byUser.map { uid, groups in
            UserEntry(id: uid, name: displayName(uid), status: status(uid, console: console), groups: groups)
        }
        .sorted { ($0.id == console ? 0 : $0.id == 0 ? 2 : 1, $0.name) < ($1.id == console ? 0 : $1.id == 0 ? 2 : 1, $1.name) }
    }

    /// The account logged in at the screen right now.
    static func consoleUID() -> uid_t {
        var info = stat()
        return stat("/dev/console", &info) == 0 ? info.st_uid : getuid()
    }

    private static func displayName(_ uid: uid_t) -> String {
        if uid == 0 { return "System" }
        return getpwuid(uid).map { String(cString: $0.pointee.pw_name) } ?? "uid \(uid)"
    }

    private static func status(_ uid: uid_t, console: uid_t) -> String {
        if uid == 0 { return "System" }
        return uid == console ? "Active" : "Signed in"
    }
}
