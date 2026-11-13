//
//  IconCache.swift
//  Taskr
//
//  Small, cached Finder icons for the rows in the Processes list.
//

import AppKit
import UniformTypeIdentifiers

/// 16-point icons for the Processes list, cached by path.
///
/// `NSWorkspace.icon(forFile:)` is relatively slow and the list redraws every second, so each icon
/// is fetched once. Used from SwiftUI views on the main actor.
final class IconCache {
    static let shared = IconCache()

    private var cache: [String: NSImage] = [:]
    private static let size = NSSize(width: 16, height: 16)

    /// What macOS shows for a bare executable, used when a process has no bundle or readable path.
    private lazy var generic: NSImage = {
        let image = NSWorkspace.shared.icon(for: UTType.unixExecutable)
        image.size = Self.size
        return image
    }()

    /// The icon for the file or bundle at `path`, or the generic executable icon for `nil` or empty paths.
    func icon(for path: String?) -> NSImage {
        guard let path, !path.isEmpty else { return generic }
        if let hit = cache[path] { return hit }

        // Our own bundle: use the icon baked into the running app, which LaunchServices may not have indexed yet.
        let image = path == Bundle.main.bundlePath
            ? (NSApp.applicationIconImage.copy() as? NSImage ?? NSWorkspace.shared.icon(forFile: path))
            : NSWorkspace.shared.icon(forFile: path)
        image.size = Self.size
        cache[path] = image
        return image
    }
}
