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

    func status(for person: Person, in groups: [Group]) -> ContactStatus {
        if person.isPaused { return .onTrack }
        if let snoozedUntil = person.snoozedUntil, snoozedUntil > referenceDate { return .onTrack }
        guard let group = groups.first(where: { $0.id == person.groupId }) else {
            return .onTrack
        }

        guard let lastTouch = effectiveLastTouchDate(for: person) else {
            return .unknown
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastTouch, to: referenceDate).day ?? 0
        if daysSince >= group.frequencyDays {
            return .overdue
        }
        if daysSince >= max(0, group.frequencyDays - group.warningDays) {
            return .dueSoon
        }
        return .onTrack
    }

    func daysOverdue(for person: Person, in groups: [Group]) -> Int {
        if person.isPaused { return 0 }
        if let snoozedUntil = person.snoozedUntil, snoozedUntil > referenceDate { return 0 }
        guard let group = groups.first(where: { $0.id == person.groupId }) else {
            return 0
        }

        guard let lastTouch = effectiveLastTouchDate(for: person) else {
            return 0
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastTouch, to: referenceDate).day ?? 0
        return max(0, daysSince - group.frequencyDays)
    }

    func effectiveLastTouchDate(for person: Person) -> Date? {
        if let lastTouch = person.lastTouchAt { return lastTouch }
        return person.groupAddedAt
    }

    func daysSinceLastTouch(for person: Person) -> Int? {
        guard let lastTouch = effectiveLastTouchDate(for: person) else { return nil }
        return Calendar.current.dateComponents([.day], from: lastTouch, to: referenceDate).day
    }
}
