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
    static func classify(people: [Person], cadences: [Cadence], referenceDate: Date) -> NotificationClassification {
        var dueToday: [Person] = []
        var overdue: [Person] = []
        var dueSoon: [Person] = []
        var allForDigest: [Person] = []
        var allNonCustom: [Person] = []
        var allOverdue: [Person] = []
        var allDueSoon: [Person] = []
        var customOverrides: [CustomNotification] = []

        let calc = FrequencyCalculator(referenceDate: referenceDate)
        let cal = Calendar.current

        for person in people where !person.isPaused && !person.notificationsMuted && !(person.snoozedUntil.map { $0 > referenceDate } ?? false) {
            guard let cadence = cadences.first(where: { $0.id == person.cadenceId }) else { continue }
            guard let dueDate = calc.effectiveDueDate(for: person, in: cadences) else { continue }

            let daysUntilDue = cal.dateComponents([.day], from: cal.startOfDay(for: referenceDate), to: cal.startOfDay(for: dueDate)).day ?? 0
            let type: DailyNotificationType?
            if daysUntilDue < 0 {
                type = .overdue
            } else if daysUntilDue == 0 {
                type = .dueToday
            } else if daysUntilDue <= cadence.warningDays {
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
