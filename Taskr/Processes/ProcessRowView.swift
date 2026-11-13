//
//  ProcessRowView.swift
//  Taskr
//
//  One 28-point row of the Processes list: name, status, and the heat-tinted metric cells.
//

import SwiftUI

/// Renders a single `ProcessRow`. Selection and expansion live in the store; this view only displays them.
struct ProcessRowView: View {
    let row: ProcessRow
    @Bindable var store: ProcessStore
    let onGoToDetails: (ProcessTarget) -> Void
    let onGetInfo: (ProcessTarget) -> Void
    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }
    private var selected: Bool { store.selection == row.id }

    var body: some View {
        HStack(spacing: 0) {
            nameCell
            statusCell
            if let metrics = row.metrics {
                metricCells(metrics)
            } else {
                Color.clear.frame(width: ProcessColumn.metricsWidth)
            }
        }
        .font(.system(size: 13))
        .frame(height: ProcessColumn.rowHeight)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture {
            store.selection = row.id
            if row.kind == .category { store.toggle(row.id) }
        }
        .contextMenu { contextMenuItems }
    }

    // MARK: Name and status

    private var nameCell: some View {
        HStack(spacing: 6) {
            Group {
                if row.expandable {
                    Image(systemName: row.expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                } else {
                    Color.clear
                }
            }
            .frame(width: 10)
            .contentShape(Rectangle())
            .onTapGesture { if row.expandable { store.toggle(row.id) } }

            if row.kind != .category {
                Image(nsImage: IconCache.shared.icon(for: row.iconPath))
                    .resizable().frame(width: 16, height: 16)
            }
            Text(row.title)
                .fontWeight(row.kind == .category ? .semibold : .regular)
                .foregroundStyle(row.kind == .category && !selected ? Color.accentColor : primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, row.kind == .child ? 36 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Not responding" takes priority over "Efficiency".
    private var statusCell: some View {
        HStack(spacing: 4) {
            if row.unresponsive {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9))
                    .foregroundStyle(selected ? Color.white : Color.red)
                Text("Not responding").font(.system(size: 12))
                    .foregroundStyle(selected ? Color.white : Color.red)
            } else if row.efficient {
                Image(systemName: "leaf.fill").font(.system(size: 9))
                    .foregroundStyle(selected ? Color.white : Color.green)
                Text("Efficiency").font(.system(size: 12))
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .frame(width: ProcessColumn.status)
    }

    // MARK: Metrics

    @ViewBuilder
    private func metricCells(_ m: ProcessRow.Metrics) -> some View {
        valueCell(ProcessFormat.rowPercent(m.cpu), width: ProcessColumn.cpu, tier: Heat.tier(m.cpu, Heat.cpu))
        valueCell(ProcessFormat.memory(m.memory, asPercent: store.memoryAsPercent, installed: store.physicalMemory),
                  width: ProcessColumn.memory, tier: Heat.tier(Double(m.memory) / 1e6, Heat.memoryMB))
        if AppPrefs.shared.isVisible(.disk) {
            valueCell(ProcessFormat.disk(m.disk), width: ProcessColumn.disk, tier: Heat.tier(m.disk / 1e6, Heat.diskMBps))
        }

        if !AppPrefs.shared.isVisible(.network) {
            EmptyView()
        } else if store.networkReady {
            valueCell(ProcessFormat.network(m.network), width: ProcessColumn.network,
                      tier: Heat.tier(m.network * 8 / 1e6, Heat.networkMbps))
        } else {
            valueCell("–", width: ProcessColumn.network, tier: 0, dim: true)
        }

        if !AppPrefs.shared.isVisible(.gpu) {
            EmptyView()
        } else if store.gpuReady {
            valueCell(m.gpu < 0.05 ? "0%" : ProcessFormat.rowPercent(m.gpu), width: ProcessColumn.gpu,
                      tier: Heat.tier(m.gpu, Heat.gpu), dim: m.gpu < 0.05)
        } else {
            valueCell("–", width: ProcessColumn.gpu, tier: 0, dim: true)
        }

        if AppPrefs.shared.isVisible(.energy) { energyCell(m) }
    }

    private func energyCell(_ m: ProcessRow.Metrics) -> some View {
        var text = "–"
        var level = 0
        if store.energyReady {
            level = ProcessFormat.energyLevel(watts: m.watts)
            text = ProcessFormat.energyLabels[level]
        }
        // Low levels recede; Moderate and above read as primary text, like the design.
        let color: Color = selected ? .white : (level >= 2 ? .primary : .secondary)
        return HStack { Text(text).foregroundStyle(color); Spacer() }
            .padding(.leading, 12)
            .frame(width: ProcessColumn.energy, height: ProcessColumn.rowHeight)
    }

    private func valueCell(_ text: String, width: CGFloat, tier: Int, dim: Bool = false) -> some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(selected ? Color.white : (dim ? Color.secondary : Color.primary))
            .padding(.trailing, 12)
            .frame(width: width, height: ProcessColumn.rowHeight, alignment: .trailing)
            .background(selected ? Color.clear : Heat.color(tier, dark: isDark))
    }

    // MARK: Appearance

    private var primary: Color { selected ? .white : .primary }

    private var background: Color {
        if selected { return Color.accentColor }
        if row.kind == .category { return Color.primary.opacity(0.05) }
        return .clear
    }
}
