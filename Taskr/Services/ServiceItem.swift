//
//  ServiceItem.swift
//  Taskr
//
//  One launchd job as shown on the Services page.
//

import Foundation

/// A job loaded in one of launchd's domains.
nonisolated struct ServiceItem: Identifiable, Hashable, Sendable {
    /// `<domain>/<label>`, unique across domains.
    let id: String
    let label: String
    /// `system` or `gui/<uid>`.
    let domain: String
    /// Process id while running, `nil` when stopped.
    let pid: Int32?
    let description: String

    var isRunning: Bool { pid != nil }
    var isSystem: Bool { domain == "system" }
    /// What `launchctl` takes to address this job.
    var target: String { "\(domain)/\(label)" }
}
