//
//  SettingsPage.swift
//  Taskr
//
//  The Settings page.
//

import SwiftUI

/// Preferences, saved as you change them.
struct SettingsPage: View {
    let history: AppHistoryStore
    @State private var prefs = AppPrefs.shared
    @State private var showColumns = false

    var body: some View {
        Form {
            Section("Default start page") {
                Picker("Open Taskr to", selection: $prefs.startPage) {
                    ForEach(Page.allCases.filter { $0 != .settings }) { Text($0.title).tag($0) }
                }
            }

            Section("Window management") {
                Toggle("Float above other windows", isOn: $prefs.floatAbove)
                Toggle("Show Taskr in the Dock", isOn: $prefs.showInDock)
                Toggle("Keep running in the menu bar when the window is closed",
                       isOn: Binding(get: { prefs.menuBarVisible }, set: { prefs.keepInMenuBar = $0 }))
                    .disabled(!prefs.showInDock)
            }

            Section("Real-time update speed") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Refresh interval")
                        Spacer()
                        Picker("Refresh interval", selection: $prefs.refresh) {
                            ForEach(RefreshSpeed.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 280)
                    }
                    Text("Normal samples once per second. High samples twice a second, Low every four seconds, and Paused stops sampling (App history stops recording too).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $prefs.theme) {
                    ForEach(ThemeChoice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Other options") {
                Toggle("Show full user names", isOn: $prefs.fullUserNames)
                Toggle("Show history for all processes", isOn: Binding(
                    get: { prefs.historyAllProcesses },
                    set: { prefs.historyAllProcesses = $0; history.scope = $0 ? .all : .apps }))
                Toggle("Confirm before ending a task", isOn: $prefs.confirmEnd)
                LabeledContent("Optional columns") {
                    Button("Choose…") { showColumns = true }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showColumns) { ColumnChooser(prefs: prefs) }
    }
}

/// Which optional Processes columns are shown.
private struct ColumnChooser: View {
    let prefs: AppPrefs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optional columns").font(.headline)
            Text("Choose the columns shown on the Processes page. Name, Status, CPU and Memory always show.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(OptionalColumn.allCases) { column in
                Toggle(column.title, isOn: Binding(get: { prefs.isVisible(column) }, set: { prefs.setVisible(column, $0) }))
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(20).frame(width: 340)
    }
}
