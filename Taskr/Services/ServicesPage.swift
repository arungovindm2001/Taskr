//
//  ServicesPage.swift
//  Taskr
//
//  The Services page: launchd jobs with PID, description, status and domain.
//

import SwiftUI

private enum ServiceColumn {
    static let pid: CGFloat = 70
    static let status: CGFloat = 100
    static let domain: CGFloat = 110
    static let descriptionMin: CGFloat = 120
    static let nameMin: CGFloat = 200
    static let rowHeight: CGFloat = 24
    static let headerHeight: CGFloat = 28
}

/// launchd services, with Start, Stop and Restart.
struct ServicesPage: View {
    let store: ServicesStore
    @State private var query = ""

    var body: some View {
        let rows = store.rows(matching: query)
        VStack(spacing: 0) {
            header
            Divider()
            if !store.loaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in rowView(row) }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Services")
        .navigationSubtitle("\(rows.count) of \(store.items.count) services shown")
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .task {
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                let service = store.selected
                Button { Task { await store.perform(.start) } } label: {
                    Label { Text("Start") } icon: { Image(systemName: "play.square").foregroundStyle(Color.accentColor) }
                }
                .disabled(service == nil || service?.isRunning == true)
                Button { Task { await store.perform(.stop) } } label: {
                    Label { Text("Stop") } icon: { Image(systemName: "xmark.octagon").foregroundStyle(.red) }
                }
                .disabled(service?.isRunning != true)
                Button { Task { await store.perform(.restart) } } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .disabled(service == nil)
                Menu {
                    Picker("Domain", selection: Bindable(store).domain) {
                        ForEach([ServiceDomainFilter.all, .system, .user], id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text("Domain: \(store.domain.title)")
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            cell("Name", .name, nil, .leading, 16, minWidth: ServiceColumn.nameMin)
            cell("PID", .pid, ServiceColumn.pid, .trailing)
            cell("Description", .description, nil, .leading, 8, minWidth: ServiceColumn.descriptionMin)
            cell("Status", .status, ServiceColumn.status, .leading, 8)
            cell("Domain", .domain, ServiceColumn.domain, .leading, 8)
        }
        .frame(height: ServiceColumn.headerHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func cell(_ title: String, _ key: ServiceSort, _ width: CGFloat?, _ align: Alignment, _ leading: CGFloat = 0,
                      minWidth: CGFloat = 0) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            if key == store.sortKey {
                Image(systemName: store.ascending ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .bold))
            }
        }
        .padding(.leading, leading).padding(.trailing, align == .trailing ? 12 : 0)
        .frame(minWidth: width ?? minWidth, maxWidth: width ?? .infinity, maxHeight: .infinity, alignment: align)
        .contentShape(Rectangle())
        .onTapGesture {
            if store.sortKey == key { store.ascending.toggle() } else { store.sortKey = key; store.ascending = key != .status }
        }
    }

    // MARK: Rows

    private func rowView(_ row: ServiceItem) -> some View {
        let selected = store.selection == row.id
        return HStack(spacing: 0) {
            Text(row.label).lineLimit(1).padding(.leading, 14)
                .frame(minWidth: ServiceColumn.nameMin, maxWidth: .infinity, alignment: .leading)
            text(row.pid.map(String.init) ?? "–", ServiceColumn.pid, .trailing, selected, secondary: true, trailingPad: 12)
            text(row.description, nil, .leading, selected, secondary: true, leadingPad: 8)
            text(row.isRunning ? "Running" : "Stopped", ServiceColumn.status, .leading, selected, leadingPad: 8)
            text(row.domain, ServiceColumn.domain, .leading, selected, secondary: true, leadingPad: 8)
        }
        .font(.system(size: 13))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(height: ServiceColumn.rowHeight)
        .background(selected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { store.selection = row.id }
    }

    private func text(_ value: String, _ width: CGFloat?, _ align: Alignment, _ selected: Bool, secondary: Bool = false,
                      leadingPad: CGFloat = 0, trailingPad: CGFloat = 0) -> some View {
        Text(value).monospacedDigit().lineLimit(1)
            .foregroundStyle(selected ? Color.white : (secondary ? Color.secondary : Color.primary))
            .padding(.leading, leadingPad).padding(.trailing, trailingPad)
            .frame(minWidth: width ?? ServiceColumn.descriptionMin, maxWidth: width ?? .infinity,
                   minHeight: ServiceColumn.rowHeight, maxHeight: ServiceColumn.rowHeight, alignment: align)
    }
}
