//
//  NetworkDetail.swift
//  Taskr
//
//  The Network page: throughput graph and the primary adapter's addresses and Wi-Fi details.
//

import SwiftUI

/// Network detail panel.
struct NetworkDetail: View {
    let store: PerformanceStore

    var body: some View {
        let peak = max(store.netIn.peak, store.netOut.peak)
        let top = PerformanceFormat.niceMax(peak, floor: 100_000)
        PerformanceDetail(title: store.networkTitle,
                          subtitle: store.network?.standard ?? store.network?.connectionType ?? "No connection",
                          stats: stats, facts: facts) {
            GraphSection(title: "Throughput",
                         legend: [LegendItem(color: GraphPalette.receiveFill, label: "Receive"),
                                  LegendItem(color: GraphPalette.sendFill, label: "Send")],
                         maxLabel: PerformanceFormat.rate(top), maxValue: top,
                         series: [GraphSeries(values: store.netIn.values, line: GraphPalette.receiveLine,
                                              fill: GraphPalette.receiveFill, fillOpacity: 0.22),
                                  GraphSeries(values: store.netOut.values, line: GraphPalette.sendLine,
                                              fill: GraphPalette.sendFill, fillOpacity: 0.2)],
                         height: 300, border: GraphPalette.receiveFill)
        }
    }

    private var stats: [PerformanceStat] {
        [PerformanceStat(label: "Send", value: PerformanceFormat.rate(store.latest?.netOut ?? 0)),
         PerformanceStat(label: "Receive", value: PerformanceFormat.rate(store.latest?.netIn ?? 0))]
    }

    private var facts: [PerformanceFact] {
        guard let network = store.network else { return [PerformanceFact(label: "Status", value: "Not connected")] }
        var facts = [PerformanceFact(label: "Adapter name", value: network.interface),
                     PerformanceFact(label: "Network name", value: network.networkName ?? "–"),
                     PerformanceFact(label: "Connection type", value: network.connectionType),
                     PerformanceFact(label: "IPv4 address", value: network.ipv4 ?? "–"),
                     PerformanceFact(label: "IPv6 address", value: network.ipv6 ?? "–")]
        if let signal = network.signal { facts.append(PerformanceFact(label: "Signal strength", value: "\(signal) dBm")) }
        return facts
    }
}
