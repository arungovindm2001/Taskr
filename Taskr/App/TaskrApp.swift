//
//  TaskrApp.swift
//  Taskr
//
//  App entry point: one window hosting the root navigation view, plus an optional menu bar item.
//

import SwiftUI
import AppKit

/// Decides whether closing the window quits the app, per the "Keep running in the menu bar" setting.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPrefs.shared.applyAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !AppPrefs.shared.menuBarVisible
    }
}

/// A single-window app; the minimum size keeps all eight columns visible.
@main
struct TaskrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var prefs = AppPrefs.shared

    var body: some Scene {
        WindowGroup("Task Manager", id: "main") {
            RootView()
                .frame(minWidth: 1040, minHeight: 560)
        }
        .defaultSize(width: 1100, height: 700)
        .windowToolbarStyle(.unified)

        MenuBarExtra("Taskr", systemImage: "gauge.with.dots.needle.33percent",
                     isInserted: Binding(get: { prefs.menuBarVisible }, set: { _ in })) {
            MenuBarContent()
        }
    }
}

/// The menu bar item's menu: bring the window back, or quit.
private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Taskr") {
            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
            } else {
                openWindow(id: "main")
            }
            NSApp.activate()
        }
        Divider()
        Button("Quit Taskr") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
