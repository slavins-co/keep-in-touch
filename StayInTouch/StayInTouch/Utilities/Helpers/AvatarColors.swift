//
//  AvatarColors.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

/// Avatar color palette. Single source of truth for both:
///   1. Random hex assignment (`AvatarColors.randomHex()`)
///   2. Light/dark-mode resolution (`DS.Colors.avatarColors(for:scheme:)`)
///
/// Adding a 9th color is now a single edit here — both light AND dark
/// resolve correctly without touching DesignSystem.swift. Prior to PR
/// #312 the palette lived in two places: a `[String]` of 8 light hexes
/// here and a parallel `switch` over the same 8 normalized hexes in
/// DesignSystem.swift. A new color silently fell through to "accent
/// green fallback" in dark mode.
enum AvatarColors {
    /// One palette entry. `lightHex` is the stored avatar color (still
    /// written to `Person.avatarColor` and used as the light-mode
    /// background, white text on top). `darkBackgroundHex` and
    /// `darkTextHex` are the muted variants the dark mode addendum spec
    /// prescribes.
    struct PaletteEntry {
        /// Hex stored on `Person.avatarColor`. Light-mode background.
        /// Includes `#` prefix to match the prior `palette: [String]` format
        /// that callers serialized verbatim.
        let lightHex: String
        /// Dark-mode background (no `#` — passed directly to `Color(hex:)`).
        let darkBackgroundHex: String
        /// Dark-mode text color on the dark background.
        let darkTextHex: String
    }

    /// Palette entries. Values **byte-identical** to the prior
    /// `palette: [String]` and the prior `DS.Colors.avatarColors(for:scheme:)`
    /// switch. See `Color.normalize(hex:)` for the normalization used to
    /// match a stored hex against an entry.
    static let entries: [PaletteEntry] = [
        PaletteEntry(lightHex: "#FF6B6B", darkBackgroundHex: "3D2010", darkTextHex: "FDBA74"),  // Red / Orange-ish
        PaletteEntry(lightHex: "#4ECDC4", darkBackgroundHex: "0D3D3D", darkTextHex: "5EEAD4"),  // Teal
        PaletteEntry(lightHex: "#95E1D3", darkBackgroundHex: "0D3D3D", darkTextHex: "5EEAD4"),  // Mint
        PaletteEntry(lightHex: "#F38181", darkBackgroundHex: "3D2010", darkTextHex: "FDBA74"),  // Pink-Red
        PaletteEntry(lightHex: "#AA96DA", darkBackgroundHex: "2D1B4E", darkTextHex: "D8B4FE"),  // Purple
        PaletteEntry(lightHex: "#FCBAD3", darkBackgroundHex: "2D1B4E", darkTextHex: "D8B4FE"),  // Light Pink
        PaletteEntry(lightHex: "#FFD93D", darkBackgroundHex: "3D2E10", darkTextHex: "FCD34D"),  // Yellow / Amber
        PaletteEntry(lightHex: "#6BCB77", darkBackgroundHex: "2D5040", darkTextHex: "4ADE80")   // Green
    ]

    /// Hexes the legacy `palette: [String]` exposed — retained for
    /// callers that just want a random light-mode hex.
    static var palette: [String] {
        entries.map(\.lightHex)
    }

    static func randomHex() -> String {
        palette.randomElement() ?? "#FF6B6B"
    }

    /// Looks up a palette entry whose `lightHex` matches the supplied
    /// hex (after normalization). Returns `nil` when no entry matches —
    /// callers should fall back to the accent-green default.
    static func entry(forLightHex hex: String) -> PaletteEntry? {
        let target = Color.normalize(hex: hex).uppercased()
        return entries.first { entry in
            Color.normalize(hex: entry.lightHex).uppercased() == target
        }
    }
}
