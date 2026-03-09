//
//  FrequencyCalculatorTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class FrequencyCalculatorTests: XCTestCase {
    func testNoTouchNoGroupAddedIsUnknown() {
        let groupId = UUID()
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Joe",
            initials: "J",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: nil,
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
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let status = FrequencyCalculator(referenceDate: Date()).status(for: person, in: [group])
        XCTAssertEqual(status, .unknown)
    }

    func testNoTouchWithGroupAddedDateBecomesOutOfSLAAfterSlaDays() {
        let groupId = UUID()
        let start = Date()
        let reference = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Joe",
            initials: "J",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: nil,
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
            groupAddedAt: start,
            createdAt: start,
            modifiedAt: start,
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: start, modifiedAt: start)
        let status = FrequencyCalculator(referenceDate: reference).status(for: person, in: [group])
        XCTAssertEqual(status, .overdue)
    }

    func testPausedIsAlwaysInSLA() {
        let groupId = UUID()
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Pat",
            initials: "P",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: nil,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: true,
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
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let status = FrequencyCalculator(referenceDate: Date()).status(for: person, in: [group])
        XCTAssertEqual(status, .onTrack)
    }

    func testDaysOverdueUsesGroupAddedDateWhenNoTouches() {
        let groupId = UUID()
        let start = Date()
        let reference = Calendar.current.date(byAdding: .day, value: 10, to: start) ?? start
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Joe",
            initials: "J",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: nil,
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
            groupAddedAt: start,
            createdAt: start,
            modifiedAt: start,
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: start, modifiedAt: start)
        let overdue = FrequencyCalculator(referenceDate: reference).daysOverdue(for: person, in: [group])
        XCTAssertEqual(overdue, 3)
    }

    // MARK: - Calendar Day Boundary Tests (#152)

    func testDaysSinceLastTouchUsesCalendarDaysNotHours() {
        // Touch at 11 PM yesterday, check at 8 AM today → should be 1 day, not 0
        let cal = Calendar.current
        let todayAt8AM = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let yesterdayAt11PM = cal.date(byAdding: .hour, value: -9, to: todayAt8AM)!

        let groupId = UUID()
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Eve",
            initials: "E",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: yesterdayAt11PM,
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
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )

        let days = FrequencyCalculator(referenceDate: todayAt8AM).daysSinceLastTouch(for: person)
        XCTAssertEqual(days, 1, "Touch yesterday at 11 PM should count as 1 calendar day ago, not 0")
    }

    func testDaysSinceLastTouchSameCalendarDayIsZero() {
        // Touch at 1 AM, check at 11 PM same day → should be 0
        let cal = Calendar.current
        let todayAt1AM = cal.date(bySettingHour: 1, minute: 0, second: 0, of: Date())!
        let todayAt11PM = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!

        let groupId = UUID()
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Sam",
            initials: "S",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: todayAt1AM,
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
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )

        let days = FrequencyCalculator(referenceDate: todayAt11PM).daysSinceLastTouch(for: person)
        XCTAssertEqual(days, 0, "Touch earlier same calendar day should count as 0 days ago")
    }

    func testStatusUsesCalendarDaysForOverdueCheck() {
        // Touch at 11 PM, 7 days later at 8 AM → only ~6.4 24-hour periods
        // but 7 calendar days → should be overdue for a 7-day frequency
        let cal = Calendar.current
        let touchDate = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        let referenceDate = cal.date(byAdding: .day, value: 7, to: cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!)!

        let groupId = UUID()
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Alex",
            initials: "A",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: touchDate,
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
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())

        let status = FrequencyCalculator(referenceDate: referenceDate).status(for: person, in: [group])
        XCTAssertEqual(status, .overdue, "7 calendar days should trigger overdue even if fewer than 7×24 hours elapsed")
    }

    // MARK: - Custom Due Date Tests (#9)

    func testCustomDueDatePastIsOverdue() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        let lastTouch = cal.date(byAdding: .day, value: -3, to: now)!
        let customDue = cal.date(byAdding: .day, value: -1, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, lastTouchAt: lastTouch, customDueDate: customDue)
        let group = Group(id: groupId, name: "Monthly", frequencyDays: 30, warningDays: 5, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        let calc = FrequencyCalculator(referenceDate: now)
        XCTAssertEqual(calc.status(for: person, in: [group]), .overdue)
        XCTAssertEqual(calc.daysOverdue(for: person, in: [group]), 1)
    }

    func testCustomDueDateInWarningWindowIsDueSoon() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        let lastTouch = cal.date(byAdding: .day, value: -3, to: now)!
        let customDue = cal.date(byAdding: .day, value: 2, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, lastTouchAt: lastTouch, customDueDate: customDue)
        let group = Group(id: groupId, name: "Monthly", frequencyDays: 30, warningDays: 5, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        let status = FrequencyCalculator(referenceDate: now).status(for: person, in: [group])
        XCTAssertEqual(status, .dueSoon)
    }

    func testCustomDueDateSoonerThanGroupTakesPrecedence() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        // Last touch 3 days ago, group says due in 7 days (4 remaining)
        let lastTouch = cal.date(byAdding: .day, value: -3, to: now)!
        // Custom due date is tomorrow — sooner than group due date
        let customDue = cal.date(byAdding: .day, value: 1, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, lastTouchAt: lastTouch, customDueDate: customDue)
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        let status = FrequencyCalculator(referenceDate: now).status(for: person, in: [group])
        XCTAssertEqual(status, .dueSoon, "Custom due date tomorrow should override group due date (4 days remaining)")
    }

    func testCustomDueDateFullyOverridesGroupFrequency() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        // Last touch 8 days ago — would be overdue for 7-day group
        let lastTouch = cal.date(byAdding: .day, value: -8, to: now)!
        // Custom due date far in the future — fully replaces group frequency
        let customDue = cal.date(byAdding: .day, value: 30, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, lastTouchAt: lastTouch, customDueDate: customDue)
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        let status = FrequencyCalculator(referenceDate: now).status(for: person, in: [group])
        XCTAssertEqual(status, .onTrack, "Custom due date fully overrides group frequency — 30 days out means on track")
    }

    func testNoLastTouchWithCustomDueDateDerivesStatus() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        let customDue = cal.date(byAdding: .day, value: -2, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, customDueDate: customDue)
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        let calc = FrequencyCalculator(referenceDate: now)
        XCTAssertEqual(calc.status(for: person, in: [group]), .overdue)
        XCTAssertEqual(calc.daysOverdue(for: person, in: [group]), 2)
    }

    func testPausedWithCustomDueDateStillOnTrack() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        let customDue = cal.date(byAdding: .day, value: -5, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, isPaused: true, customDueDate: customDue)
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        XCTAssertEqual(FrequencyCalculator(referenceDate: now).status(for: person, in: [group]), .onTrack)
    }

    func testSnoozedWithCustomDueDateStillOnTrack() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        let customDue = cal.date(byAdding: .day, value: -5, to: now)!
        let snoozedUntil = cal.date(byAdding: .day, value: 3, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, snoozedUntil: snoozedUntil, customDueDate: customDue)
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        XCTAssertEqual(FrequencyCalculator(referenceDate: now).status(for: person, in: [group]), .onTrack)
    }

    func testEffectiveDueDateReturnsCustomDateWhenSet() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        let lastTouch = cal.date(byAdding: .day, value: -3, to: now)!
        // Custom due is later than group due — custom still wins (full override)
        let customDue = cal.date(byAdding: .day, value: 20, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, lastTouchAt: lastTouch, customDueDate: customDue)
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        let calc = FrequencyCalculator(referenceDate: now)
        let dueDate = calc.effectiveDueDate(for: person, in: [group])
        XCTAssertNotNil(dueDate)
        XCTAssertEqual(cal.startOfDay(for: dueDate!), cal.startOfDay(for: customDue),
                        "Custom due date should be returned regardless of group frequency")
    }

    func testCustomDueDateFullyOverridesFrequencyWhenOverdue() {
        let now = Date()
        let cal = Calendar.current
        let groupId = UUID()
        // Last touch 14 days ago — way overdue for 7-day group
        let lastTouch = cal.date(byAdding: .day, value: -14, to: now)!
        // Custom due date 10 days out — this IS the due date now
        let customDue = cal.date(byAdding: .day, value: 10, to: now)!

        let person = TestFactory.makePerson(groupId: groupId, lastTouchAt: lastTouch, customDueDate: customDue)
        let group = Group(id: groupId, name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: now, modifiedAt: now)

        let calc = FrequencyCalculator(referenceDate: now)
        XCTAssertEqual(calc.status(for: person, in: [group]), .onTrack,
                        "Person overdue by frequency but custom due date 10 days out should show on track")
        XCTAssertEqual(calc.daysOverdue(for: person, in: [group]), 0,
                        "No days overdue when custom due date is in the future")
    }
}
