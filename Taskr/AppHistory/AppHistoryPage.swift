//
//  AppHistoryPage.swift
//  Taskr
//
//  The App history page: cumulative CPU time, network, disk writes and energy per app.
//

import SwiftUI

/// Column geometry for the history table. The Name column takes the remaining width.
private enum HistoryColumn {
    static let cpuTime: CGFloat = 120
    static let network: CGFloat = 120
    static let disk: CGFloat = 120
    static let energy: CGFloat = 140
    static let rowHeight: CGFloat = 28
    static let headerHeight: CGFloat = 28
}

/// Usage history for the current user account, recorded while Taskr runs.
struct AppHistoryPage: View {
    let store: AppHistoryStore
    @State private var query = ""
    @State private var confirmDelete = false

    var body: some View {
        let rows = store.rows(matching: query)

        VStack(spacing: 0) {
            Text("Resource usage since \(store.since.formatted(.dateTime.day().month(.abbreviated).year())) for the current user account, recorded while Taskr is running.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 40)
            Divider()
            header
            Divider()
            if rows.isEmpty {
                ContentUnavailableView("No usage recorded yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Leave Taskr running and apps will appear here as they use the CPU, network and disk."))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, usage in
                            row(usage, striped: index % 2 == 1)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("App history")
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup {
                Button { confirmDelete = true } label: {
                    Label("Delete usage history", systemImage: "trash")
                }
                Picker("Show", selection: Bindable(store).scope) {
                    ForEach(AppHistoryScope.allCases) { Text("Show: \($0.rawValue)").tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
        .confirmationDialog("Delete usage history?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { store.deleteHistory() }
        } message: {
            Text("Taskr will forget what every app has used so far and start counting again from now.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            headerCell("Name", key: .name, width: nil, align: .leading, leading: 16)
            headerCell("CPU time", key: .cpuTime, width: HistoryColumn.cpuTime, align: .trailing)
            headerCell("Network", key: .network, width: HistoryColumn.network, align: .trailing)
            headerCell("Disk written", key: .diskWritten, width: HistoryColumn.disk, align: .trailing)
            headerCell("Energy impact", key: .energy, width: HistoryColumn.energy, align: .leading, leading: 8)
        }
        .frame(height: HistoryColumn.headerHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func headerCell(_ title: String, key: AppHistorySort, width: CGFloat?, align: Alignment,
                            leading: CGFloat = 0) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            if store.sortKey == key { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
        }
        .padding(.leading, leading)
        .padding(.trailing, align == .trailing ? 12 : 0)
        .frame(minWidth: width ?? 0, maxWidth: width ?? .infinity, maxHeight: .infinity, alignment: align)
        .contentShape(Rectangle())
        .onTapGesture { store.sortKey = key }
    }

    // MARK: Rows

    private func row(_ usage: AppUsage, striped: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(nsImage: IconCache.shared.icon(for: usage.iconPath)).resizable().frame(width: 16, height: 16)
                Text(usage.name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            numberCell(Self.clock(usage.cpuSeconds), width: HistoryColumn.cpuTime)
            numberCell(Self.size(usage.networkBytes), width: HistoryColumn.network)
            numberCell(Self.size(usage.diskWrittenBytes), width: HistoryColumn.disk)

            Text(ProcessFormat.energyLabels[ProcessFormat.energyLevel(watts: usage.averageWatts)])
                .padding(.leading, 8)
                .frame(width: HistoryColumn.energy, alignment: .leading)
        }
        .font(.system(size: 13))
        .frame(height: HistoryColumn.rowHeight)
        .background(striped ? Color.primary.opacity(0.04) : Color.clear)
    }

    private func numberCell(_ text: String, width: CGFloat) -> some View {
        Text(text).monospacedDigit()
            .padding(.trailing, 12)
            .frame(width: width, alignment: .trailing)
    }

    /// "6.4 GB" or "420 MB", never smaller than MB (so idle apps read "0 MB", as in Windows).
    private static func size(_ bytes: Double) -> String {
        bytes >= 1e9 ? String(format: "%.1f GB", bytes / 1e9) : String(format: "%.0f MB", bytes / 1e6)
    }

    /// "1:42:10" (hours:minutes:seconds).
    private static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}
