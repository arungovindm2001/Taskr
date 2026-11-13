//
//  ProcessTableHeader.swift
//  Taskr
//
//  The 56-point column header: whole-machine totals above each column name, tinted by load.
//

import SwiftUI

/// Column header for the Processes list. Tapping a sortable column changes `store.sortKey`.
struct ProcessTableHeader: View {
    let store: ProcessStore
    let totals: HeaderTotals
    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }

    /// Whole-GPU utilization; falls back to the per-process sum when the driver doesn't report it.
    private var gpuTotal: Double {
        store.gpuDevice ?? min(100, store.gpuPct.values.reduce(0, +))
    }

    var body: some View {
        HStack(spacing: 0) {
            cell("Name", total: nil, key: .name, width: nil, align: .leading, tier: 0, leading: 16)
            cell("Status", total: nil, key: nil, width: ProcessColumn.status, align: .leading, tier: 0, leading: 8)
            cell("CPU", total: ProcessFormat.percent(totals.cpu), key: .cpu, width: ProcessColumn.cpu, align: .trailing,
                 tier: Heat.tier(totals.cpu, Heat.cpuTotal))
            cell("Memory", total: ProcessFormat.percent(totals.memoryPercent), key: .memory, width: ProcessColumn.memory,
                 align: .trailing, tier: Heat.tier(totals.memoryPercent, Heat.memoryTotalPct))
            cell("Disk", total: ProcessFormat.disk(totals.disk), key: .disk, width: ProcessColumn.disk, align: .trailing,
                 tier: Heat.tier(totals.disk / 1e6, Heat.diskTotalMBps))
            cell("Network", total: totals.network.map { ProcessFormat.network($0) } ?? "–", key: .network,
                 width: ProcessColumn.network, align: .trailing,
                 tier: totals.network.map { Heat.tier($0 * 8 / 1e6, Heat.networkTotalMbps) } ?? 0)
            cell("GPU", total: store.gpuReady ? ProcessFormat.percent(gpuTotal) : "–", key: .gpu,
                 width: ProcessColumn.gpu, align: .trailing,
                 tier: store.gpuReady ? Heat.tier(gpuTotal, Heat.gpuTotal) : 0)
            cell("Energy impact", total: nil, key: .energy, width: ProcessColumn.energy, align: .leading, tier: 0, leading: 8)
        }
        .frame(height: ProcessColumn.headerHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// One header cell: optional total on top, column title (with a sort chevron when active) below.
    private func cell(_ title: String, total: String?, key: SortKey?, width: CGFloat?, align: Alignment,
                      tier: Int, leading: CGFloat = 0) -> some View {
        let trailing = align == .trailing
        return VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            if let total {
                Text(total).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(total == "–" ? Color.secondary : Color.primary)
            }
            HStack(spacing: 4) {
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                if let key, key == store.sortKey {
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
            }
        }
        .padding(.leading, leading)
        .padding(.trailing, trailing ? 12 : 0)
        .padding(.bottom, total == nil ? 0 : 6)
        .frame(minWidth: width ?? 0, maxWidth: width ?? .infinity,
               minHeight: ProcessColumn.headerHeight, maxHeight: ProcessColumn.headerHeight,
               alignment: Self.alignment(trailing: trailing, hasTotal: total != nil))
        .background(Heat.color(tier, dark: isDark))
        .contentShape(Rectangle())
        .onTapGesture { if let key { store.sortKey = key } }
    }

    private static func alignment(trailing: Bool, hasTotal: Bool) -> Alignment {
        switch (trailing, hasTotal) {
        case (true, true): .bottomTrailing
        case (true, false): .trailing
        case (false, true): .bottomLeading
        case (false, false): .leading
        }
    }
}
