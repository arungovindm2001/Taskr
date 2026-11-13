//
//  ProcessesPage.swift
//  Taskr
//
//  The Processes page: header with column totals, the scrolling grouped list, and the toolbar.
//

import SwiftUI

/// The Processes page. A thin shell that wires the store to the table header, rows, toolbar and sheets.
struct ProcessesPage: View {
    /// Owned by `RootView` so sampling (and App history recording) continues on other pages.
    let store: ProcessStore
    @State private var query = ""
    @State private var showRunSheet = false
    @State private var infoTarget: ProcessTarget?

    /// Called when the user chooses "Go to Details" on a row.
    var onGoToDetails: (ProcessTarget) -> Void

    init(store: ProcessStore, onGoToDetails: @escaping (ProcessTarget) -> Void = { _ in }) {
        self.store = store
        self.onGoToDetails = onGoToDetails
    }

    var body: some View {
        let rows = store.rows(matching: query)
        let totals = store.headerTotals

        VStack(spacing: 0) {
            ProcessTableHeader(store: store, totals: totals)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        ProcessRowView(row: row, store: store,
                                       onGoToDetails: onGoToDetails,
                                       onGetInfo: { infoTarget = $0 })
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Processes")
        .navigationSubtitle("\(totals.processCount) processes")
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showRunSheet) {
            RunTaskSheet { text, admin in
                do { try ProcessActions.runTask(text, admin: admin) }
                catch { ProcessActions.showError("Couldn’t run that task", error.localizedDescription) }
            }
        }
        .sheet(item: $infoTarget) { ProcessInfoSheet(target: $0) }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        let target = store.target(for: store.selection)
        ToolbarItemGroup {
            Button { showRunSheet = true } label: {
                Label { Text("Run new task") } icon: { Image(systemName: "play.rectangle").foregroundStyle(Color.accentColor) }
            }
            Button { if let target { ProcessActions.confirmEnd(target) } } label: {
                Label { Text("End task") } icon: { Image(systemName: "xmark.octagon").foregroundStyle(.red) }
            }
            .disabled(target == nil)
            .keyboardShortcut(.delete, modifiers: .command)
            Button { if let target { store.toggleEfficiency(target) } } label: {
                Label { Text("Efficiency mode") } icon: { Image(systemName: "leaf").foregroundStyle(.green) }
            }
            .disabled(target == nil)
            Menu {
                Button("Expand All") { store.expandAll() }
                Button("Collapse All") { store.collapseAll() }
            } label: {
                Label("View", systemImage: "eye")
            }
        }
    }
}
