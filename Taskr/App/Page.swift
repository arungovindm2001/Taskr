//
//  Page.swift
//  Taskr
//
//  The pages of the app, mirroring Windows Task Manager's navigation.
//

import SwiftUI

/// The pages, mirroring Windows Task Manager's tabs (Performance holds CPU, Memory, Disk, Network and GPU).
enum Page: String, CaseIterable, Identifiable {
    case processes, performance, appHistory, startup, users, details, services, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .processes: "Processes"
        case .performance: "Performance"
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
        case .performance: "chart.line.uptrend.xyaxis"
        case .appHistory: "clock.arrow.circlepath"
        case .startup: "power"
        case .users: "person.2"
        case .details: "tablecells"
        case .services: "gearshape.2"
        case .settings: "gearshape"
        }
    }
}
