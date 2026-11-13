//
//  ProcessTarget.swift
//  Taskr
//
//  What an action (End Task, Efficiency Mode, Get Info, …) operates on.
//

import Foundation

/// The thing a toolbar button or context-menu item acts on: one process, or a whole group of them.
struct ProcessTarget: Identifiable {
    /// Unique per set of pids, so SwiftUI can present a sheet for a target.
    var id: String { pids.map(String.init).joined(separator: ",") }

    /// Display name used in confirmation alerts.
    let title: String
    let pids: [Int32]
    /// Set when the target is a regular Dock app, so it can be quit gracefully through `NSRunningApplication`.
    let appBundlePath: String?
    /// File to reveal in Finder (bundle path for apps, executable path otherwise).
    let revealPath: String?
    /// The pid to sample or inspect when the target is a group: the app's main process.
    var primaryPid: Int32? = nil
}
