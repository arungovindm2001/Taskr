//
//  PerformanceDevice.swift
//  Taskr
//
//  The five things the Performance page can show, and the colors of their graphs.
//

import SwiftUI

/// A device in the Performance page's list.
enum PerformanceDevice: String, CaseIterable, Identifiable {
    case cpu, memory, disk, network, gpu

    var id: String { rawValue }

    /// Accent color for the device's card and main graph.
    var tint: Color {
        switch self {
        case .cpu: GraphPalette.cpuLine
        case .memory: GraphPalette.memoryFill
        case .disk: GraphPalette.readFill
        case .network: GraphPalette.receiveFill
        case .gpu: GraphPalette.gpuFill
        }
    }
}

/// Graph colors from the design. Each series has a stroke ("line") and a lighter area fill.
enum GraphPalette {
    static let cpuLine = Color(hex: 0x0a5fd8), cpuFill = Color(hex: 0x0a84ff)
    static let systemLine = Color(hex: 0xc4313b), systemFill = Color(hex: 0xe5484d)
    static let memoryLine = Color(hex: 0x6b34b8), memoryFill = Color(hex: 0x8a4fd1)
    static let readLine = Color(hex: 0x176b32), readFill = Color(hex: 0x1d8a3f)
    static let writeLine = Color(hex: 0xb86a1a), writeFill = Color(hex: 0xd9822b)
    static let receiveLine = Color(hex: 0x8a4a00), receiveFill = Color(hex: 0xa85a00)
    static let sendLine = Color(hex: 0xb87a1f), sendFill = Color(hex: 0xe0a14a)
    static let gpuLine = Color(hex: 0x0a6068), gpuFill = Color(hex: 0x0e7f8a)
}
