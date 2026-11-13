//
//  DetailsPage.swift
//  Taskr
//
//  The Details page: every process as one flat row, like Windows Task Manager's Details tab.
//

import SwiftUI
import TaskrCore

private enum DetailColumn {
    static let pid: CGFloat = 70
    static let status: CGFloat = 90
    static let user: CGFloat = 110
    static let cpu: CGFloat = 70
    static let memory: CGFloat = 90
    static let arch: CGFloat = 100
    static let nameMin: CGFloat = 180
    static let descriptionMin: CGFloat = 120
    static let rowHeight: CGFloat = 24
    static let headerHeight: CGFloat = 28
}

/// One process with everything the Details table shows.
private struct DetailRow: Identifiable {
    let process: ProcessSnapshot
    let category: ProcessCategory
    let groupName: String
    let iconPath: String?
    let userName: String
    let status: String
    var id: Int32 { process.pid }
    var description: String {
        switch category {
        case .apps: groupName
        case .macOS: "macOS process"
        case .background: "Background process"
        }
    }
}

private enum DetailSort { case name, pid, status, user, cpu, memory, arch }

/// Flat list of all processes with PID, status, owner, CPU, memory and architecture.
struct DetailsPage: View {
    let store: ProcessStore
    /// A pid to select when arriving from "Go to Details".
    @Binding var focusPid: Int32?
    @State private var query = ""
    @State private var selection: Int32?
    @State private var sort: DetailSort = .cpu
    @State private var ascending = false

    var body: some View {
        let rows = visibleRows()
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in rowView(row) }
                    }
                }
                .onChange(of: focusPid) { _, pid in
                    guard let pid else { return }
                    selection = pid
                    query = ""
                    proxy.scrollTo(pid, anchor: .center)
                    focusPid = nil
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Details")
        .navigationSubtitle("\(rows.count) processes")
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup {
                let target = selectedTarget()
                Button { if let target { ProcessActions.confirmEnd(target) } } label: {
                    Label { Text("End task") } icon: { Image(systemName: "xmark.octagon").foregroundStyle(.red) }
                }
                .disabled(target == nil)
                Button { if let target { store.toggleEfficiency(target) } } label: {
                    Label { Text("Efficiency mode") } icon: { Image(systemName: "leaf").foregroundStyle(.green) }
                }
                .disabled(target == nil)
            }
        }
        .onAppear {
            if let pid = focusPid { selection = pid; focusPid = nil }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            cell("Name", .name, nil, .leading, 16, minWidth: DetailColumn.nameMin)
            cell("PID", .pid, DetailColumn.pid, .trailing)
            cell("Status", .status, DetailColumn.status, .leading, 8)
            cell("User name", .user, DetailColumn.user, .leading, 8)
            cell("CPU", .cpu, DetailColumn.cpu, .trailing)
            cell("Memory", .memory, DetailColumn.memory, .trailing)
            cell("Architecture", .arch, DetailColumn.arch, .leading, 8)
            cell("Description", nil, nil, .leading, 8, minWidth: DetailColumn.descriptionMin)
        }
        .frame(height: DetailColumn.headerHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func cell(_ title: String, _ key: DetailSort?, _ width: CGFloat?, _ align: Alignment, _ leading: CGFloat = 0,
                      minWidth: CGFloat = 0) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            if let key, key == sort {
                Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .bold))
            }
        }
        .padding(.leading, leading).padding(.trailing, align == .trailing ? 12 : 0)
        .frame(minWidth: width ?? minWidth, maxWidth: width ?? .infinity, maxHeight: .infinity, alignment: align)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let key else { return }
            if sort == key { ascending.toggle() } else { sort = key; ascending = (key == .name || key == .user || key == .status || key == .arch) }
        }
    }

    // MARK: Rows

    private func rowView(_ row: DetailRow) -> some View {
        let selected = selection == row.id
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(nsImage: IconCache.shared.icon(for: row.iconPath)).resizable().frame(width: 16, height: 16)
                Text(row.process.name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 14).frame(minWidth: DetailColumn.nameMin, maxWidth: .infinity, alignment: .leading)
            text(String(row.process.pid), DetailColumn.pid, .trailing, selected, secondary: true, trailingPad: 12)
            text(row.status, DetailColumn.status, .leading, selected, leadingPad: 8)
            text(row.userName, DetailColumn.user, .leading, selected, leadingPad: 8)
            text(ProcessFormat.rowPercent(row.process.cpuPercent), DetailColumn.cpu, .trailing, selected, trailingPad: 12,
                 heat: Heat.tier(row.process.cpuPercent, Heat.cpu))
            text(ProcessFormat.memory(row.process.memoryBytes, asPercent: false, installed: store.physicalMemory),
                 DetailColumn.memory, .trailing, selected, trailingPad: 12,
                 heat: Heat.tier(Double(row.process.memoryBytes) / 1e6, Heat.memoryMB))
            text(ProcessArchitecture.label(for: row.process.pid), DetailColumn.arch, .leading, selected, secondary: true, leadingPad: 8)
            text(row.description, nil, .leading, selected, secondary: true, leadingPad: 8)
        }
        .font(.system(size: 13))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(height: DetailColumn.rowHeight)
        .background(selected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selection = row.id }
        .id(row.id)
    }

    @Environment(\.colorScheme) private var scheme

    private func text(_ value: String, _ width: CGFloat?, _ align: Alignment, _ selected: Bool, secondary: Bool = false,
                      leadingPad: CGFloat = 0, trailingPad: CGFloat = 0, heat: Int = 0) -> some View {
        Text(value).monospacedDigit().lineLimit(1)
            .foregroundStyle(selected ? Color.white : (secondary ? Color.secondary : Color.primary))
            .padding(.leading, leadingPad).padding(.trailing, trailingPad)
            .frame(minWidth: width ?? DetailColumn.descriptionMin, maxWidth: width ?? .infinity, minHeight: DetailColumn.rowHeight,
                   maxHeight: DetailColumn.rowHeight, alignment: align)
            .background(selected ? Color.clear : Heat.color(heat, dark: scheme == .dark))
    }

    // MARK: Data

    private func visibleRows() -> [DetailRow] {
        var rows: [DetailRow] = []
        for group in store.groups {
            for process in group.processes {
                let uid = ProcessOwners.uid(for: process.pid)
                rows.append(DetailRow(process: process, category: group.category, groupName: group.name, iconPath: group.iconPath,
                                      userName: Self.userName(uid),
                                      status: store.unresponsive.contains(process.pid) ? "Not responding"
                                          : store.efficiency.contains(process.pid) ? "Efficiency" : "Running"))
            }
        }
        let text = query.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            rows = rows.filter {
                $0.process.name.localizedCaseInsensitiveContains(text) || String($0.process.pid) == text
                    || $0.userName.localizedCaseInsensitiveContains(text)
            }
        }
        let order: (DetailRow, DetailRow) -> Bool = { a, b in
            switch sort {
            case .name: return a.process.name.localizedStandardCompare(b.process.name) == .orderedAscending
            case .pid: return a.process.pid < b.process.pid
            case .status: return a.status < b.status
            case .user: return a.userName < b.userName
            case .cpu: return a.process.cpuPercent < b.process.cpuPercent
            case .memory: return a.process.memoryBytes < b.process.memoryBytes
            case .arch: return ProcessArchitecture.label(for: a.process.pid) < ProcessArchitecture.label(for: b.process.pid)
            }
        }
        return rows.sorted { ascending ? order($0, $1) : order($1, $0) }
    }

    private static var userNames: [uid_t: String] = [:]
    private static func userName(_ uid: uid_t) -> String {
        if let hit = userNames[uid] { return hit }
        let name = getpwuid(uid).map { String(cString: $0.pointee.pw_name) } ?? "uid \(uid)"
        userNames[uid] = name
        return name
    }

    private func selectedTarget() -> ProcessTarget? {
        guard let selection else { return nil }
        return store.target(for: "pid:\(selection)")
    }
}
