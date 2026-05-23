//
//  Color+Hex.swift
//  KeepInTouch
//
//  Hex-string <-> Color conversion. Lives in Shared/ so the widget
//  extension and the main app use a single implementation.
//

import SwiftUI

extension Color {
    /// Strips non-alphanumeric characters (e.g. leading `#`, whitespace) from
    /// a hex color string. Single source of truth — replaces inline
    /// `hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)` calls
    /// (see issue #307, audit finding R8). Does NOT change case; callers that
    /// need uppercase form should chain `.uppercased()` themselves.
    static func normalize(hex: String) -> String {
        hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    init(hex: String) {
        let cleaned = Color.normalize(hex: hex)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
