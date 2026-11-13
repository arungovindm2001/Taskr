//
//  ProcessRowView+ContextMenu.swift
//  Taskr
//
//  The right-click menu for a row, mirroring the design: Expand, End Task, Efficiency Mode, Resource Values, …
//

import SwiftUI

extension ProcessRowView {

    /// Menu items for the row; resolves the row to a `ProcessTarget` first.
    @ViewBuilder
    var contextMenuItems: some View {
        let target = store.target(for: row.id)

        if row.expandable {
            Button(row.expanded ? "Collapse" : "Expand") { store.toggle(row.id) }
        }

        if let target {
            Divider()
            Button("End Task") { ProcessActions.confirmEnd(target) }
            Button("Force Quit") { ProcessActions.confirmEnd(target, force: true) }
                .keyboardShortcut(.escape, modifiers: [.command, .option])
            Button(store.isEfficient(target) ? "Turn Off Efficiency Mode" : "Efficiency Mode") {
                store.toggleEfficiency(target)
            }

            Menu("Resource Values") {
                Menu("Memory") {
                    Picker("Memory", selection: $store.memoryAsPercent) {
                        Text("Values").tag(false)
                        Text("Percents").tag(true)
                    }
                    .pickerStyle(.inline)
                }
            }
            Button("Sample Process…") { ProcessActions.sampleProcess(target) }

            Divider()
            if let path = target.revealPath, !path.isEmpty {
                Button("Reveal in Finder") { ProcessActions.reveal(path) }
            }
            Button("Search Online") { ProcessActions.searchOnline(target.title) }

            Divider()
            Button("Go to Details") { onGoToDetails(target) }
            Button("Get Info") { onGetInfo(target) }
                .keyboardShortcut("i", modifiers: .command)
        }
    }
}
