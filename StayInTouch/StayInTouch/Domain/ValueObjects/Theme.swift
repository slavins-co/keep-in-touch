//
//  Theme.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum Theme: String, CaseIterable, Codable {
    case dark = "dark"
    case light = "light"
    case system = "system"

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }
}
