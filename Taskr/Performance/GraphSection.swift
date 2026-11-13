//
//  GraphSection.swift
//  Taskr
//
//  A titled graph with an optional legend and a maximum-value label, as in the design.
//

import SwiftUI

/// A legend entry: a colored swatch and a label.
struct LegendItem {
    let color: Color
    let label: String
}

/// Title row (title, legend, axis maximum) above a bordered `LiveGraph`.
struct GraphSection: View {
    let title: String
    var legend: [LegendItem] = []
    let maxLabel: String
    let maxValue: Double
    let series: [GraphSeries]
    /// Fixed height in points; `nil` lets the graph fill the space it's given.
    var height: CGFloat?
    var border: Color = Color(nsColor: .separatorColor)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Text(title)
                ForEach(legend.indices, id: \.self) { index in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(legend[index].color).frame(width: 9, height: 9)
                        Text(legend[index].label).foregroundStyle(.primary.opacity(0.8))
                    }
                }
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            LiveGraph(series: series, maxValue: maxValue)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .frame(maxHeight: height == nil ? .infinity : nil)
                .background(Color(nsColor: .controlBackgroundColor))
                .overlay(Rectangle().stroke(border, lineWidth: 1))
        }
    }
}
