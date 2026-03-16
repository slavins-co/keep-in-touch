//
//  FrequencyCalculator.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct FrequencyCalculator {
    let referenceDate: Date

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    func status(for person: Person, in groups: [Cadence]) -> ContactStatus {
        if person.isPaused { return .onTrack }
        if let snoozedUntil = person.snoozedUntil, snoozedUntil > referenceDate { return .onTrack }
        guard let group = groups.first(where: { $0.id == person.cadenceId }) else {
            return .onTrack
        }

        guard let dueDate = effectiveDueDate(for: person, in: groups) else {
            return .unknown
        }

        let daysUntilDue = calendarDaysBetween(from: referenceDate, to: dueDate)
        if daysUntilDue <= 0 {
            return .overdue
        }
        if daysUntilDue <= group.warningDays {
            return .dueSoon
        }
        return .onTrack
    }

    func daysOverdue(for person: Person, in groups: [Cadence]) -> Int {
        if person.isPaused { return 0 }
        if let snoozedUntil = person.snoozedUntil, snoozedUntil > referenceDate { return 0 }
        guard groups.first(where: { $0.id == person.cadenceId }) != nil else {
            return 0
        }

        guard let dueDate = effectiveDueDate(for: person, in: groups) else {
            return 0
        }

        let daysUntilDue = calendarDaysBetween(from: referenceDate, to: dueDate)
        return max(0, -daysUntilDue)
    }

    func effectiveDueDate(for person: Person, in groups: [Cadence]) -> Date? {
        let cal = Calendar.current
        guard let group = groups.first(where: { $0.id == person.cadenceId }) else { return nil }

        let groupDueDate: Date?
        if let lastTouch = effectiveLastTouchDate(for: person) {
            groupDueDate = cal.date(byAdding: .day, value: group.frequencyDays, to: cal.startOfDay(for: lastTouch))
        } else {
            groupDueDate = nil
        }

        let customDue = person.customDueDate.map { cal.startOfDay(for: $0) }

        // Custom due date fully replaces group frequency when set.
        // It does not combine with group — it IS the due date.
        switch (groupDueDate, customDue) {
        case (_, let c?): return c
        case (let g?, nil): return g
        case (nil, nil): return nil
        }
    }

    func effectiveLastTouchDate(for person: Person) -> Date? {
        if let lastTouch = person.lastTouchAt { return lastTouch }
        return person.cadenceAddedAt
    }

    func daysSinceLastTouch(for person: Person) -> Int? {
        guard let lastTouch = effectiveLastTouchDate(for: person) else { return nil }
        return calendarDaysBetween(from: lastTouch, to: referenceDate)
    }

    private func calendarDaysBetween(from: Date, to: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }
}
