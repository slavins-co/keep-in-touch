//
//  TimeOfDay.swift
//  KeepInTouch
//
//  Created by Codex on 2/15/26.
//

import Foundation

enum TimeOfDay: String, CaseIterable, Codable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"

    /// Higher = later in the day (used for descending sort)
    var sortOrder: Int {
        switch self {
        case .morning: return 1
        case .afternoon: return 2
        case .evening: return 3
        }
    }
}
