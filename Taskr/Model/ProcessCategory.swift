//
//  ProcessCategory.swift
//  Taskr
//
//  The three top-level sections of the Processes list, matching Windows Task Manager.
//

import Foundation

/// Which section of the Processes list a group of processes belongs to.
enum ProcessCategory: String, CaseIterable {
    /// Regular Dock apps (anything `NSWorkspace` reports with a `.regular` activation policy).
    case apps
    /// Helpers, daemons and agents that don't belong to the operating system.
    case background
    /// Processes that ship with macOS (executables under `/System`, `/usr`, and similar).
    case macOS

    /// Stable identifier for the section header row. The `cat:` prefix keeps it from colliding with group ids.
    var id: String { "cat:\(rawValue)" }

    /// Header text shown in the list.
    var title: String {
        switch self {
        case .apps: "Apps"
        case .background: "Background processes"
        case .macOS: "macOS processes"
        }
    }
}
