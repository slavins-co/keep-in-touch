//
//  InitialsBuilder.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum InitialsBuilder {
    static func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let components = trimmed.split(separator: " ")
        if components.count == 1 {
            return String(components[0].prefix(2)).uppercased()
        }
        let first = components.first?.prefix(1) ?? ""
        let last = components.last?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
}
