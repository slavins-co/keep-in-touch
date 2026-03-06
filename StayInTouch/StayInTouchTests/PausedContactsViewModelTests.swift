//
//  PausedContactsViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class PausedContactsViewModelTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var sut: PausedContactsViewModel!

    override func setUp() {
        super.setUp()
        personRepo = MockPersonRepository()
    }

    override func tearDown() {
        sut = nil
        personRepo = nil
        super.tearDown()
    }

    // MARK: - Load

    func testLoadFetchesPausedOnly() {
        // 3 people: paused+tracked, active+tracked, paused+untracked
        personRepo.people = [
            TestFactory.makePerson(name: "Paused Tracked", isPaused: true, isTracked: true),
            TestFactory.makePerson(name: "Active Tracked", isPaused: false, isTracked: true),
            TestFactory.makePerson(name: "Paused Untracked", isPaused: true, isTracked: false)
        ]

        sut = PausedContactsViewModel(personRepository: personRepo)

        XCTAssertEqual(sut.people.count, 1)
        XCTAssertEqual(sut.people.first?.displayName, "Paused Tracked")
    }

    func testLoadSortsByName() {
        personRepo.people = [
            TestFactory.makePerson(name: "Zara", isPaused: true, isTracked: true),
            TestFactory.makePerson(name: "Alice", isPaused: true, isTracked: true)
        ]

        sut = PausedContactsViewModel(personRepository: personRepo)

        XCTAssertEqual(sut.people.count, 2)
        XCTAssertEqual(sut.people[0].displayName, "Alice")
        XCTAssertEqual(sut.people[1].displayName, "Zara")
    }

    // MARK: - Single Resume

    func testResumeSetsIsPausedFalse() throws {
        let person = TestFactory.makePerson(name: "Paused", isPaused: true, isTracked: true)
        personRepo.people = [person]
        sut = PausedContactsViewModel(personRepository: personRepo)

        sut.resume(person, lastTouchAt: nil)

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertFalse(saved.isPaused)
    }

    func testResumeSetsLastTouchAtWhenProvided() throws {
        let person = TestFactory.makePerson(name: "Paused", isPaused: true, isTracked: true)
        personRepo.people = [person]
        sut = PausedContactsViewModel(personRepository: personRepo)

        let touchDate = Date(timeIntervalSince1970: 1_700_000_000)
        sut.resume(person, lastTouchAt: touchDate)

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertEqual(saved.lastTouchAt, touchDate)
    }

    func testResumeKeepsLastTouchAtWhenNil() throws {
        let originalDate = Date(timeIntervalSince1970: 1_600_000_000)
        let person = TestFactory.makePerson(
            name: "Paused",
            lastTouchAt: originalDate,
            isPaused: true,
            isTracked: true
        )
        personRepo.people = [person]
        sut = PausedContactsViewModel(personRepository: personRepo)

        sut.resume(person, lastTouchAt: nil)

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertEqual(saved.lastTouchAt, originalDate)
    }

    func testResumeSavesToRepo() {
        let person = TestFactory.makePerson(name: "Paused", isPaused: true, isTracked: true)
        personRepo.people = [person]
        sut = PausedContactsViewModel(personRepository: personRepo)

        sut.resume(person, lastTouchAt: nil)

        XCTAssertFalse(personRepo.savedPersons.isEmpty)
    }

    // MARK: - Batch Resume

    func testResumeBatchResumesAll() {
        let person1 = TestFactory.makePerson(name: "Alice", isPaused: true, isTracked: true)
        let person2 = TestFactory.makePerson(name: "Bob", isPaused: true, isTracked: true)
        personRepo.people = [person1, person2]
        sut = PausedContactsViewModel(personRepository: personRepo)

        sut.resume([person1, person2], lastTouchAt: nil)

        XCTAssertEqual(personRepo.savedPersons.count, 2)
        XCTAssertTrue(personRepo.savedPersons.allSatisfy { !$0.isPaused })
    }

    func testResumeBatchCallsLoad() {
        let person1 = TestFactory.makePerson(name: "Alice", isPaused: true, isTracked: true)
        let person2 = TestFactory.makePerson(name: "Bob", isPaused: true, isTracked: true)
        personRepo.people = [person1, person2]
        sut = PausedContactsViewModel(personRepository: personRepo)

        // Before batch resume, both are paused so sut.people has 2
        XCTAssertEqual(sut.people.count, 2)

        // Batch resume sets isPaused=false in mock repo, then calls load()
        // load() fetches tracked+paused, filters isPaused == true -> none left
        sut.resume([person1, person2], lastTouchAt: nil)

        XCTAssertTrue(sut.people.isEmpty)
    }
}
