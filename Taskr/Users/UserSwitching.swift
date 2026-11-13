//
//  UserSwitching.swift
//  Taskr
//
//  "Switch user…": show the login window without logging out.
//

import Foundation

/// Fast user switching.
enum UserSwitching {
    private static let cgSession = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"

    /// Locks the screen to the login window so another account can sign in, leaving this session running.
    static func switchUser() {
        guard FileManager.default.isExecutableFile(atPath: cgSession) else {
            ProcessActions.showError("Couldn’t switch user",
                                     "This version of macOS doesn’t include the tool Taskr uses. Use the user menu in Control Center instead.")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cgSession)
        process.arguments = ["-suspend"]
        do { try process.run() } catch {
            ProcessActions.showError("Couldn’t switch user", error.localizedDescription)
        }
    }
}
