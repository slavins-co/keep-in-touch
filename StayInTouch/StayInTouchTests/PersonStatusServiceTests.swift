//
//  PersonStatusServiceTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class PersonStatusServiceTests: XCTestCase {
    /// Person 4 days from due with cadence warningDays=5 should appear in dueSoon
    /// regardless of any global settings window. FrequencyCalculator is the single
    /// source of truth for Due Soon status.
    func testDueSoonUsesWarningDaysNotSettingsWindow() {
        let cadenceId = UUID()
        let now = Date()
        // 26 days into a 30-day cadence → 4 days until due → within warningDays(5)
        let reference = Calendar.current.date(byAdding: .day, value: 26, to: now) ?? now

        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Alex",
            initials: "A",
            avatarColor: "#FF6B6B",
            cadenceId: cadenceId,
            groupIds: [],
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
            cadenceAddedAt: nil,
            createdAt: now,
            modifiedAt: now,
            sortOrder: 0
        )

        let cadence = Cadence(
            id: cadenceId,
            name: "Monthly",
            frequencyDays: 30,
            warningDays: 5,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        let service = PersonStatusService(referenceDate: reference)
        let dueSoon = service.dueSoonPeople([person], cadences: [cadence])
        XCTAssertEqual(dueSoon.count, 1)
        XCTAssertEqual(dueSoon.first?.displayName, "Alex")
    }

    func testOverdueTieBreakByLastTouchOlderFirst() {
        let cadenceId = UUID()
        let now = Date()
        let reference = Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now

        let older = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Bob",
            initials: "B",
            avatarColor: "#FF6B6B",
            cadenceId: cadenceId,
            groupIds: [],
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
            cadenceAddedAt: nil,
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
            cadenceId: cadenceId,
            groupIds: [],
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
            cadenceAddedAt: nil,
            createdAt: now,
            modifiedAt: now,
            sortOrder: 0
        )

        let cadence = Cadence(
            id: cadenceId,
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
        let overdue = service.overduePeople([newer, older], cadences: [cadence])
        XCTAssertEqual(overdue.first?.displayName, "Bob")
    }
}
