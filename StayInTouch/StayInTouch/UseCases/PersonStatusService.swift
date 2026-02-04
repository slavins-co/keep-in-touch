//
//  PersonStatusService.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct PersonStatusService {
    private let calculator: SLACalculator

    init(referenceDate: Date = Date()) {
        self.calculator = SLACalculator(referenceDate: referenceDate)
    }

    func overduePeople(_ people: [Person], groups: [Group]) -> [Person] {
        let filtered = people.filter { !($0.isPaused) }
        let overdue = filtered.filter { calculator.status(for: $0, in: groups) == .outOfSLA }
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

    func dueSoonPeople(_ people: [Person], groups: [Group], settings: AppSettings) -> [Person] {
        let filtered = people.filter { !($0.isPaused) }
        let dueSoon = filtered.filter { person in
            guard calculator.status(for: person, in: groups) == .dueSoon else { return false }
            guard let daysSince = calculator.daysSinceLastTouch(for: person) else { return false }
            guard let group = groups.first(where: { $0.id == person.groupId }) else { return false }
            let daysUntilDue = group.slaDays - daysSince
            return daysUntilDue > 0 && daysUntilDue <= settings.dueSoonWindowDays
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

    private func daysUntilDue(for person: Person, groups: [Group]) -> Int {
        guard let daysSince = calculator.daysSinceLastTouch(for: person) else { return Int.max }
        guard let group = groups.first(where: { $0.id == person.groupId }) else { return Int.max }
        return group.slaDays - daysSince
    }
}
