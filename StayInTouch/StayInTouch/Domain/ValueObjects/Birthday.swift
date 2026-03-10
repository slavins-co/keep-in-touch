//
//  Birthday.swift
//  KeepInTouch
//
//  Created by Claude on 3/1/26.
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
}
