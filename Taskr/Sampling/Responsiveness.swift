//
//  Responsiveness.swift
//  Taskr
//
//  Detects hung apps ("Not responding") with the WindowServer's responsiveness query.
//

import AppKit
import CoreServices
import Darwin

// The same WindowServer query Activity Monitor and AltTab use to detect a hung app (the beach ball).
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSEventIsAppUnresponsive")
private func CGSEventIsAppUnresponsive(_ connection: Int32, _ psn: UnsafePointer<ProcessSerialNumber>) -> Bool

private typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

// Marked unavailable in Swift's headers, but still exported by CoreServices.
private let getProcessForPID: GetProcessForPIDFn? = {
    guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "GetProcessForPID") else { return nil }
    return unsafeBitCast(sym, to: GetProcessForPIDFn.self)
}()

enum Responsiveness {
    /// Pids of GUI apps that aren't answering events right now.
    static func unresponsivePids() -> Set<Int32> {
        guard let getProcessForPID else { return [] }
        let connection = CGSMainConnectionID()
        var hung = Set<Int32>()
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
            var psn = ProcessSerialNumber()
            guard getProcessForPID(app.processIdentifier, &psn) == noErr else { continue }
            if CGSEventIsAppUnresponsive(connection, &psn) { hung.insert(app.processIdentifier) }
        }
        return hung
    }
}
