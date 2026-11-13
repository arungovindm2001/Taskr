//
//  MetricHistory.swift
//  Taskr
//
//  A fixed-length rolling window of readings, one per second.
//

import Foundation

/// The last 60 readings of one metric, oldest first.
struct MetricHistory {
    /// Seconds of history kept (one reading per second).
    static let capacity = 60

    private(set) var values: [Double] = []

    /// The most recent reading.
    var last: Double? { values.last }

    /// The largest reading in the window, or 0 when empty.
    var peak: Double { values.max() ?? 0 }

    /// Adds a reading, dropping the oldest once the window is full.
    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > Self.capacity { values.removeFirst(values.count - Self.capacity) }
    }
}
