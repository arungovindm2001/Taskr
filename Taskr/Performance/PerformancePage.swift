//
//  PerformancePage.swift
//  Taskr
//
//  The Performance page: a list of devices on the left, the selected device's detail on the right.
//

import SwiftUI

/// Mirrors Windows Task Manager's Performance tab: CPU, Memory, Disk, network and GPU, each with a live graph.
struct PerformancePage: View {
    let store: PerformanceStore
    @State private var selected: PerformanceDevice = .cpu

    /// The selected device, or the CPU if it's gone (an external disk was unplugged).
    private var current: PerformanceDevice { store.devices.contains(selected) ? selected : .cpu }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.devices) { device in
                        DeviceCard(device: device, summary: store.summary(for: device),
                                   selected: current == device) { selected = device }
                    }
                }
            }
            .scrollIndicators(.never)
            .frame(width: 244)

            detail
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Performance")
    }

    @ViewBuilder
    private var detail: some View {
        switch current {
        case .cpu: CPUDetail(store: store)
        case .memory: MemoryDetail(store: store)
        case .disk(let id): DiskDetail(store: store, diskID: id)
        case .network: NetworkDetail(store: store)
        case .gpu: GPUDetail(store: store)
        }
    }
}
