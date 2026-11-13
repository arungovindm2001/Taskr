//
//  StartupItem.swift
//  Taskr
//
//  One thing that starts when you log in: a login item or a launch agent.
//

import Foundation

/// Where a startup item comes from.
nonisolated enum StartupKind: String, Sendable {
    /// An app listed under System Settings ▸ General ▸ Login Items ▸ Open at Login.
    case loginItem = "Login item"
    /// A launchd agent plist in `~/Library/LaunchAgents` or `/Library/LaunchAgents`.
    case launchAgent = "Launch agent"
}

/// An item that starts at login.
nonisolated struct StartupItem: Identifiable, Equatable, Sendable {
    /// Plist path for launch agents, app path for login items.
    let id: String
    let name: String
    let developer: String
    let kind: StartupKind
    /// Whether it will start at the next login. Always `true` for login items.
    var isEnabled: Bool
    /// The launchd label (launch agents only); needed to enable or disable the item.
    let label: String?
    /// The plist that defines the item (launch agents only).
    let plistPath: String?
    /// The app or executable the item runs; used for the icon, "Show in Finder" and matching running processes.
    let targetPath: String?

    /// Only launch agents can be switched off from here. Login items are managed in System Settings.
    var canToggle: Bool { kind == .launchAgent && label != nil }

    /// The id `ProcessGroup` would give this item once running: its outermost `.app`, else the executable itself.
    var processGroupID: String? {
        guard let targetPath else { return nil }
        return ProcessGrouping.bundlePath(targetPath) ?? targetPath
    }
}
