//
//  StatsCalculator.swift
//  KeepInTouch
//

import Foundation

struct StatsCalculator {

    func compute(
        now: Date = Date(),
        range: StatsRange,
        events: [TouchEvent],
        people: [Person],
        cadences: [Cadence]
    ) -> StatsSnapshot {
        guard !people.isEmpty || !events.isEmpty else {
            return StatsSnapshot(range: range, generatedAt: now, state: .empty)
        }

        let rangeStart = range.startDate(now: now)
        let eventsInRange = events.filter { $0.at >= rangeStart }

        let cadenceRows = cadences
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { cadence in
                cadenceRow(
                    cadence: cadence,
                    range: range,
                    people: people,
                    eventsInRange: eventsInRange
                )
            }

        let methodRows = methodBreakdown(events: eventsInRange)

        if eventsInRange.isEmpty {
            return StatsSnapshot(range: range, generatedAt: now, state: .emptyForRange)
        }

        return StatsSnapshot(
            range: range,
            generatedAt: now,
            state: .ready(
                cadenceRows: cadenceRows,
                methodRows: methodRows,
                totalEvents: eventsInRange.count
            )
        )
    }

    // MARK: - Cadence row

    private func cadenceRow(
        cadence: Cadence,
        range: StatsRange,
        people: [Person],
        eventsInRange: [TouchEvent]
    ) -> StatsSnapshot.CadenceRow {
        let trackedPeople = people.filter {
            $0.cadenceId == cadence.id && $0.isTracked && !$0.isPaused
        }
        let trackedIds = Set(trackedPeople.map(\.id))
        let actual = eventsInRange.filter { trackedIds.contains($0.personId) }.count

        let expectedPerPerson = range.dayCount / max(cadence.frequencyDays, 1)
        let expected = expectedPerPerson * trackedPeople.count

        let ratio: Double? = expected == 0 ? nil : Double(actual) / Double(expected)

        return StatsSnapshot.CadenceRow(
            id: cadence.id,
            name: cadence.name,
            frequencyDays: cadence.frequencyDays,
            trackedCount: trackedPeople.count,
            expected: expected,
            actual: actual,
            ratio: ratio
        )
    }

    // MARK: - Method breakdown

    private func methodBreakdown(events: [TouchEvent]) -> [StatsSnapshot.MethodRow] {
        guard !events.isEmpty else { return [] }
        let total = events.count
        let counts = Dictionary(grouping: events, by: \.method).mapValues(\.count)

        return TouchMethod.allCases.compactMap { method -> StatsSnapshot.MethodRow? in
            guard let count = counts[method], count > 0 else { return nil }
            return StatsSnapshot.MethodRow(
                method: method,
                count: count,
                percent: Double(count) / Double(total)
            )
        }
        .sorted { $0.count > $1.count }
    }
}
