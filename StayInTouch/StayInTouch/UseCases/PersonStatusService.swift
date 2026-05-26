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
        let cadencesById = Dictionary(uniqueKeysWithValues: cadences.map { ($0.id, $0) })
        let filtered = people.filter { !($0.isPaused) }
        let overdue = filtered.filter { calculator.status(for: $0, cadencesById: cadencesById) == .overdue }
        return overdue.sorted { lhs, rhs in
            sortOverdue(lhs, rhs, cadencesById: cadencesById)
        }
    }

    func dueSoonPeople(_ people: [Person], cadences: [Cadence]) -> [Person] {
        let cadencesById = Dictionary(uniqueKeysWithValues: cadences.map { ($0.id, $0) })
        let filtered = people.filter { !($0.isPaused) }
        let dueSoon = filtered.filter { calculator.status(for: $0, cadencesById: cadencesById) == .dueSoon }

        return dueSoon.sorted { lhs, rhs in
            sortDueSoon(lhs, rhs, cadencesById: cadencesById)
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
        // Build the id→cadence dict once so per-person status / sort lookups
        // are O(1) instead of O(N) (audit E3, #317). All downstream paths
        // (status, sort comparators) route through the dict-based overloads.
        let cadencesById = Dictionary(uniqueKeysWithValues: cadences.map { ($0.id, $0) })

        var overdue: [Person] = []
        var dueSoon: [Person] = []
        var onTrack: [Person] = []

        for person in people where !person.isPaused {
            switch calculator.status(for: person, cadencesById: cadencesById) {
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

        overdue.sort { sortOverdue($0, $1, cadencesById: cadencesById) }
        dueSoon.sort { sortDueSoon($0, $1, cadencesById: cadencesById) }
        onTrack.sort { ($0.lastTouchAt ?? .distantPast) > ($1.lastTouchAt ?? .distantPast) }

        return (overdue, dueSoon, onTrack)
    }

    // MARK: - Private

    private func sortOverdue(_ lhs: Person, _ rhs: Person, cadencesById: [UUID: Cadence]) -> Bool {
        let lhsOverdue = calculator.daysOverdue(for: lhs, cadencesById: cadencesById)
        let rhsOverdue = calculator.daysOverdue(for: rhs, cadencesById: cadencesById)
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

    private func sortDueSoon(_ lhs: Person, _ rhs: Person, cadencesById: [UUID: Cadence]) -> Bool {
        let lhsDays = daysUntilDue(for: lhs, cadencesById: cadencesById)
        let rhsDays = daysUntilDue(for: rhs, cadencesById: cadencesById)
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

    private func daysUntilDue(for person: Person, cadencesById: [UUID: Cadence]) -> Int {
        calculator.daysUntilDue(for: person, cadencesById: cadencesById) ?? Int.max
    }
}
