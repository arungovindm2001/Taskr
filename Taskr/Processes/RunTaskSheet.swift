//
//  RunTaskSheet.swift
//  Taskr
//
//  The "Create new task" dialog, modelled on Windows Task Manager's Run dialog.
//

import SwiftUI
import AppKit

/// Sheet that asks for a path or command to run. Calls `onRun(text, runAsAdmin)` when confirmed.
struct RunTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var admin = false
    let onRun: (String, Bool) -> Void

    private var canRun: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 40, height: 40)
                Text("Create new task").font(.headline)
            }
            Text("Enter the path of an app, script or command and Taskr will open it for you.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Open:")
                TextField("", text: $text).textFieldStyle(.roundedBorder)
                Button("Browse…", action: browse)
            }
            Toggle("Run with administrator privileges", isOn: $admin)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("OK") { onRun(text, admin); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRun)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    /// Lets the user pick an app or file instead of typing its path.
    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsOtherFileTypes = true
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK, let url = panel.url { text = url.path }
    }
}
