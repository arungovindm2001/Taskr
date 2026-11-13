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

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 6) {
                ForEach(PerformanceDevice.allCases) { device in
                    DeviceCard(device: device, summary: store.summary(for: device),
                               selected: selected == device) { selected = device }
                }
                Spacer(minLength: 0)
            }
            .frame(width: 244)

            detail
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Performance")
    }

    @ViewBuilder
    private var detail: some View {
        switch selected {
        case .cpu: CPUDetail(store: store)
        case .memory: MemoryDetail(store: store)
        case .disk: DiskDetail(store: store)
        case .network: NetworkDetail(store: store)
        case .gpu: GPUDetail(store: store)
        }
    }
}
