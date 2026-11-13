//
//  DeviceCard.swift
//  Taskr
//
//  One entry in the Performance page's device list: a mini graph, a name and a one-line summary.
//

import SwiftUI

/// A selectable card showing a device's mini graph and headline reading.
struct DeviceCard: View {
    let device: PerformanceDevice
    let summary: DeviceSummary
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LiveGraph(series: [GraphSeries(values: summary.values, line: device.tint,
                                               fill: device.tint, fillOpacity: 0.2)],
                          maxValue: summary.maxValue, showGrid: false, lineWidth: 1.2)
                    .frame(width: 56, height: 36)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(Rectangle().stroke(device.tint, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 0) {
                    Text(summary.name).fontWeight(.medium).lineLimit(1)
                    Text(summary.subtitle)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 62)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? device.tint.opacity(0.12) : Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? device.tint.opacity(0.4) : Color(nsColor: .separatorColor)))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
