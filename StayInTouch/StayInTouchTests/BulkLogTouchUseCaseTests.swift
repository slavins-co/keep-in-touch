//
//  BulkLogTouchUseCaseTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class BulkLogTouchUseCaseTests: XCTestCase {

    private var personRepo: MockPersonRepository!
    private var touchRepo: MockTouchEventRepository!
    private var sut: BulkLogTouchUseCase!

    override func setUp() {
        super.setUp()
        personRepo = MockPersonRepository()
        touchRepo = MockTouchEventRepository()
        sut = BulkLogTouchUseCase(personRepository: personRepo, touchEventRepository: touchRepo)
    }

    // MARK: - Happy path

    func testExecuteWritesOneTouchEventPerPerson() throws {
        let p1 = TestFactory.makePerson(name: "Alice")
        let p2 = TestFactory.makePerson(name: "Bob")
        let p3 = TestFactory.makePerson(name: "Carol")
        try personRepo.batchSave([p1, p2, p3])

        let result = try sut.execute(
            personIds: [p1.id, p2.id, p3.id],
            method: .irl,
            notes: "Dinner",
            date: Date()
        )

        XCTAssertEqual(result.touchEventsWritten, 3)
        XCTAssertEqual(result.peopleUpdated, 3)
        XCTAssertEqual(touchRepo.events.count, 3)
        XCTAssertTrue(result.skippedPersonIds.isEmpty)
    }

    func testExecuteUpdatesDenormalizedLastTouchFields() throws {
        let person = TestFactory.makePerson(name: "Alice")
        try personRepo.save(person)
        let date = Date()

        _ = try sut.execute(
            personIds: [person.id],
            method: .call,
            notes: "Catch up",
            date: date
        )

        let updated = personRepo.fetch(id: person.id)
        XCTAssertEqual(updated?.lastTouchAt, date)
        XCTAssertEqual(updated?.lastTouchMethod, .call)
        XCTAssertEqual(updated?.lastTouchNotes, "Catch up")
    }

    // MARK: - Newest-wins rule

    func testBackDatedTouchDoesNotOverwriteNewerHeadline() throws {
        let newerDate = Date()
        let olderDate = Calendar.current.date(byAdding: .day, value: -7, to: newerDate)!

        var person = TestFactory.makePerson(name: "Alice", lastTouchAt: newerDate, lastTouchMethod: .text)
        person.lastTouchNotes = "Recent solo touch"
        try personRepo.save(person)

        _ = try sut.execute(
            personIds: [person.id],
            method: .irl,
            notes: "Back-dated dinner",
            date: olderDate
        )

        let updated = personRepo.fetch(id: person.id)
        XCTAssertEqual(updated?.lastTouchAt, newerDate, "Headline lastTouchAt must remain the newer date")
        XCTAssertEqual(updated?.lastTouchMethod, .text, "Headline method must remain the newer one")
        XCTAssertEqual(updated?.lastTouchNotes, "Recent solo touch", "Headline notes must remain the newer one")
        XCTAssertEqual(touchRepo.events.count, 1, "TouchEvent still written for timeline visibility")
    }

    func testNewerTouchOverwritesOlderHeadline() throws {
        let olderDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let newerDate = Date()

        let person = TestFactory.makePerson(name: "Alice", lastTouchAt: olderDate, lastTouchMethod: .text)
        try personRepo.save(person)

        _ = try sut.execute(
            personIds: [person.id],
            method: .irl,
            notes: "Fresh dinner",
            date: newerDate
        )

        let updated = personRepo.fetch(id: person.id)
        XCTAssertEqual(updated?.lastTouchAt, newerDate)
        XCTAssertEqual(updated?.lastTouchMethod, .irl)
        XCTAssertEqual(updated?.lastTouchNotes, "Fresh dinner")
    }

    func testTouchAgainstNilLastTouchAlwaysWritesHeadline() throws {
        let person = TestFactory.makePerson(name: "New friend")
        XCTAssertNil(person.lastTouchAt)
        try personRepo.save(person)

        let date = Date()
        _ = try sut.execute(
            personIds: [person.id],
            method: .text,
            notes: nil,
            date: date
        )

        let updated = personRepo.fetch(id: person.id)
        XCTAssertEqual(updated?.lastTouchAt, date)
    }

    // MARK: - Missing-person handling

    func testMissingPersonIsSkippedAndReturnedInResult() throws {
        let p1 = TestFactory.makePerson(name: "Alice")
        try personRepo.save(p1)
        let ghostId = UUID()

        let result = try sut.execute(
            personIds: [p1.id, ghostId],
            method: .irl,
            notes: nil,
            date: Date()
        )

        XCTAssertEqual(result.touchEventsWritten, 1)
        XCTAssertEqual(result.skippedPersonIds, [ghostId])
        XCTAssertEqual(touchRepo.events.count, 1)
    }

    func testAllPersonsMissingProducesEmptyResultWithoutThrowing() throws {
        let result = try sut.execute(
            personIds: [UUID(), UUID()],
            method: .irl,
            notes: nil,
            date: Date()
        )

        XCTAssertEqual(result.touchEventsWritten, 0)
        XCTAssertEqual(result.skippedPersonIds.count, 2)
        XCTAssertTrue(touchRepo.events.isEmpty)
    }

    // MARK: - Snooze / custom due date clearing

    func testSnoozeIsClearedOnlyWhenHeadlineActuallyChanges() throws {
        let future = Date().addingTimeInterval(86_400 * 5)
        let now = Date()

        var withSnooze = TestFactory.makePerson(name: "Snoozed", snoozedUntil: future)
        try personRepo.save(withSnooze)
        _ = try sut.execute(personIds: [withSnooze.id], method: .text, notes: nil, date: now)
        XCTAssertNil(personRepo.fetch(id: withSnooze.id)?.snoozedUntil, "New headline clears snooze")

        let backDate = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        var futureSnoozed = TestFactory.makePerson(name: "Snoozed 2", lastTouchAt: now, snoozedUntil: future)
        try personRepo.save(futureSnoozed)
        _ = try sut.execute(personIds: [futureSnoozed.id], method: .text, notes: nil, date: backDate)
        XCTAssertEqual(personRepo.fetch(id: futureSnoozed.id)?.snoozedUntil, future,
                       "Back-dated touch must NOT silently wipe a future snooze")
    }

    // MARK: - applyTouch helper

    func testApplyTouchHelperRespectsNewestWins() {
        let now = Date()
        let older = now.addingTimeInterval(-86_400)
        let person = TestFactory.makePerson(name: "Alice", lastTouchAt: now, lastTouchMethod: .text)
        let backDatedEvent = TestFactory.makeTouchEvent(personId: person.id, at: older, method: .call)

        let result = BulkLogTouchUseCase.applyTouch(to: person, event: backDatedEvent, now: now)

        XCTAssertEqual(result.lastTouchAt, now)
        XCTAssertEqual(result.lastTouchMethod, .text)
    }
}
