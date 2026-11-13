//
//  ServicesStore.swift
//  Taskr
//
//  Owns the service list, selection, filters and the start / stop / restart actions.
//

import Foundation
import Observation

enum ServiceSort { case name, pid, description, status, domain }

/// Which services are listed.
enum ServiceDomainFilter: Hashable {
    case all, system, user
    var title: String {
        switch self {
        case .all: "All"
        case .system: "system"
        case .user: "gui/\(getuid())"
        }
    }
}

@Observable
final class ServicesStore {
    private(set) var items: [ServiceItem] = []
    private(set) var loaded = false
    var selection: String?
    var sortKey: ServiceSort = .name
    var ascending = true
    var domain: ServiceDomainFilter = .all

    var selected: ServiceItem? { items.first { $0.id == selection } }

    /// Rescans in the background; called on a timer while the page is open.
    func refresh() async {
        let found = await Task.detached { ServiceScanner.scan() }.value
        if found != items { items = found }
        loaded = true
    }

    func perform(_ action: ServiceScanner.Action) async {
        guard let service = selected else { return }
        let error = await Task.detached { ServiceScanner.perform(action, on: service) }.value
        if let error {
            let verb = switch action { case .start: "start"; case .stop: "stop"; case .restart: "restart" }
            ProcessActions.showError("Couldn’t \(verb) \(service.label)", error)
        }
        await refresh()
    }

    /// Filtered and sorted rows.
    func rows(matching query: String) -> [ServiceItem] {
        let text = query.trimmingCharacters(in: .whitespaces)
        var list = items.filter {
            switch domain {
            case .all: true
            case .system: $0.isSystem
            case .user: !$0.isSystem
            }
        }
        if !text.isEmpty {
            list = list.filter {
                $0.label.localizedCaseInsensitiveContains(text) || $0.description.localizedCaseInsensitiveContains(text)
                    || ($0.pid.map { String($0) == text } ?? false)
            }
        }
        let order: (ServiceItem, ServiceItem) -> Bool = { a, b in
            switch self.sortKey {
            case .name: a.label.localizedStandardCompare(b.label) == .orderedAscending
            case .pid: (a.pid ?? -1) < (b.pid ?? -1)
            case .description: a.description.localizedStandardCompare(b.description) == .orderedAscending
            case .status: a.isRunning && !b.isRunning
            case .domain: a.domain < b.domain
            }
        }
        return list.sorted { ascending ? order($0, $1) : order($1, $0) }
    }
}
