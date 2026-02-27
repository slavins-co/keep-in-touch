//
//  BadgeCountOption.swift
//  StayInTouch
//
//  Created by Codex on 2/27/26.
//

import Foundation

enum BadgeCountOption: String, CaseIterable, Codable {
    case overdueOnly = "overdue_only"
    case overdueAndDueSoon = "overdue_and_due_soon"
}

extension BadgeCountOption {
    var displayName: String {
        switch self {
        case .overdueOnly: return "Overdue Only"
        case .overdueAndDueSoon: return "Overdue + Due Soon"
        }
    }
}
