//
//  StartupPage.swift
//  Taskr
//
//  The Startup apps page: what opens when you log in, whether it's enabled, and its impact.
//

import SwiftUI

/// Column geometry for the startup table. The Name column takes the remaining width.
private enum StartupColumn {
    static let developer: CGFloat = 220
    static let status: CGFloat = 120
    static let impact: CGFloat = 150
    static let type: CGFloat = 150
    static let rowHeight: CGFloat = 28
}

/// Login items and launch agents, with Disable / Enable and Show in Finder.
struct StartupPage: View {
    let store: StartupStore
    let history: AppHistoryStore
    @State private var query = ""

    var body: some View {
        let rows = store.rows(matching: query, history: history)

        VStack(spacing: 0) {
            HStack {
                Text("Items that open when you log in.")
                Spacer()
                Text("Last restart: **\(Self.lastRestart)**")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(height: 40)
            Divider()
            header
            Divider()
            if rows.isEmpty {
                ContentUnavailableView(store.loaded ? "No startup items" : "Looking for startup items…",
                                       systemImage: "power",
                                       description: Text(store.loaded ? "Nothing is set to open when you log in." : ""))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows, id: \.item.id) { row in rowView(row.item, impact: row.impact) }
                    }
                }
            }
            if !rows.isEmpty {
                Divider()
                Text("Launch agents can be disabled here and take effect at your next login. Login items are managed in System Settings ▸ General ▸ Login Items.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 30)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Startup apps")
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup {
                Button { Task { await store.toggleSelected() } } label: {
                    Label(store.selected?.isEnabled == false ? "Enable" : "Disable",
                          systemImage: store.selected?.isEnabled == false ? "checkmark.circle" : "nosign")
                }
                .disabled(store.selected?.canToggle != true)
                .help(store.selected.map { $0.canToggle ? "" : "Login items are managed in System Settings." } ?? "")
                Button {
                    if let path = store.selected?.targetPath ?? store.selected?.plistPath { ProcessActions.reveal(path) }
                } label: { Label("Show in Finder", systemImage: "folder") }
                .disabled(store.selected == nil)
            }
        }
        .task {
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            headerCell("Name", key: .name, width: nil, leading: 16)
            headerCell("Developer", key: nil, width: StartupColumn.developer, leading: 8)
            headerCell("Status", key: .status, width: StartupColumn.status, leading: 8)
            headerCell("Startup impact", key: .impact, width: StartupColumn.impact, leading: 8)
            headerCell("Type", key: nil, width: StartupColumn.type, leading: 8)
        }
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func headerCell(_ title: String, key: StartupSort?, width: CGFloat?, leading: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            if let key, store.sortKey == key { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
        }
        .padding(.leading, leading)
        .frame(minWidth: width ?? 0, maxWidth: width ?? .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { if let key { store.sortKey = key } }
    }

    // MARK: Rows

    private func rowView(_ item: StartupItem, impact: StartupImpact) -> some View {
        let selected = store.selection == item.id
        let secondary: Color = selected ? .white.opacity(0.85) : .secondary
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(nsImage: IconCache.shared.icon(for: item.targetPath)).resizable().frame(width: 16, height: 16)
                Text(item.name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.developer).foregroundStyle(secondary).lineLimit(1)
                .padding(.leading, 8).frame(width: StartupColumn.developer, alignment: .leading)
            Text(item.isEnabled ? "Enabled" : "Disabled").foregroundStyle(secondary)
                .padding(.leading, 8).frame(width: StartupColumn.status, alignment: .leading)
            Text(impact.label).fontWeight(impact == .high ? .medium : .regular)
                .padding(.leading, 8).frame(width: StartupColumn.impact, alignment: .leading)
            Text(item.kind.rawValue).foregroundStyle(secondary)
                .padding(.leading, 8).frame(width: StartupColumn.type, alignment: .leading)
        }
        .font(.system(size: 13))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(height: StartupColumn.rowHeight)
        .background(selected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { store.selection = item.id }
    }

    /// "6 Nov, 09:12", from the kernel's boot time.
    private static var lastRestart: String {
        let boot = Date().addingTimeInterval(-(Sysctl.uptime() ?? 0))
        return boot.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
