//
//  StatsRange.swift
//  KeepInTouch
//

import Foundation

enum StatsRange: String, CaseIterable, Codable, Identifiable {
    case days30
    case days90

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .days30: return 30
        case .days90: return 90
        }
    }

    var displayName: String {
        switch self {
        case .days30: return "30 days"
        case .days90: return "90 days"
        }
    }

    /// Helps the user pick the range that best matches how they keep in touch.
    /// 30 days gives Weekly + Biweekly cadences ~2–4 expected touches per
    /// person; 90 days does the same for Monthly + Quarterly.
    var subtitle: String {
        switch self {
        case .days30: return "Best signal for Weekly and Biweekly cadences"
        case .days90: return "Best signal for Monthly and Quarterly cadences"
        }
    }
}
