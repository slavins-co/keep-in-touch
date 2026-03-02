//
//  AssignGroupUseCaseTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class AssignGroupUseCaseTests: XCTestCase {
    func testAssignUpdatesGroupAndGroupAddedAt() {
        let now = Date()
        let useCase = AssignGroupUseCase(referenceDate: now)
        let original = makePerson(groupId: UUID(), groupAddedAt: nil)
        let newGroupId = UUID()

        let updated = useCase.assign(person: original, to: newGroupId)

        XCTAssertEqual(updated.groupId, newGroupId)
        XCTAssertEqual(updated.groupAddedAt, now)
        XCTAssertEqual(updated.modifiedAt, now)
    }

    func testAssignSameGroupSetsGroupAddedAtIfMissing() {
        let now = Date()
        let groupId = UUID()
        let useCase = AssignGroupUseCase(referenceDate: now)
        let original = makePerson(groupId: groupId, groupAddedAt: nil)

        let updated = useCase.assign(person: original, to: groupId)

        XCTAssertEqual(updated.groupAddedAt, now)
    }

    func testAssignSameGroupKeepsExistingGroupAddedAt() {
        let now = Date()
        let existing = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let groupId = UUID()
        let useCase = AssignGroupUseCase(referenceDate: now)
        let original = makePerson(groupId: groupId, groupAddedAt: existing)

        let updated = useCase.assign(person: original, to: groupId)

        XCTAssertEqual(updated.groupAddedAt, existing)
    }

    private func makePerson(groupId: UUID, groupAddedAt: Date?) -> Person {
        Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Person",
            initials: "P",
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
            birthday: nil,
            contactUnavailable: false,
            isDemoData: false,
            groupAddedAt: groupAddedAt,
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
    }
}
