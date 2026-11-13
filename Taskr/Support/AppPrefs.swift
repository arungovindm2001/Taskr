//
//  AppPrefs.swift
//  Taskr
//
//  The user's settings, saved in UserDefaults and observable so the UI follows changes at once.
//

import SwiftUI
import AppKit
import Observation

/// How often Taskr samples.
enum RefreshSpeed: String, CaseIterable, Identifiable {
    case high, normal, low, paused
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// Seconds between samples, or `nil` while paused.
    var seconds: Double? {
        switch self {
        case .high: 0.5
        case .normal: 1
        case .low: 4
        case .paused: nil
        }
    }
}

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { self == .system ? "Match system" : rawValue.capitalized }
}

/// Processes-table columns the user can hide. Name, Status, CPU and Memory always show.
enum OptionalColumn: String, CaseIterable, Identifiable {
    case disk, network, gpu, energy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .disk: "Disk"
        case .network: "Network"
        case .gpu: "GPU"
        case .energy: "Energy impact"
        }
    }
}

@Observable
final class AppPrefs {
    static let shared = AppPrefs()
    private let defaults = UserDefaults.standard

    var startPage: Page { didSet { defaults.set(startPage.rawValue, forKey: "startPage") } }
    var floatAbove: Bool { didSet { defaults.set(floatAbove, forKey: "floatAbove"); applyWindowLevel() } }
    var showInDock: Bool { didSet { defaults.set(showInDock, forKey: "showInDock"); applyDock() } }
    var keepInMenuBar: Bool { didSet { defaults.set(keepInMenuBar, forKey: "keepInMenuBar") } }
    var refresh: RefreshSpeed { didSet { defaults.set(refresh.rawValue, forKey: "refresh") } }
    var theme: ThemeChoice { didSet { defaults.set(theme.rawValue, forKey: "theme"); applyAppearance() } }
    var fullUserNames: Bool { didSet { defaults.set(fullUserNames, forKey: "fullUserNames") } }
    var historyAllProcesses: Bool { didSet { defaults.set(historyAllProcesses, forKey: "historyAllProcesses") } }
    var confirmEnd: Bool { didSet { defaults.set(confirmEnd, forKey: "confirmEnd") } }
    var hiddenColumns: Set<String> { didSet { defaults.set(Array(hiddenColumns), forKey: "hiddenColumns") } }

    private init() {
        let d = UserDefaults.standard
        startPage = Page(rawValue: d.string(forKey: "startPage") ?? "") ?? .processes
        floatAbove = d.bool(forKey: "floatAbove")
        showInDock = d.object(forKey: "showInDock") as? Bool ?? true
        keepInMenuBar = d.object(forKey: "keepInMenuBar") as? Bool ?? true
        refresh = RefreshSpeed(rawValue: d.string(forKey: "refresh") ?? "") ?? .normal
        theme = ThemeChoice(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        fullUserNames = d.object(forKey: "fullUserNames") as? Bool ?? true
        historyAllProcesses = d.bool(forKey: "historyAllProcesses")
        confirmEnd = d.object(forKey: "confirmEnd") as? Bool ?? true
        hiddenColumns = Set(d.stringArray(forKey: "hiddenColumns") ?? [])
    }

    // MARK: Derived

    /// The Dock can only be hidden if the menu bar item is there to reach the app.
    var menuBarVisible: Bool { keepInMenuBar || !showInDock }

    func isVisible(_ column: OptionalColumn) -> Bool { !hiddenColumns.contains(column.rawValue) }

    func setVisible(_ column: OptionalColumn, _ visible: Bool) {
        if visible { hiddenColumns.remove(column.rawValue) } else { hiddenColumns.insert(column.rawValue) }
    }

    /// Sleeps until the next sample is due. Returns `false` while paused (after a short wait), so callers skip sampling.
    func tick() async -> Bool {
        guard let seconds = refresh.seconds else {
            try? await Task.sleep(for: .milliseconds(500))
            return false
        }
        try? await Task.sleep(for: .seconds(seconds))
        return refresh.seconds != nil
    }

    // MARK: Applying

    func applyAll() {
        applyAppearance()
        applyDock()
        applyWindowLevel()
    }

    func applyWindowLevel() {
        for window in NSApp.windows where window.canBecomeMain { window.level = floatAbove ? .floating : .normal }
    }

    func applyDock() {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        NSApp.activate()
    }

    func applyAppearance() {
        switch theme {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
