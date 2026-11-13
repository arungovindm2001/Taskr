//
//  NetworkSampler.swift
//  Taskr
//
//  Per-process network throughput from a long-lived `nettop` child process.
//

import Foundation

/// Per-process network throughput, read from one long-lived `nettop` process.
///
/// `nettop -P -d -L 0 -s 1` prints one CSV block per second with the bytes each process moved
/// during that second. We parse the stream on a background thread and keep the latest block.
nonisolated final class NetworkSampler: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var pending = ""
    private var building: [Int32: Double] = [:]   // bytes (in + out) in the block being read
    private var latest: [Int32: Double] = [:]     // last complete block
    private var blocksSeen = 0

    func start() {
        lock.lock(); defer { lock.unlock() }
        guard process == nil else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        p.arguments = ["-P", "-d", "-L", "0", "-s", "1", "-n", "-x", "-J", "bytes_in,bytes_out"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            self?.consume(String(decoding: data, as: UTF8.self))
        }
        do {
            try p.run()
            process = p
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
        }
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        process?.terminate()
        process = nil
        pending = ""; building = [:]; latest = [:]; blocksSeen = 0
    }

    /// True once at least one complete, non-baseline sample has arrived.
    var hasData: Bool {
        lock.lock(); defer { lock.unlock() }
        return blocksSeen >= 3
    }

    /// Bytes per second by pid, from the most recent sample.
    func rates() -> [Int32: Double] {
        lock.lock(); defer { lock.unlock() }
        return latest
    }

    // MARK: Parsing

    private func consume(_ chunk: String) {
        lock.lock(); defer { lock.unlock() }
        pending += chunk
        while let nl = pending.firstIndex(of: "\n") {
            let line = String(pending[..<nl]).trimmingCharacters(in: .whitespaces)
            pending.removeSubrange(...nl)
            handle(line)
        }
    }

    /// Column positions taken from the header line, so a leading "time" column (or its absence) doesn't matter.
    private var processColumn = 0
    private var inColumn = 1
    private var outColumn = 2

    private func handle(_ line: String) {
        let f = line.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }

        // Each block starts with a header line like "time,,bytes_in,bytes_out,".
        if let bytesIn = f.firstIndex(of: "bytes_in"), let bytesOut = f.firstIndex(of: "bytes_out") {
            commit()
            inColumn = bytesIn
            outColumn = bytesOut
            processColumn = f.firstIndex(of: "") ?? 0
            return
        }

        // Data row: "<time>,<name>.<pid>,<bytes_in>,<bytes_out>,"
        guard f.count > max(processColumn, inColumn, outColumn),
              let dot = f[processColumn].lastIndex(of: "."),
              let pid = Int32(f[processColumn][f[processColumn].index(after: dot)...]),
              let bytesIn = Double(f[inColumn]),
              let bytesOut = Double(f[outColumn]) else { return }
        building[pid, default: 0] += bytesIn + bytesOut
    }

    private func commit() {
        blocksSeen += 1
        // Block 1 is empty (before the first header), block 2 is the cumulative baseline.
        if blocksSeen >= 3 { latest = building }
        building = [:]
    }
}
