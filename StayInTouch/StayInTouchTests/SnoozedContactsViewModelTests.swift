//
//  SnoozedContactsViewModelTests.swift
//  KeepInTouchTests
//
//  Mirrors PausedContactsViewModelTests for the snoozed-contacts screen (#334).
//

import XCTest
@testable import StayInTouch

@MainActor
final class SnoozedContactsViewModelTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var sut: SnoozedContactsViewModel!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        personRepo = MockPersonRepository()
    }

    override func tearDown() {
        sut = nil
        personRepo = nil
        super.tearDown()
    }

    private func future() -> Date { now.addingTimeInterval(3 * 86_400) }
    private func past() -> Date { now.addingTimeInterval(-3 * 86_400) }

    // MARK: - Load

    func testLoadFetchesActiveSnoozesOnly() {
        personRepo.people = [
            TestFactory.makePerson(name: "Active Snooze", isTracked: true, snoozedUntil: future()),
            TestFactory.makePerson(name: "Expired Snooze", isTracked: true, snoozedUntil: past()),
            TestFactory.makePerson(name: "Not Snoozed", isTracked: true, snoozedUntil: nil)
        ]

        sut = SnoozedContactsViewModel(personRepository: personRepo, referenceDate: now)

        XCTAssertEqual(sut.people.count, 1)
        XCTAssertEqual(sut.people.first?.displayName, "Active Snooze")
    }

    func testLoadSortsByName() {
        personRepo.people = [
            TestFactory.makePerson(name: "Zara", isTracked: true, snoozedUntil: future()),
            TestFactory.makePerson(name: "Alice", isTracked: true, snoozedUntil: future())
        ]

        sut = SnoozedContactsViewModel(personRepository: personRepo, referenceDate: now)

        XCTAssertEqual(sut.people.map(\.displayName), ["Alice", "Zara"])
    }

    // MARK: - Unsnooze

    func testUnsnoozeClearsSnoozedUntil() throws {
        let person = TestFactory.makePerson(name: "Snoozed", isTracked: true, snoozedUntil: future())
        personRepo.people = [person]
        sut = SnoozedContactsViewModel(personRepository: personRepo, referenceDate: now)

        sut.unsnooze(person)

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertNil(saved.snoozedUntil)
    }

    func testBatchUnsnoozeClearsAllAndReloads() {
        let p1 = TestFactory.makePerson(name: "Alice", isTracked: true, snoozedUntil: future())
        let p2 = TestFactory.makePerson(name: "Bob", isTracked: true, snoozedUntil: future())
        personRepo.people = [p1, p2]
        sut = SnoozedContactsViewModel(personRepository: personRepo, referenceDate: now)
        XCTAssertEqual(sut.people.count, 2)

        sut.unsnooze([p1, p2])

        XCTAssertEqual(personRepo.savedPersons.count, 2)
        XCTAssertTrue(personRepo.savedPersons.allSatisfy { $0.snoozedUntil == nil })
        // After clearing, reload finds no active snoozes.
        XCTAssertTrue(sut.people.isEmpty)
    }
}
