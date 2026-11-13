//
//  RootView.swift
//  Taskr
//
//  The window's root: sidebar navigation on the left, the selected page on the right.
//

import SwiftUI

/// Sidebar (Processes … Services, then Settings) plus the detail page for the current selection.
struct RootView: View {
    @State private var selection: Page? = .processes
    /// Lives here so the graphs keep their history while another page is showing.
    @State private var performance = PerformanceStore()
    /// Also lives here: sampling must keep running on every page so App history can record.
    @State private var processes = ProcessStore()
    @State private var history = AppHistoryStore()
    @State private var startup = StartupStore()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach([Page.processes, .performance, .appHistory, .startup, .users, .details, .services]) { row($0) }
                Section { row(.settings) }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            switch selection ?? .processes {
            case .processes: ProcessesPage(store: processes, onGoToDetails: { _ in selection = .details })
            case .appHistory: AppHistoryPage(store: history)
            case .users: UsersPage(store: processes)
            case .startup: StartupPage(store: startup, history: history)
            case .performance: PerformancePage(store: performance)
            case let p: ShellPage(page: p)
            }
        }
        .task { await performance.run() }
        .task { await processes.run() }
        .task { await history.run(from: processes) }
    }

    /// One sidebar row for a page.
    private func row(_ p: Page) -> some View {
        Label(p.title, systemImage: p.symbol).tag(p)
    }
}
