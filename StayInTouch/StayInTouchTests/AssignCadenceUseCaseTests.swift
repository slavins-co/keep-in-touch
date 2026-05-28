//
//  AssignCadenceUseCaseTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class AssignCadenceUseCaseTests: XCTestCase {
    func testAssignUpdatesGroupAndGroupAddedAt() {
        let now = Date()
        let useCase = AssignCadenceUseCase(referenceDate: now)
        let original = makePerson(cadenceId: UUID(), cadenceAddedAt: nil)
        let newGroupId = UUID()

        let updated = useCase.assign(person: original, to: newGroupId)

        XCTAssertEqual(updated.cadenceId, newGroupId)
        XCTAssertEqual(updated.cadenceAddedAt, now)
        XCTAssertEqual(updated.modifiedAt, now)
    }

    func testAssignSameGroupSetsGroupAddedAtIfMissing() {
        let now = Date()
        let cadenceId = UUID()
        let useCase = AssignCadenceUseCase(referenceDate: now)
        let original = makePerson(cadenceId: cadenceId, cadenceAddedAt: nil)

        let updated = useCase.assign(person: original, to: cadenceId)

        XCTAssertEqual(updated.cadenceAddedAt, now)
    }

    func testAssignSameGroupKeepsExistingGroupAddedAt() {
        let now = Date()
        let existing = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let cadenceId = UUID()
        let useCase = AssignCadenceUseCase(referenceDate: now)
        let original = makePerson(cadenceId: cadenceId, cadenceAddedAt: existing)

        let updated = useCase.assign(person: original, to: cadenceId)

        XCTAssertEqual(updated.cadenceAddedAt, existing)
    }

    private func makePerson(cadenceId: UUID, cadenceAddedAt: Date?) -> Person {
        Person(
            identity: Person.Identity(id: UUID(), displayName: "Person", initials: "P", avatarColor: "#FF6B6B"),
            cadenceId: cadenceId,
            groupIds: [],
            isPaused: false,
            isTracked: true,
            touchState: Person.TouchState(cadenceAddedAt: cadenceAddedAt),
            notifications: Person.NotificationConfig(notificationsMuted: false, birthdayNotificationsEnabled: true),
            metadata: Person.Metadata(contactUnavailable: false, isDemoData: false, createdAt: Date(), modifiedAt: Date(), sortOrder: 0)
        )
    }
}
