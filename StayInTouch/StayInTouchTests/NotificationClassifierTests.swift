//
//  NotificationClassifierTests.swift
//  StayInTouchTests
//
//  Created by Codex on 2/3/26.
//

import XCTest
@testable import StayInTouch

final class NotificationClassifierTests: XCTestCase {
    func testMutedPeopleAreExcluded() {
        let groupId = UUID()
        let group = Group(id: groupId, name: "Weekly", slaDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let reference = Date()

        let muted = makePerson(groupId: groupId, daysAgo: 10, muted: true)
        let overdue = makePerson(groupId: groupId, daysAgo: 10)

        let result = NotificationClassifier.classify(people: [muted, overdue], groups: [group], referenceDate: reference)
        XCTAssertEqual(result.overdue.count, 1)
        XCTAssertFalse(result.overdue.contains(where: { $0.id == muted.id }))
    }

    func testCustomTimeRemovedFromGroupedLists() {
        let groupId = UUID()
        let group = Group(id: groupId, name: "Weekly", slaDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        let reference = Date()

        var custom = makePerson(groupId: groupId, daysAgo: 10)
        custom.customBreachTime = LocalTime(hour: 9, minute: 0)

        let result = NotificationClassifier.classify(people: [custom], groups: [group], referenceDate: reference)
        XCTAssertEqual(result.customOverrides.count, 1)
        XCTAssertTrue(result.overdue.isEmpty)
        XCTAssertTrue(result.allNonCustom.isEmpty)
        XCTAssertEqual(result.allOverdue.count, 1)
    }

    func testUnknownLastTouchIsExcluded() {
        let groupId = UUID()
        let group = Group(id: groupId, name: "Weekly", slaDays: 7, warningDays: 2, colorHex: nil, isDefault: true, sortOrder: 0, createdAt: Date(), modifiedAt: Date())
        var person = makePerson(groupId: groupId, daysAgo: nil)
        person.lastTouchAt = nil
        person.groupAddedAt = nil

        let result = NotificationClassifier.classify(people: [person], groups: [group], referenceDate: Date())
        XCTAssertTrue(result.allForDigest.isEmpty)
    }

    private func makePerson(groupId: UUID, daysAgo: Int?, muted: Bool = false) -> Person {
        let reference = Date()
        let lastTouch = daysAgo.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: reference) }
        return Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Test",
            initials: "T",
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: [],
            lastTouchAt: lastTouch,
            lastTouchMethod: .text,
            lastTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: muted,
            customBreachTime: nil,
            groupAddedAt: lastTouch,
            createdAt: reference,
            modifiedAt: reference,
            sortOrder: 0
        )
    }
}
