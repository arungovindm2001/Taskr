//
//  ProcessColumn.swift
//  Taskr
//
//  Fixed column widths shared by the list header and its rows so they stay aligned.
//

import SwiftUI

/// Column geometry for the Processes table. The Name column takes the remaining width.
enum ProcessColumn {
    static let status: CGFloat = 124
    static let cpu: CGFloat = 70
    static let memory: CGFloat = 84
    static let disk: CGFloat = 96
    static let network: CGFloat = 96
    static let gpu: CGFloat = 60
    static let energy: CGFloat = 96
    static let rowHeight: CGFloat = 28
    static let headerHeight: CGFloat = 56

    /// Combined width of the metric columns (CPU through Energy), used to pad section-header rows.
    static let metricsWidth = cpu + memory + disk + network + gpu + energy
}
