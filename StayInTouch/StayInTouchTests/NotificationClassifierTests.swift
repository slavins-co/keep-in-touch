//
//  NotificationClassifierTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/3/26.
//

import XCTest
@testable import StayInTouch

final class NotificationClassifierTests: XCTestCase {
    func testMutedPeopleAreExcluded() {
        let cadenceId = UUID()
        let group = Cadence(id: cadenceId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let reference = Date()

        let muted = makePerson(cadenceId: cadenceId, daysAgo: 10, muted: true)
        let overdue = makePerson(cadenceId: cadenceId, daysAgo: 10)

        let result = NotificationClassifier.classify(people: [muted, overdue], groups: [group], referenceDate: reference)
        XCTAssertEqual(result.overdue.count, 1)
        XCTAssertFalse(result.overdue.contains(where: { $0.id == muted.id }))
    }

    func testCustomTimeRemovedFromGroupedLists() {
        let cadenceId = UUID()
        let group = Cadence(id: cadenceId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let reference = Date()

        var custom = makePerson(cadenceId: cadenceId, daysAgo: 10)
        custom.customBreachTime = LocalTime(hour: 9, minute: 0)

        let result = NotificationClassifier.classify(people: [custom], groups: [group], referenceDate: reference)
        XCTAssertEqual(result.customOverrides.count, 1)
        XCTAssertTrue(result.overdue.isEmpty)
        XCTAssertTrue(result.allNonCustom.isEmpty)
        XCTAssertEqual(result.allOverdue.count, 1)
        XCTAssertTrue(result.allDueSoon.isEmpty, "Overdue custom person should not be in allDueSoon")
    }

    func testDueTodayCountedInAllOverdue() {
        let cadenceId = UUID()
        let group = Cadence(id: cadenceId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let reference = Date()

        // Exactly at frequency boundary — dueToday, should be in allOverdue
        // Use consistent reference to avoid sub-second date drift between Date() calls
        let lastTouch = Calendar.current.date(byAdding: .day, value: -7, to: reference)!
        var person = makePerson(cadenceId: cadenceId, daysAgo: nil)
        person.lastTouchAt = lastTouch
        person.cadenceAddedAt = lastTouch

        let result = NotificationClassifier.classify(people: [person], groups: [group], referenceDate: reference)
        XCTAssertEqual(result.dueToday.count, 1)
        XCTAssertEqual(result.allOverdue.count, 1, "dueToday people should be counted in allOverdue for badge")
    }

    func testCustomBreachTimeDueSoonInAllDueSoon() {
        let cadenceId = UUID()
        let group = Cadence(id: cadenceId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let reference = Date()

        // 6 days ago = within warning window (7-2=5, so 6 >= 5) → dueSoon
        var person = makePerson(cadenceId: cadenceId, daysAgo: 6)
        person.customBreachTime = LocalTime(hour: 9, minute: 0)

        let result = NotificationClassifier.classify(people: [person], groups: [group], referenceDate: reference)
        XCTAssertEqual(result.customOverrides.count, 1)
        XCTAssertTrue(result.dueSoon.isEmpty, "Custom breach time people excluded from grouped dueSoon")
        XCTAssertEqual(result.allDueSoon.count, 1, "Custom breach time people should still be in allDueSoon for badge")
    }

    func testUnknownLastTouchIsExcluded() {
        let cadenceId = UUID()
        let group = Cadence(id: cadenceId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        var person = makePerson(cadenceId: cadenceId, daysAgo: nil)
        person.lastTouchAt = nil
        person.cadenceAddedAt = nil

        let result = NotificationClassifier.classify(people: [person], groups: [group], referenceDate: Date())
        XCTAssertTrue(result.allForDigest.isEmpty)
    }

    // MARK: - Calendar Day Boundary Test

    func testClassifierUsesCalendarDaysNotHours() {
        // Touch at 11 PM, reference 7 days later at 8 AM → ~6.4 × 24h periods
        // but 7 calendar days → should classify as dueToday for a 7-day frequency
        // Use consistent base date to avoid sub-second date drift between Date() calls
        let cal = Calendar.current
        let now = Date()
        let touchDate = cal.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let referenceDate = cal.date(byAdding: .day, value: 7, to: cal.date(bySettingHour: 8, minute: 0, second: 0, of: now)!)!

        let cadenceId = UUID()
        let group = Cadence(id: cadenceId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())

        var person = makePerson(cadenceId: cadenceId, daysAgo: nil)
        person.lastTouchAt = touchDate
        person.cadenceAddedAt = touchDate

        let result = NotificationClassifier.classify(people: [person], groups: [group], referenceDate: referenceDate)
        XCTAssertEqual(result.dueToday.count, 1, "7 calendar days should classify as dueToday even if fewer than 7×24 hours elapsed")
    }

    private func makePerson(cadenceId: UUID, daysAgo: Int?, muted: Bool = false) -> Person {
        let reference = Date()
        let lastTouch = daysAgo.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: reference) }
        return Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Test",
            initials: "T",
            avatarColor: "#FF6B6B",
            cadenceId: cadenceId,
            tagIds: [],
            lastTouchAt: lastTouch,
            lastTouchMethod: .text,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: muted,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            cadenceAddedAt: lastTouch,
            createdAt: reference,
            modifiedAt: reference,
            sortOrder: 0
        )
    }
}
