//
//  LastTouchOption.swift
//  KeepInTouch
//

import Foundation

enum LastTouchOption: String, CaseIterable, Codable {
    case thisWeek = "This week"
    case withinTwoWeeks = "Within 2 weeks"
    case thisMonth = "This month"
    case fewMonthsAgo = "A few months ago"
    case sixPlusMonths = "6+ months ago"
    case cantRemember = "Can't remember"

    func approximateDate(from referenceDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .thisWeek:
            return calendar.date(byAdding: .day, value: -3, to: referenceDate)
        case .withinTwoWeeks:
            return calendar.date(byAdding: .day, value: -10, to: referenceDate)
        case .thisMonth:
            return calendar.date(byAdding: .day, value: -21, to: referenceDate)
        case .fewMonthsAgo:
            return calendar.date(byAdding: .month, value: -2, to: referenceDate)
        case .sixPlusMonths:
            return calendar.date(byAdding: .month, value: -6, to: referenceDate)
        case .cantRemember:
            return nil
        }
    }
}
