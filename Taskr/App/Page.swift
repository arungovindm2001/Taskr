//
//  Page.swift
//  Taskr
//
//  The pages of the app, mirroring Windows Task Manager's navigation.
//

import SwiftUI

/// The 12 pages, mirroring Windows Task Manager (Performance is split into its sub-pages).
enum Page: String, CaseIterable, Identifiable {
    case processes, cpu, memory, disk, network, gpu, appHistory, startup, users, details, services, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .processes: "Processes"
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .network: "Network"
        case .gpu: "GPU"
        case .appHistory: "App history"
        case .startup: "Startup apps"
        case .users: "Users"
        case .details: "Details"
        case .services: "Services"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .processes: "list.bullet.rectangle"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "network"
        case .gpu: "display"
        case .appHistory: "clock.arrow.circlepath"
        case .startup: "power"
        case .users: "person.2"
        case .details: "tablecells"
        case .services: "gearshape.2"
        case .settings: "gearshape"
        }
    }

    /// Sidebar section a page belongs to.
    enum Group: String, CaseIterable { case main, performance, system }
    var group: Group {
        switch self {
        case .processes: .main
        case .cpu, .memory, .disk, .network, .gpu: .performance
        default: .system
        }
    }
}
