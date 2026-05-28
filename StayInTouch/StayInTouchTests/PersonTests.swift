//
//  PersonTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class PersonTests: XCTestCase {

    // MARK: - Nested-struct initializer field mapping (#318)

    /// Locks the nested-config-struct initializer: every grouped field must
    /// flow into the matching flat stored property. A regression here means a
    /// field was wired to the wrong slot during the 28-param init refactor.
    func testNestedStructInitMapsEveryFieldToCorrectStoredProperty() {
        let id = UUID()
        let cadenceId = UUID()
        let groupIdA = UUID()
        let groupIdB = UUID()
        let lastTouchAt = Date(timeIntervalSince1970: 1_000)
        let snoozedUntil = Date(timeIntervalSince1970: 2_000)
        let customDueDate = Date(timeIntervalSince1970: 3_000)
        let cadenceAddedAt = Date(timeIntervalSince1970: 4_000)
        let createdAt = Date(timeIntervalSince1970: 5_000)
        let modifiedAt = Date(timeIntervalSince1970: 6_000)
        let breachTime = LocalTime(hour: 9, minute: 30)
        let birthday = Birthday(month: 7, day: 4, year: 1990)

        let person = Person(
            identity: Person.Identity(
                id: id,
                cnIdentifier: "cn-123",
                displayName: "Jordan Vega",
                nickname: "Jay",
                initials: "JV",
                avatarColor: "#0A84FF"
            ),
            cadenceId: cadenceId,
            groupIds: [groupIdA, groupIdB],
            isPaused: true,
            isTracked: false,
            birthday: birthday,
            touchState: Person.TouchState(
                lastTouchAt: lastTouchAt,
                lastTouchMethod: .call,
                lastTouchNotes: "Talked about hiking",
                nextTouchNotes: "Ask about new job",
                snoozedUntil: snoozedUntil,
                customDueDate: customDueDate,
                cadenceAddedAt: cadenceAddedAt
            ),
            notifications: Person.NotificationConfig(
                notificationsMuted: true,
                customBreachTime: breachTime,
                birthdayNotificationsEnabled: false,
                preferredMessenger: .whatsapp
            ),
            metadata: Person.Metadata(
                contactUnavailable: true,
                isDemoData: true,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                sortOrder: 42
            )
        )

        // Identity
        XCTAssertEqual(person.id, id)
        XCTAssertEqual(person.cnIdentifier, "cn-123")
        XCTAssertEqual(person.displayName, "Jordan Vega")
        XCTAssertEqual(person.nickname, "Jay")
        XCTAssertEqual(person.initials, "JV")
        XCTAssertEqual(person.avatarColor, "#0A84FF")
        // Top-level behavioral
        XCTAssertEqual(person.cadenceId, cadenceId)
        XCTAssertEqual(person.groupIds, [groupIdA, groupIdB])
        XCTAssertTrue(person.isPaused)
        XCTAssertFalse(person.isTracked)
        XCTAssertEqual(person.birthday, birthday)
        // TouchState
        XCTAssertEqual(person.lastTouchAt, lastTouchAt)
        XCTAssertEqual(person.lastTouchMethod, .call)
        XCTAssertEqual(person.lastTouchNotes, "Talked about hiking")
        XCTAssertEqual(person.nextTouchNotes, "Ask about new job")
        XCTAssertEqual(person.snoozedUntil, snoozedUntil)
        XCTAssertEqual(person.customDueDate, customDueDate)
        XCTAssertEqual(person.cadenceAddedAt, cadenceAddedAt)
        // NotificationConfig
        XCTAssertTrue(person.notificationsMuted)
        XCTAssertEqual(person.customBreachTime, breachTime)
        XCTAssertFalse(person.birthdayNotificationsEnabled)
        XCTAssertEqual(person.preferredMessenger, .whatsapp)
        // Metadata
        XCTAssertTrue(person.contactUnavailable)
        XCTAssertTrue(person.isDemoData)
        XCTAssertEqual(person.createdAt, createdAt)
        XCTAssertEqual(person.modifiedAt, modifiedAt)
        XCTAssertEqual(person.sortOrder, 42)
    }

    /// The nested-struct fields must carry the same defaults the old flat
    /// 28-param init used, so omitting them yields nil / the documented value.
    func testNestedStructInitDefaultsMatchLegacyInit() {
        let person = Person(
            identity: Person.Identity(
                id: UUID(),
                displayName: "Casey",
                initials: "C",
                avatarColor: "#FF6B6B"
            ),
            cadenceId: UUID(),
            groupIds: [],
            isPaused: false,
            isTracked: true,
            notifications: Person.NotificationConfig(
                notificationsMuted: false,
                birthdayNotificationsEnabled: true
            ),
            metadata: Person.Metadata(
                contactUnavailable: false,
                isDemoData: false,
                createdAt: Date(),
                modifiedAt: Date(),
                sortOrder: 0
            )
        )

        XCTAssertNil(person.cnIdentifier)
        XCTAssertNil(person.nickname)
        XCTAssertNil(person.birthday)
        XCTAssertNil(person.lastTouchAt)
        XCTAssertNil(person.lastTouchMethod)
        XCTAssertNil(person.lastTouchNotes)
        XCTAssertNil(person.nextTouchNotes)
        XCTAssertNil(person.snoozedUntil)
        XCTAssertNil(person.customDueDate)
        XCTAssertNil(person.cadenceAddedAt)
        XCTAssertNil(person.customBreachTime)
        XCTAssertNil(person.preferredMessenger)
    }

    // MARK: - displayNickname

    func testDisplayNicknameNilWhenNicknameIsNil() {
        let person = makePerson(displayName: "Robert Smith", nickname: nil)
        XCTAssertNil(person.displayNickname)
    }

    func testDisplayNicknameNilWhenNicknameIsEmpty() {
        let person = makePerson(displayName: "Robert Smith", nickname: "")
        XCTAssertNil(person.displayNickname)
    }

    func testDisplayNicknameNilWhenNicknameIsWhitespaceOnly() {
        let person = makePerson(displayName: "Robert Smith", nickname: "   \n\t ")
        XCTAssertNil(person.displayNickname)
    }

    func testDisplayNicknameNilWhenEqualToDisplayNameExactly() {
        let person = makePerson(displayName: "Robert", nickname: "Robert")
        XCTAssertNil(person.displayNickname)
    }

    func testDisplayNicknameNilWhenEqualToDisplayNameCaseInsensitive() {
        let person = makePerson(displayName: "Robert", nickname: "ROBERT")
        XCTAssertNil(person.displayNickname)
    }

    func testDisplayNicknameNilWhenEqualToDisplayNameAfterTrim() {
        let person = makePerson(displayName: "Robert", nickname: "  Robert  ")
        XCTAssertNil(person.displayNickname)
    }

    func testDisplayNicknameReturnsTrimmedValueWhenDifferent() {
        let person = makePerson(displayName: "Robert Smith", nickname: "  Bobby  ")
        XCTAssertEqual(person.displayNickname, "Bobby")
    }

    // MARK: - Helpers

    private func makePerson(displayName: String, nickname: String?) -> Person {
        let now = Date()
        return Person(
            identity: Person.Identity(
                id: UUID(),
                displayName: displayName,
                nickname: nickname,
                initials: String(displayName.prefix(1)),
                avatarColor: "#FF6B6B"
            ),
            cadenceId: UUID(),
            groupIds: [],
            isPaused: false,
            isTracked: true,
            notifications: Person.NotificationConfig(notificationsMuted: false, birthdayNotificationsEnabled: true),
            metadata: Person.Metadata(contactUnavailable: false, isDemoData: false, createdAt: now, modifiedAt: now, sortOrder: 0)
        )
    }
}
