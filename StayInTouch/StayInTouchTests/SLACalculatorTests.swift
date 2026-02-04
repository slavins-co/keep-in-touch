//
//  SLACalculatorTests.swift
//  StayInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class SLACalculatorTests: XCTestCase {
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
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            groupAddedAt: nil,
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", slaDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let status = SLACalculator(referenceDate: Date()).status(for: person, in: [group])
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
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            groupAddedAt: start,
            createdAt: start,
            modifiedAt: start,
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", slaDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: start, modifiedAt: start)
        let status = SLACalculator(referenceDate: reference).status(for: person, in: [group])
        XCTAssertEqual(status, .outOfSLA)
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
            isPaused: true,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            groupAddedAt: nil,
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", slaDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let status = SLACalculator(referenceDate: Date()).status(for: person, in: [group])
        XCTAssertEqual(status, .inSLA)
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
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            groupAddedAt: start,
            createdAt: start,
            modifiedAt: start,
            sortOrder: 0
        )
        let group = Group(id: groupId, name: "Weekly", slaDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: start, modifiedAt: start)
        let overdue = SLACalculator(referenceDate: reference).daysOverdue(for: person, in: [group])
        XCTAssertEqual(overdue, 3)
    }
}
