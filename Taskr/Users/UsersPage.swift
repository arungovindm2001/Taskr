//
//  UsersPage.swift
//  Taskr
//
//  The Users page: each account and its running apps with CPU, memory, disk and network use.
//

import SwiftUI
import TaskrCore

/// Column geometry for the Users table. The User column takes the remaining width.
private enum UserColumn {
    static let status: CGFloat = 130
    static let cpu: CGFloat = 90
    static let memory: CGFloat = 100
    static let disk: CGFloat = 110
    static let network: CGFloat = 110
    static let rowHeight: CGFloat = 28
    static let headerHeight: CGFloat = 56
}

/// Accounts with processes running, grouped like Windows Task Manager's Users tab.
struct UsersPage: View {
    let store: ProcessStore
    @State private var query = ""
    @State private var expanded: Set<uid_t> = [UserEntry.consoleUID()]
    @State private var selection: String?
    @State private var sortKey: SortKey = .cpu
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let users = UserEntry.build(from: store.groups)
        let totals = store.headerTotals

        VStack(spacing: 0) {
            header(totals)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(users) { user in
                        userRow(user)
                        if isOpen(user) {
                            ForEach(visibleGroups(of: user)) { group in groupRow(group, of: user) }
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Users")
        .navigationSubtitle("\(users.count) \(users.count == 1 ? "user" : "users")")
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup {
                let target = selectedTarget(in: users)
                Button { if let target { ProcessActions.confirmEnd(target) } } label: {
                    Label { Text("End task") } icon: { Image(systemName: "xmark.octagon").foregroundStyle(.red) }
                }
                .disabled(target == nil)
                Button { UserSwitching.switchUser() } label: { Label("Switch user…", systemImage: "person.2.circle") }
            }
        }
    }

    // MARK: Header

    private func header(_ totals: HeaderTotals) -> some View {
        HStack(spacing: 0) {
            headerCell("User", total: nil, key: nil, width: nil, align: .leading, tier: 0, leading: 16)
            headerCell("Status", total: nil, key: nil, width: UserColumn.status, align: .leading, tier: 0, leading: 8)
            headerCell("CPU", total: ProcessFormat.percent(totals.cpu), key: .cpu, width: UserColumn.cpu, align: .trailing,
                       tier: Heat.tier(totals.cpu, Heat.cpuTotal))
            headerCell("Memory", total: ProcessFormat.percent(totals.memoryPercent), key: .memory, width: UserColumn.memory,
                       align: .trailing, tier: Heat.tier(totals.memoryPercent, Heat.memoryTotalPct))
            headerCell("Disk", total: ProcessFormat.disk(totals.disk), key: .disk, width: UserColumn.disk, align: .trailing,
                       tier: Heat.tier(totals.disk / 1e6, Heat.diskTotalMBps))
            headerCell("Network", total: totals.network.map { ProcessFormat.network($0) } ?? "–", key: .network,
                       width: UserColumn.network, align: .trailing,
                       tier: totals.network.map { Heat.tier($0 * 8 / 1e6, Heat.networkTotalMbps) } ?? 0)
        }
        .frame(height: UserColumn.headerHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func headerCell(_ title: String, total: String?, key: SortKey?, width: CGFloat?, align: Alignment,
                            tier: Int, leading: CGFloat = 0) -> some View {
        let trailing = align == .trailing
        return VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            if let total {
                Text(total).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(total == "–" ? Color.secondary : Color.primary)
            }
            HStack(spacing: 4) {
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                if let key, key == sortKey { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
            }
        }
        .padding(.leading, leading)
        .padding(.trailing, trailing ? 12 : 0)
        .padding(.bottom, total == nil ? 0 : 6)
        .frame(minWidth: width ?? 0, maxWidth: width ?? .infinity,
               minHeight: UserColumn.headerHeight, maxHeight: UserColumn.headerHeight,
               alignment: trailing ? (total == nil ? .trailing : .bottomTrailing) : (total == nil ? .leading : .bottomLeading))
        .background(Heat.color(tier, dark: scheme == .dark))
        .contentShape(Rectangle())
        .onTapGesture { if let key { sortKey = key } }
    }

    // MARK: Rows

    private func userRow(_ user: UserEntry) -> some View {
        let id = "user:\(user.id)"
        let selected = selection == id
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: isOpen(user) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(selected ? Color.white : Color.secondary)
                    .frame(width: 10)
                Text("\(user.name) (\(user.processCount) processes)").fontWeight(.semibold).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(user.status).foregroundStyle(selected ? Color.white.opacity(0.85) : Color.secondary)
                .padding(.leading, 8).frame(width: UserColumn.status, alignment: .leading)
            metricCells(cpu: user.cpu, memory: user.memory, disk: user.disk,
                        network: store.network(user.groups.flatMap { $0.processes.map(\.pid) }), selected: selected)
        }
        .font(.system(size: 13))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(height: UserColumn.rowHeight)
        .background(selected ? Color.accentColor : Color.primary.opacity(0.05))
        .contentShape(Rectangle())
        .onTapGesture {
            selection = id
            if expanded.contains(user.id) { expanded.remove(user.id) } else { expanded.insert(user.id) }
        }
    }

    private func groupRow(_ group: ProcessGroup, of user: UserEntry) -> some View {
        let id = rowID(group, user)
        let selected = selection == id
        let count = group.processes.count
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(nsImage: IconCache.shared.icon(for: group.iconPath)).resizable().frame(width: 16, height: 16)
                Text(count > 1 ? "\(group.name) (\(count))" : group.name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 36)
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: UserColumn.status)
            metricCells(cpu: group.cpu, memory: group.memory, disk: group.disk,
                        network: store.network(group.processes.map(\.pid)), selected: selected)
        }
        .font(.system(size: 13))
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(height: UserColumn.rowHeight)
        .background(selected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selection = id }
    }

    @ViewBuilder
    private func metricCells(cpu: Double, memory: UInt64, disk: Double, network: Double, selected: Bool) -> some View {
        valueCell(ProcessFormat.rowPercent(cpu), UserColumn.cpu, Heat.tier(cpu, Heat.cpu), selected)
        valueCell(ProcessFormat.memory(memory, asPercent: false, installed: store.physicalMemory), UserColumn.memory,
                  Heat.tier(Double(memory) / 1e6, Heat.memoryMB), selected)
        valueCell(ProcessFormat.disk(disk), UserColumn.disk, Heat.tier(disk / 1e6, Heat.diskMBps), selected)
        if store.networkReady {
            valueCell(ProcessFormat.network(network), UserColumn.network, Heat.tier(network * 8 / 1e6, Heat.networkMbps), selected)
        } else {
            valueCell("–", UserColumn.network, 0, selected, dim: true)
        }
    }

    private func valueCell(_ text: String, _ width: CGFloat, _ tier: Int, _ selected: Bool, dim: Bool = false) -> some View {
        Text(text).monospacedDigit()
            .foregroundStyle(selected ? Color.white : (dim ? Color.secondary : Color.primary))
            .padding(.trailing, 12)
            .frame(width: width, height: UserColumn.rowHeight, alignment: .trailing)
            .background(selected ? Color.clear : Heat.color(tier, dark: scheme == .dark))
    }

    // MARK: Helpers

    /// A user's groups, filtered by the search text and sorted by the active column.
    private func visibleGroups(of user: UserEntry) -> [ProcessGroup] {
        let text = query.trimmingCharacters(in: .whitespaces)
        let groups = user.groups.filter { text.isEmpty || $0.name.localizedCaseInsensitiveContains(text) }
        switch sortKey {
        case .name: return groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .memory: return groups.sorted { $0.memory > $1.memory }
        case .disk: return groups.sorted { $0.disk > $1.disk }
        case .network: return groups.sorted { store.network($0.processes.map(\.pid)) > store.network($1.processes.map(\.pid)) }
        default: return groups.sorted { $0.cpu > $1.cpu }
        }
    }

    private func isOpen(_ user: UserEntry) -> Bool { !query.isEmpty || expanded.contains(user.id) }

    private func rowID(_ group: ProcessGroup, _ user: UserEntry) -> String { "group:\(user.id):\(group.id)" }

    /// The app row that's selected, as something End task can act on. User rows can't be ended.
    private func selectedTarget(in users: [UserEntry]) -> ProcessTarget? {
        guard let selection else { return nil }
        for user in users {
            for group in user.groups where rowID(group, user) == selection {
                let main = group.processes.max { $0.memoryBytes < $1.memoryBytes }?.pid
                return ProcessTarget(title: group.name, pids: group.processes.map(\.pid),
                                     appBundlePath: group.category == .apps ? group.id : nil,
                                     revealPath: group.iconPath, primaryPid: main)
            }
        }
        return nil
    }
}
