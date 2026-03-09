//
//  PersonStatusServiceTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class PersonStatusServiceTests: XCTestCase {
    func testDueSoonUsesSettingsWindow() {
        let groupId = UUID()
        let now = Date()
        let reference = Calendar.current.date(byAdding: .day, value: 26, to: now) ?? now

        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Alex",
            initials: "A",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: now,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            groupAddedAt: nil,
            createdAt: now,
            modifiedAt: now,
            sortOrder: 0
        )

        let group = Group(
            id: groupId,
            name: "Monthly",
            frequencyDays: 30,
            warningDays: 5,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        let settings = AppSettings(
            id: AppSettings.singletonId,
            theme: .light,
            notificationsEnabled: false,
            breachTimeOfDay: LocalTime(hour: 18, minute: 0),
            digestEnabled: false,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: .perType,
            badgeCountShowDueSoon: false,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            analyticsEnabled: true,
            hideContactNamesInNotifications: false,
            birthdayNotificationsEnabled: false,
            birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
            birthdayIgnoreSnoozePause: true,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: "1.0"
        )

        let service = PersonStatusService(referenceDate: reference)
        let dueSoon = service.dueSoonPeople([person], groups: [group], settings: settings)
        XCTAssertTrue(dueSoon.isEmpty)
    }

    func testOverdueTieBreakByLastTouchOlderFirst() {
        let groupId = UUID()
        let now = Date()
        let reference = Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now

        let older = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Bob",
            initials: "B",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: Calendar.current.date(byAdding: .day, value: -10, to: reference),
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            groupAddedAt: nil,
            createdAt: now,
            modifiedAt: now,
            sortOrder: 0
        )

        let newer = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Alex",
            initials: "A",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: Calendar.current.date(byAdding: .day, value: -9, to: reference),
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            groupAddedAt: nil,
            createdAt: now,
            modifiedAt: now,
            sortOrder: 0
        )

        let group = Group(
            id: groupId,
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        let service = PersonStatusService(referenceDate: reference)
        let overdue = service.overduePeople([newer, older], groups: [group])
        XCTAssertEqual(overdue.first?.displayName, "Bob")
    }
}
