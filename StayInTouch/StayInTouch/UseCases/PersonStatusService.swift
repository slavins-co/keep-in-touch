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

    func overduePeople(_ people: [Person], cadences: [Cadence]) -> [Person] {
        let filtered = people.filter { !($0.isPaused) }
        let overdue = filtered.filter { calculator.status(for: $0, in: cadences) == .overdue }
        return overdue.sorted { lhs, rhs in
            sortOverdue(lhs, rhs, cadences: cadences)
        }
    }

    func dueSoonPeople(_ people: [Person], cadences: [Cadence]) -> [Person] {
        let filtered = people.filter { !($0.isPaused) }
        let dueSoon = filtered.filter { calculator.status(for: $0, in: cadences) == .dueSoon }

        return dueSoon.sorted { lhs, rhs in
            sortDueSoon(lhs, rhs, cadences: cadences)
        }
    }

    /// Partition non-paused people into the three Home buckets in a single
    /// pass so all three buckets are routed through the same status source
    /// (`FrequencyCalculator.status`). Eliminates the silent-divergence risk
    /// of running a second `FrequencyCalculator` for the "All Good" bucket
    /// while using `PersonStatusService` for the other two (audit R5, #310).
    ///
    /// Bucket semantics, preserved from the prior implementation:
    /// - `overdue`: status == .overdue, sorted by daysOverdue desc, then
    ///   effectiveLastTouchDate asc, then displayName asc.
    /// - `dueSoon`: status == .dueSoon, sorted by daysUntilDue asc, then
    ///   effectiveLastTouchDate asc, then displayName asc.
    /// - `onTrack`: status == .onTrack, sorted by `lastTouchAt` desc
    ///   (most-recently touched first; nil treated as `.distantPast`).
    /// - Paused people are excluded from all three buckets.
    /// - `.unknown` status (no cadence match / no effective due date)
    ///   is excluded from all three buckets.
    func partition(
        _ people: [Person],
        cadences: [Cadence]
    ) -> (overdue: [Person], dueSoon: [Person], onTrack: [Person]) {
        var overdue: [Person] = []
        var dueSoon: [Person] = []
        var onTrack: [Person] = []

        for person in people where !person.isPaused {
            switch calculator.status(for: person, in: cadences) {
            case .overdue:
                overdue.append(person)
            case .dueSoon:
                dueSoon.append(person)
            case .onTrack:
                onTrack.append(person)
            case .unknown:
                continue
            }
        }

        overdue.sort { sortOverdue($0, $1, cadences: cadences) }
        dueSoon.sort { sortDueSoon($0, $1, cadences: cadences) }
        onTrack.sort { ($0.lastTouchAt ?? .distantPast) > ($1.lastTouchAt ?? .distantPast) }

        return (overdue, dueSoon, onTrack)
    }

    // MARK: - Private

    private func sortOverdue(_ lhs: Person, _ rhs: Person, cadences: [Cadence]) -> Bool {
        let lhsOverdue = calculator.daysOverdue(for: lhs, in: cadences)
        let rhsOverdue = calculator.daysOverdue(for: rhs, in: cadences)
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

    private func sortDueSoon(_ lhs: Person, _ rhs: Person, cadences: [Cadence]) -> Bool {
        let lhsDays = daysUntilDue(for: lhs, cadences: cadences)
        let rhsDays = daysUntilDue(for: rhs, cadences: cadences)
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

    private func daysUntilDue(for person: Person, cadences: [Cadence]) -> Int {
        calculator.daysUntilDue(for: person, in: cadences) ?? Int.max
    }
}
