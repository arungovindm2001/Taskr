//
//  RootView.swift
//  Taskr
//
//  The window's root: sidebar navigation on the left, the selected page on the right.
//

import SwiftUI

/// Sidebar (Processes … Services, then Settings) plus the detail page for the current selection.
struct RootView: View {
    @State private var selection: Page? = AppPrefs.shared.startPage
    /// Lives here so the graphs keep their history while another page is showing.
    @State private var performance = PerformanceStore()
    /// Also lives here: sampling must keep running on every page so App history can record.
    @State private var processes = ProcessStore()
    @State private var detailsFocus: Int32?
    @State private var history = AppHistoryStore()
    @State private var startup = StartupStore()
    @State private var services = ServicesStore()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach([Page.processes, .performance, .appHistory, .startup, .users, .details, .services]) { row($0) }
                Section { row(.settings) }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            switch selection ?? .processes {
            case .processes: ProcessesPage(store: processes, onGoToDetails: { detailsFocus = $0.primaryPid; selection = .details })
            case .appHistory: AppHistoryPage(store: history)
            case .details: DetailsPage(store: processes, focusPid: $detailsFocus)
            case .services: ServicesPage(store: services)
            case .users: UsersPage(store: processes)
            case .startup: StartupPage(store: startup, history: history)
            case .performance: PerformancePage(store: performance)
            case .settings: SettingsPage(history: history)
            case let p: ShellPage(page: p)
            }
        }
        .onAppear { AppPrefs.shared.applyAll() }
        .task { await performance.run() }
        .task { await processes.run() }
        .task { await history.run(from: processes) }
    }

    /// One sidebar row for a page.
    private func row(_ p: Page) -> some View {
        Label(p.title, systemImage: p.symbol).tag(p)
    }
}
