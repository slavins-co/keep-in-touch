//
//  Birthday.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  Created by Claude on 3/1/26.
//  Moved to Shared/ for #329 so the widget extension can decode stored
//  birthdays and compute next-occurrence countdowns. Foundation-only leaf
//  value object — drags no domain dependencies into the widget target.
//

import Foundation

struct Birthday: Equatable, Codable, Hashable {
    var month: Int   // 1-12
    var day: Int     // 1-31
    var year: Int?   // optional (nil if unknown)
}

extension Birthday {
    static func from(jsonString: String) -> Birthday? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Birthday.self, from: data)
    }

    func toJsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func from(dateComponents: DateComponents) -> Birthday? {
        guard let month = dateComponents.month, let day = dateComponents.day else { return nil }
        return Birthday(month: month, day: day, year: dateComponents.year)
    }

    /// Format as "MMM d" (e.g., "Jan 23")
    var formatted: String {
        let symbols = Calendar.current.shortMonthSymbols
        let index = min(max(month - 1, 0), 11)
        return "\(symbols[index]) \(day)"
    }

    /// Returns true when this birthday's month and day match today's calendar date.
    var isToday: Bool {
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        return components.month == month && components.day == day
    }

    /// The next calendar date (at the start of that day) on which this
    /// birthday falls, on or after `referenceDate`. Today counts as the
    /// next occurrence when today is the birthday.
    ///
    /// - Year is ignored (a birthday recurs annually).
    /// - Year-rollover is handled naturally by searching forward.
    /// - Feb 29 in a non-leap year falls back to Mar 1 (`.nextTime`
    ///   matching policy), matching the iOS Reminders / Calendar convention
    ///   for non-existent recurrence dates.
    func nextOccurrence(after referenceDate: Date, calendar: Calendar = .current) -> Date {
        let startOfReference = calendar.startOfDay(for: referenceDate)
        // Search from one second before the start of the reference day so a
        // birthday that is *today* resolves to today, not next year.
        let searchStart = startOfReference.addingTimeInterval(-1)
        var components = DateComponents()
        components.month = month
        components.day = day
        let next = calendar.nextDate(
            after: searchStart,
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        )
        return calendar.startOfDay(for: next ?? startOfReference)
    }

    /// Whole calendar days from `referenceDate` until the next occurrence of
    /// this birthday. `0` when the birthday is today, `1` tomorrow, etc.
    func daysUntil(from referenceDate: Date, calendar: Calendar = .current) -> Int {
        let startOfReference = calendar.startOfDay(for: referenceDate)
        let next = nextOccurrence(after: referenceDate, calendar: calendar)
        return calendar.dateComponents([.day], from: startOfReference, to: next).day ?? 0
    }
}
