//
//  RootView.swift
//  Taskr
//
//  The window's root: sidebar navigation on the left, the selected page on the right.
//

import SwiftUI

/// Sidebar (Processes, Performance, System, Settings) plus the detail page for the current selection.
struct RootView: View {
    @State private var selection: Page? = .processes

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                row(.processes)
                Section("Performance") { ForEach([Page.cpu, .memory, .disk, .network, .gpu]) { row($0) } }
                Section("System") { ForEach([Page.appHistory, .startup, .users, .details, .services]) { row($0) } }
                Section { row(.settings) }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            switch selection ?? .processes {
            case .processes: ProcessesPage(onGoToDetails: { _ in selection = .details })
            case let p: ShellPage(page: p)
            }
        }
    }

    /// One sidebar row for a page.
    private func row(_ p: Page) -> some View {
        Label(p.title, systemImage: p.symbol).tag(p)
    }
}
