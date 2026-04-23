//
//  PersonTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class PersonTests: XCTestCase {

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
            id: UUID(),
            cnIdentifier: nil,
            displayName: displayName,
            nickname: nickname,
            initials: String(displayName.prefix(1)),
            avatarColor: "#FF6B6B",
            cadenceId: UUID(),
            groupIds: [],
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
            cadenceAddedAt: nil,
            createdAt: now,
            modifiedAt: now,
            sortOrder: 0
        )
    }
}
