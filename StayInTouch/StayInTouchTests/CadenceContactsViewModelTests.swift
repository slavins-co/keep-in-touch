//
//  CadenceContactsViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class CadenceContactsViewModelTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var cadenceRepo: MockCadenceRepository!
    private var sut: CadenceContactsViewModel!

    private var currentGroup: Cadence!
    private var otherGroup: Cadence!

    override func setUp() {
        super.setUp()
        personRepo = MockPersonRepository()
        cadenceRepo = MockCadenceRepository()

        currentGroup = TestFactory.makeCadence(id: UUID(), name: "Weekly")
        otherGroup = TestFactory.makeCadence(id: UUID(), name: "Monthly", frequencyDays: 30, isDefault: false)

        cadenceRepo.cadences = [currentGroup, otherGroup]

        // Two people in currentGroup, one in otherGroup
        personRepo.people = [
            TestFactory.makePerson(name: "Alice", cadenceId: currentGroup.id),
            TestFactory.makePerson(name: "Bob", cadenceId: currentGroup.id),
            TestFactory.makePerson(name: "Charlie", cadenceId: otherGroup.id)
        ]

        sut = CadenceContactsViewModel(
            cadence: currentGroup,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo
        )
    }

    // MARK: - Load

    func testLoadSplitsByGroup() {
        XCTAssertEqual(sut.people.count, 2, "Should have 2 people in currentGroup")
        XCTAssertEqual(sut.available.count, 1, "Should have 1 person available from otherGroup")
    }

    func testLoadPopulatesOtherGroups() {
        let thirdGroup = TestFactory.makeCadence(id: UUID(), name: "Quarterly", frequencyDays: 90, isDefault: false)
        cadenceRepo.cadences = [currentGroup, otherGroup, thirdGroup]

        sut.load()

        XCTAssertEqual(sut.otherCadences.count, 2, "Should list 2 other groups excluding current")
        XCTAssertFalse(sut.otherCadences.contains(where: { $0.id == currentGroup.id }),
                       "Current group should not appear in otherGroups")
    }

    func testOtherGroupsSortOrder() {
        // Create 3 other groups with varying isDefault and sortOrder
        var nonDefaultHigh = TestFactory.makeCadence(id: UUID(), name: "NonDefaultHigh", isDefault: false)
        nonDefaultHigh.sortOrder = 2

        var defaultMiddle = TestFactory.makeCadence(id: UUID(), name: "DefaultMiddle")
        defaultMiddle.sortOrder = 1

        var nonDefaultLow = TestFactory.makeCadence(id: UUID(), name: "NonDefaultLow", isDefault: false)
        nonDefaultLow.sortOrder = 0

        cadenceRepo.cadences = [currentGroup, nonDefaultHigh, defaultMiddle, nonDefaultLow]

        sut.load()

        XCTAssertEqual(sut.otherCadences.count, 3)
        // Default comes first, then non-default sorted by sortOrder (0 before 2)
        XCTAssertEqual(sut.otherCadences[0].name, "DefaultMiddle")
        XCTAssertEqual(sut.otherCadences[1].name, "NonDefaultLow")
        XCTAssertEqual(sut.otherCadences[2].name, "NonDefaultHigh")
    }

    // MARK: - movePerson

    func testMovePersonChangesGroupId() throws {
        let person = sut.people[0]

        sut.movePerson(person, to: otherGroup.id)

        let lastSaved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertEqual(lastSaved.cadenceId, otherGroup.id, "Moved person should have otherGroup's id")
    }

    func testMovePersonSetsGroupAddedAt() throws {
        let person = sut.people[0]

        sut.movePerson(person, to: otherGroup.id)

        let lastSaved = try XCTUnwrap(personRepo.savedPersons.last)
        let cadenceAddedAt = try XCTUnwrap(lastSaved.cadenceAddedAt)
        XCTAssertTrue(abs(cadenceAddedAt.timeIntervalSinceNow) < 1,
                      "cadenceAddedAt should be within the last second")
    }

    func testMovePersonSavesToRepo() {
        let person = sut.people[0]

        sut.movePerson(person, to: otherGroup.id)

        XCTAssertFalse(personRepo.savedPersons.isEmpty, "movePerson should save to repository")
    }

    func testMovePersonPostsNotification() {
        let person = sut.people[0]
        let expectation = expectation(forNotification: .personDidChange, object: nil)

        sut.movePerson(person, to: otherGroup.id)

        wait(for: [expectation], timeout: 1.0)
    }

    func testMovePersonReloadsLists() {
        let person = sut.people[0]
        XCTAssertTrue(sut.people.contains(where: { $0.id == person.id }),
                      "Person should start in people list")

        sut.movePerson(person, to: otherGroup.id)

        XCTAssertFalse(sut.people.contains(where: { $0.id == person.id }),
                       "Person should no longer be in people list after move")
        XCTAssertTrue(sut.available.contains(where: { $0.id == person.id }),
                      "Person should now be in available list after move")
    }

    // MARK: - addPeople

    func testAddPeopleAssignsToGroup() throws {
        let person = sut.available[0]

        let saveCountBefore = personRepo.savedPersons.count
        sut.addPeople([person.id])

        let newSaves = Array(personRepo.savedPersons.dropFirst(saveCountBefore))
        let lastSaved = try XCTUnwrap(newSaves.last)
        XCTAssertEqual(lastSaved.cadenceId, currentGroup.id,
                       "Added person should be assigned to currentGroup")
    }

    func testAddPeopleSavesEachPerson() {
        // Set up 2 people in otherGroup
        let person1 = TestFactory.makePerson(name: "Dave", cadenceId: otherGroup.id)
        let person2 = TestFactory.makePerson(name: "Eve", cadenceId: otherGroup.id)
        personRepo.people = [
            TestFactory.makePerson(name: "Alice", cadenceId: currentGroup.id),
            person1,
            person2
        ]
        sut.load()

        let saveCountBefore = personRepo.savedPersons.count
        sut.addPeople([person1.id, person2.id])

        let newSaves = Array(personRepo.savedPersons.dropFirst(saveCountBefore))
        XCTAssertEqual(newSaves.count, 2, "Should save exactly 2 people from addPeople")
    }

    func testAddPeopleIgnoresUnknownIds() {
        let saveCountBefore = personRepo.savedPersons.count

        sut.addPeople([UUID()])

        let newSaves = Array(personRepo.savedPersons.dropFirst(saveCountBefore))
        XCTAssertTrue(newSaves.isEmpty, "Unknown UUID should not produce any saves")
    }
}
