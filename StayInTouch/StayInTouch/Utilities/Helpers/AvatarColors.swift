//
//  AvatarColors.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum AvatarColors {
    static let palette: [String] = [
        "#FF6B6B",
        "#4ECDC4",
        "#95E1D3",
        "#F38181",
        "#AA96DA",
        "#FCBAD3",
        "#FFD93D",
        "#6BCB77"
    ]

    static func randomHex() -> String {
        palette.randomElement() ?? "#FF6B6B"
    }
}
