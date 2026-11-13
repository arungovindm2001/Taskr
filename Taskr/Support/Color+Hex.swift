//
//  Color+Hex.swift
//  Taskr
//
//  Small SwiftUI convenience for writing colors as hex literals.
//

import SwiftUI

extension Color {
    /// Creates an sRGB color from a 24-bit hex value, e.g. `Color(hex: 0xffb454)`.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255)
    }
}
