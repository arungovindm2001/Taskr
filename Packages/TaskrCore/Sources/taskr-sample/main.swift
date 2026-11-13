//
//  main.swift
//  taskr-sample
//
//  Headless harness for TaskrCore: a live top-15 process list in the terminal.
//  Run with `swift run taskr-sample` from the TaskrCore directory.
//

import Foundation
import TaskrCore

/// Truncates or pads `text` to exactly `width` characters.
func pad(_ text: String, _ width: Int, right: Bool = false) -> String {
    let trimmed = String(text.prefix(width))
    let fill = String(repeating: " ", count: width - trimmed.count)
    return right ? fill + trimmed : trimmed + fill
}

let sampler = ProcessSampler()
_ = await sampler.sample()   // prime the deltas

while true {
    try? await Task.sleep(for: .seconds(1))
    let rows = await sampler.sample().sorted { $0.cpuPercent > $1.cpuPercent }.prefix(15)

    print("\u{1B}[2J\u{1B}[H", terminator: "")   // clear screen, cursor to top-left
    print(pad("PID", 7) + pad("NAME", 30) + pad("CPU", 8, right: true)
          + pad("MEMORY", 12, right: true) + pad("DISK", 14, right: true))
    for process in rows {
        print(pad("\(process.pid)", 7) + pad(process.name, 30)
              + pad(String(format: "%.1f%%", process.cpuPercent), 8, right: true)
              + pad(Format.bytes(process.memoryBytes), 12, right: true)
              + pad(Format.rate(process.diskBytesPerSec), 14, right: true))
    }
}
