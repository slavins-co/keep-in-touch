//
//  BrandColors.swift
//  KeepInTouch
//
//  Single source of truth for brand color hex values shared across the
//  main app's DesignSystem and the widget extension. Widgets run in a
//  separate process and can't import DesignSystem.swift, so brand hex
//  values lived in two places before — see issue #285.
//
//  Pattern: expose both the raw hex string (for places that build
//  adaptive light/dark variants from strings) and the resolved SwiftUI
//  Color (for direct use). Semantic / adaptive wrapping still belongs
//  in DesignSystem.swift.
//

import SwiftUI

enum BrandColors {
    /// Hero accent green. Brand identity color used for the detail-view
    /// CTA container, the search focus ring (light), the filter accent
    /// (light), and the widget's "all caught up" glyph.
    static let heroAccentGreenHex = "3D6B4F"
    static let heroAccentGreen = Color(hex: heroAccentGreenHex)
}
