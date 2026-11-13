//
//  TaskrApp.swift
//  Taskr
//
//  App entry point: one window hosting the root navigation view.
//

import SwiftUI

/// A single-window app; the minimum size keeps all eight columns visible.
@main
struct TaskrApp: App {
    var body: some Scene {
        WindowGroup("Task Manager") {
            RootView()
                .frame(minWidth: 1040, minHeight: 560)
        }
        .defaultSize(width: 1100, height: 700)
        .windowToolbarStyle(.unified)
    }
}
