//
//  NotificationClassifier.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

struct NotificationClassification {
    let dueToday: [Person]
    let overdue: [Person]
    let dueSoon: [Person]
    let allForDigest: [Person]
    let allNonCustom: [Person]
    let allOverdue: [Person]
    let allDueSoon: [Person]
    let customOverrides: [CustomNotification]
}

struct CustomNotification {
    let person: Person
    let type: DailyNotificationType
    let time: LocalTime
}

enum NotificationClassifier {
    static func classify(people: [Person], groups: [Group], referenceDate: Date) -> NotificationClassification {
        var dueToday: [Person] = []
        var overdue: [Person] = []
        var dueSoon: [Person] = []
        var allForDigest: [Person] = []
        var allNonCustom: [Person] = []
        var allOverdue: [Person] = []
        var allDueSoon: [Person] = []
        var customOverrides: [CustomNotification] = []

        for person in people where !person.isPaused && !person.notificationsMuted && !(person.snoozedUntil.map { $0 > referenceDate } ?? false) {
            guard let group = groups.first(where: { $0.id == person.groupId }) else { continue }
            guard let lastTouch = FrequencyCalculator(referenceDate: referenceDate).effectiveLastTouchDate(for: person) else { continue }

            let daysSince = Calendar.current.dateComponents([.day], from: lastTouch, to: referenceDate).day ?? 0
            let type: DailyNotificationType?
            if daysSince > group.frequencyDays {
                type = .overdue
            } else if daysSince == group.frequencyDays {
                type = .dueToday
            } else if daysSince >= max(0, group.frequencyDays - group.warningDays) {
                type = .dueSoon
            } else {
                type = nil
            }

            guard let type else { continue }
            allForDigest.append(person)
            switch type {
            case .overdue, .dueToday:
                allOverdue.append(person)
            case .dueSoon:
                allDueSoon.append(person)
            }

            if let custom = person.customBreachTime {
                customOverrides.append(CustomNotification(person: person, type: type, time: custom))
            } else {
                allNonCustom.append(person)
                switch type {
                case .dueToday: dueToday.append(person)
                case .overdue: overdue.append(person)
                case .dueSoon: dueSoon.append(person)
                }
            }
        }

        return NotificationClassification(
            dueToday: dueToday,
            overdue: overdue,
            dueSoon: dueSoon,
            allForDigest: allForDigest,
            allNonCustom: allNonCustom,
            allOverdue: allOverdue,
            allDueSoon: allDueSoon,
            customOverrides: customOverrides
        )
    }
}
