//
//  LocalTime.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct LocalTime: Equatable, Codable {
    var hour: Int
    var minute: Int
}

extension LocalTime {
    static func from(jsonString: String) -> LocalTime? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LocalTime.self, from: data)
    }

    func toJsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
