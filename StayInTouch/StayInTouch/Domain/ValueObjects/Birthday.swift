//
//  Birthday.swift
//  StayInTouch
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

    /// Format as "M/DD" (e.g., "3/15")
    var formatted: String {
        "\(month)/\(day)"
    }
}
