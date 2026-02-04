//
//  SLACalculator.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct SLACalculator {
    let referenceDate: Date

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    func status(for person: Person, in groups: [Group]) -> SLAStatus {
        if person.isPaused { return .inSLA }
        guard let group = groups.first(where: { $0.id == person.groupId }) else {
            return .inSLA
        }

        guard let lastTouch = effectiveLastTouchDate(for: person) else {
            return .unknown
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastTouch, to: referenceDate).day ?? 0
        if daysSince >= group.slaDays {
            return .outOfSLA
        }
        if daysSince >= max(0, group.slaDays - group.warningDays) {
            return .dueSoon
        }
        return .inSLA
    }

    func daysOverdue(for person: Person, in groups: [Group]) -> Int {
        if person.isPaused { return 0 }
        guard let group = groups.first(where: { $0.id == person.groupId }) else {
            return 0
        }

        guard let lastTouch = effectiveLastTouchDate(for: person) else {
            return 0
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastTouch, to: referenceDate).day ?? 0
        return max(0, daysSince - group.slaDays)
    }

    func effectiveLastTouchDate(for person: Person) -> Date? {
        if let lastTouch = person.lastTouchAt { return lastTouch }
        // TODO: Revisit onboarding/new-contact flow if we want a different fallback.
        return person.groupAddedAt
    }

    func daysSinceLastTouch(for person: Person) -> Int? {
        guard let lastTouch = effectiveLastTouchDate(for: person) else { return nil }
        return Calendar.current.dateComponents([.day], from: lastTouch, to: referenceDate).day
    }
}
