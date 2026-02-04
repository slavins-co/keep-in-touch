//
//  LocalTime+Formatting.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

extension LocalTime {
    func toDate(reference: Date = Date()) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? reference
    }

    static func from(date: Date) -> LocalTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return LocalTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    var formatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: toDate())
    }
}

extension DayOfWeek {
    var displayName: String {
        rawValue.capitalized
    }
}
