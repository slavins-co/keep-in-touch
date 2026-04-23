//
//  FrequencyCalculator.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  Reads from `FrequencyCalculatorPerson` / `FrequencyCalculatorCadence`
//  protocols so the widget can reuse the exact same SLA logic without
//  depending on the Domain layer.
//

import Foundation

struct FrequencyCalculator {
    let referenceDate: Date

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    func status<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        in cadences: [C]
    ) -> ContactStatus {
        if person.isPaused { return .onTrack }
        if let snoozedUntil = person.snoozedUntil, snoozedUntil > referenceDate { return .onTrack }
        guard let cadence = cadences.first(where: { $0.id == person.cadenceId }) else {
            return .onTrack
        }

        guard let dueDate = effectiveDueDate(for: person, in: cadences) else {
            return .unknown
        }

        let daysUntilDue = calendarDaysBetween(from: referenceDate, to: dueDate)
        if daysUntilDue <= 0 {
            return .overdue
        }
        if daysUntilDue <= cadence.warningDays {
            return .dueSoon
        }
        return .onTrack
    }

    func daysOverdue<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        in cadences: [C]
    ) -> Int {
        if person.isPaused { return 0 }
        if let snoozedUntil = person.snoozedUntil, snoozedUntil > referenceDate { return 0 }
        guard cadences.first(where: { $0.id == person.cadenceId }) != nil else {
            return 0
        }

        guard let dueDate = effectiveDueDate(for: person, in: cadences) else {
            return 0
        }

        let daysUntilDue = calendarDaysBetween(from: referenceDate, to: dueDate)
        return max(0, -daysUntilDue)
    }

    func effectiveDueDate<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        in cadences: [C]
    ) -> Date? {
        let cal = Calendar.current
        guard let cadence = cadences.first(where: { $0.id == person.cadenceId }) else { return nil }

        let cadenceDueDate: Date?
        if let lastTouch = effectiveLastTouchDate(for: person) {
            cadenceDueDate = cal.date(byAdding: .day, value: cadence.frequencyDays, to: cal.startOfDay(for: lastTouch))
        } else {
            cadenceDueDate = nil
        }

        let customDue = person.customDueDate.map { cal.startOfDay(for: $0) }

        // Custom due date fully replaces cadence frequency when set.
        // It does not combine with cadence — it IS the due date.
        switch (cadenceDueDate, customDue) {
        case (_, let c?): return c
        case (let d?, nil): return d
        case (nil, nil): return nil
        }
    }

    func effectiveLastTouchDate<P: FrequencyCalculatorPerson>(for person: P) -> Date? {
        if let lastTouch = person.lastTouchAt { return lastTouch }
        return person.cadenceAddedAt
    }

    func daysSinceLastTouch<P: FrequencyCalculatorPerson>(for person: P) -> Int? {
        guard let lastTouch = effectiveLastTouchDate(for: person) else { return nil }
        return calendarDaysBetween(from: lastTouch, to: referenceDate)
    }

    private func calendarDaysBetween(from: Date, to: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }
}
