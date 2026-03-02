//
//  NotificationGrouping.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

enum NotificationGrouping: String, CaseIterable, Codable {
    case perPerson = "per_person"
    case perType = "per_type"
    case perDay = "per_day"
}

extension NotificationGrouping {
    var displayName: String {
        switch self {
        case .perPerson: return "By Person"
        case .perType: return "By Urgency"
        case .perDay: return "By Day"
        }
    }
}
