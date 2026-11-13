//
//  PerformanceDetail.swift
//  Taskr
//
//  The detail panel layout shared by all five devices: heading, graphs, big numbers, and a facts list.
//

import SwiftUI

/// A large number with a caption, e.g. "Utilization 34%".
struct PerformanceStat: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

/// A label / value line in the facts list, e.g. "Cores  8".
struct PerformanceFact: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

/// The white card on the right of the Performance page.
struct PerformanceDetail<Graphs: View>: View {
    let title: String
    let subtitle: String
    let stats: [PerformanceStat]
    let facts: [PerformanceFact]
    private let graphs: Graphs

    init(title: String, subtitle: String, stats: [PerformanceStat], facts: [PerformanceFact],
         @ViewBuilder graphs: () -> Graphs) {
        self.title = title
        self.subtitle = subtitle
        self.stats = stats
        self.facts = facts
        self.graphs = graphs()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).font(.system(size: 24, weight: .semibold))
                Spacer()
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }

            graphs

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 24) {
                statGrid.frame(maxWidth: .infinity, alignment: .topLeading)
                factList.frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor)))
    }

    private var statGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: 3),
                  alignment: .leading, spacing: 12) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 0) {
                    Text(stat.label).font(.system(size: 12)).foregroundStyle(.secondary)
                    Text(stat.value).font(.system(size: 22, weight: .semibold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var factList: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
            ForEach(facts) { fact in
                GridRow {
                    Text(fact.label).foregroundStyle(.secondary)
                    Text(fact.value).fontWeight(.medium).textSelection(.enabled)
                }
            }
        }
        .font(.system(size: 12))
    }
}
