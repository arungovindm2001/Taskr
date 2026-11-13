//
//  ProcessInfoSheet.swift
//  Taskr
//
//  The "Get Info" sheet: static facts about a process or app (bundle ID, version, path, pids).
//

import SwiftUI
import AppKit

/// "Get Info" for a process or app group.
struct ProcessInfoSheet: View {
    let target: ProcessTarget
    @Environment(\.dismiss) private var dismiss

    /// The app bundle behind the target, if any (found from the bundle path or the executable path).
    private var bundle: Bundle? {
        let source = target.appBundlePath ?? target.revealPath
        return source.flatMap { ProcessGrouping.bundlePath($0 + "/") }.flatMap { Bundle(path: $0) }
    }

    /// Label / value pairs shown in the sheet.
    private var rows: [(String, String)] {
        var r: [(String, String)] = []
        r.append(("Kind", target.appBundlePath != nil ? "Application" : "Process"))
        if let id = bundle?.bundleIdentifier { r.append(("Bundle ID", id)) }
        if let v = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String { r.append(("Version", v)) }
        if let p = target.revealPath, !p.isEmpty { r.append(("Path", p)) }
        r.append((target.pids.count == 1 ? "PID" : "PIDs (\(target.pids.count))",
                  target.pids.sorted().prefix(12).map(String.init).joined(separator: ", ")
                  + (target.pids.count > 12 ? " …" : "")))
        return r
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: IconCache.shared.icon(for: target.revealPath))
                    .resizable().frame(width: 48, height: 48)
                Text(target.title).font(.title2.weight(.semibold)).lineLimit(2)
            }
            Divider()
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(rows, id: \.0) { row in
                    GridRow {
                        Text(row.0).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Text(row.1).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
