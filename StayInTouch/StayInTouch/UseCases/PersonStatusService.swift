//
//  PersonStatusService.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct PersonStatusService {
    private let calculator: FrequencyCalculator

    init(referenceDate: Date = Date()) {
        self.calculator = FrequencyCalculator(referenceDate: referenceDate)
    }

    func overduePeople(_ people: [Person], groups: [Cadence]) -> [Person] {
        let filtered = people.filter { !($0.isPaused) }
        let overdue = filtered.filter { calculator.status(for: $0, in: groups) == .overdue }
        return overdue.sorted { lhs, rhs in
            let lhsOverdue = calculator.daysOverdue(for: lhs, in: groups)
            let rhsOverdue = calculator.daysOverdue(for: rhs, in: groups)
            if lhsOverdue != rhsOverdue {
                return lhsOverdue > rhsOverdue
            }
            let lhsDate = calculator.effectiveLastTouchDate(for: lhs)
            let rhsDate = calculator.effectiveLastTouchDate(for: rhs)
            if lhsDate != rhsDate {
                return (lhsDate ?? .distantPast) < (rhsDate ?? .distantPast)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func dueSoonPeople(_ people: [Person], groups: [Cadence], settings: AppSettings) -> [Person] {
        let filtered = people.filter { !($0.isPaused) }
        let dueSoon = filtered.filter { person in
            guard calculator.status(for: person, in: groups) == .dueSoon else { return false }
            let days = daysUntilDue(for: person, groups: groups)
            return days > 0 && days <= settings.dueSoonWindowDays
        }

        return dueSoon.sorted { lhs, rhs in
            let lhsDays = daysUntilDue(for: lhs, groups: groups)
            let rhsDays = daysUntilDue(for: rhs, groups: groups)
            if lhsDays != rhsDays {
                return lhsDays < rhsDays
            }
            let lhsDate = calculator.effectiveLastTouchDate(for: lhs)
            let rhsDate = calculator.effectiveLastTouchDate(for: rhs)
            if lhsDate != rhsDate {
                return (lhsDate ?? .distantPast) < (rhsDate ?? .distantPast)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func daysUntilDue(for person: Person, groups: [Cadence]) -> Int {
        guard let dueDate = calculator.effectiveDueDate(for: person, in: groups) else { return Int.max }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: calculator.referenceDate), to: cal.startOfDay(for: dueDate)).day ?? Int.max
    }
}
