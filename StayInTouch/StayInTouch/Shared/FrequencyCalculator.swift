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
        status(for: person, cadence: cadences.first(where: { $0.id == person.cadenceId }))
    }

    /// Dict-based overload. Avoids the O(N) linear scan that the
    /// `[C]` overload performs per call — at list-render hot paths (Home,
    /// Contacts) this turns an O(N×M) sweep into O(N) (audit E3, #317).
    /// Behavior is identical: the same cadence is resolved by id.
    func status<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        cadencesById: [UUID: C]
    ) -> ContactStatus {
        status(for: person, cadence: cadencesById[person.cadenceId])
    }

    private func status<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        cadence: C?
    ) -> ContactStatus {
        if person.isPaused { return .onTrack }
        if person.isSnoozed(at: referenceDate) { return .onTrack }
        guard let cadence else { return .onTrack }

        guard let dueDate = effectiveDueDate(for: person, cadence: cadence) else {
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
        daysOverdue(for: person, cadence: cadences.first(where: { $0.id == person.cadenceId }))
    }

    /// Dict-based overload (see `status(for:cadencesById:)` for rationale).
    func daysOverdue<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        cadencesById: [UUID: C]
    ) -> Int {
        daysOverdue(for: person, cadence: cadencesById[person.cadenceId])
    }

    private func daysOverdue<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        cadence: C?
    ) -> Int {
        if person.isPaused { return 0 }
        if person.isSnoozed(at: referenceDate) { return 0 }
        guard let cadence else { return 0 }

        guard let dueDate = effectiveDueDate(for: person, cadence: cadence) else {
            return 0
        }

        let daysUntilDue = calendarDaysBetween(from: referenceDate, to: dueDate)
        return max(0, -daysUntilDue)
    }

    func effectiveDueDate<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        in cadences: [C]
    ) -> Date? {
        effectiveDueDate(for: person, cadence: cadences.first(where: { $0.id == person.cadenceId }))
    }

    /// Dict-based overload (see `status(for:cadencesById:)` for rationale).
    func effectiveDueDate<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        cadencesById: [UUID: C]
    ) -> Date? {
        effectiveDueDate(for: person, cadence: cadencesById[person.cadenceId])
    }

    private func effectiveDueDate<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        cadence: C?
    ) -> Date? {
        let cal = Calendar.current
        guard let cadence else { return nil }

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

    /// Human-readable "time since last touch" label shown in contact rows.
    /// Returns `"Today"` when the last touch was today, `"\(n)d ago"` for any
    /// positive day count, and `"No contact"` when no effective last-touch
    /// date can be resolved. Single source of truth — replaces the inline
    /// helper that was duplicated across `HomeView` and `ContactsListView`
    /// (audit finding Q6, issue #313).
    func timeAgoText<P: FrequencyCalculatorPerson>(for person: P) -> String {
        let days = daysSinceLastTouch(for: person)
        guard let days else { return "No contact" }
        if days == 0 { return "Today" }
        return "\(days)d ago"
    }

    /// Calendar-day difference between `referenceDate` and the person's
    /// effective due date. Negative when overdue, zero when due today,
    /// positive when due in the future. Returns `nil` when no due date can
    /// be resolved (no matching cadence, no last-touch and no custom date).
    /// Single source of truth — replaces the inline
    /// `cal.dateComponents([.day], from: startOfDay(...), to: startOfDay(...))`
    /// pattern that was duplicated across NotificationClassifier,
    /// PersonStatusService, WidgetDataProvider, and PersonHeroSection (see
    /// issue #307, audit finding R3).
    func daysUntilDue<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        in cadences: [C]
    ) -> Int? {
        guard let dueDate = effectiveDueDate(for: person, in: cadences) else { return nil }
        return calendarDaysBetween(from: referenceDate, to: dueDate)
    }

    /// Dict-based overload (see `status(for:cadencesById:)` for rationale).
    func daysUntilDue<P: FrequencyCalculatorPerson, C: FrequencyCalculatorCadence>(
        for person: P,
        cadencesById: [UUID: C]
    ) -> Int? {
        guard let dueDate = effectiveDueDate(for: person, cadencesById: cadencesById) else { return nil }
        return calendarDaysBetween(from: referenceDate, to: dueDate)
    }

    /// Calendar-day difference (startOfDay-aligned) between two dates.
    /// Promoted from `private` so callers outside `FrequencyCalculator`
    /// can route through it instead of reimplementing the same
    /// `dateComponents([.day], …)` boilerplate.
    func calendarDaysBetween(from: Date, to: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }
}
