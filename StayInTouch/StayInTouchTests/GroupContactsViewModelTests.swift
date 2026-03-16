//
//  GroupContactsViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class GroupContactsViewModelTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var group: Group!
    private var otherGroupId: UUID!
    private var cadenceId: UUID!
    private var sut: GroupContactsViewModel!

    override func setUp() {
        super.setUp()
        personRepo = MockPersonRepository()
        group = TestFactory.makeGroup(id: UUID(), name: "Work")
        otherGroupId = UUID()
        cadenceId = UUID()
    }

    /// Helper: create the SUT after configuring personRepo.people.
    /// The init calls load(), so people must be set first.
    private func makeSUT() {
        sut = GroupContactsViewModel(group: group, personRepository: personRepo)
    }

    // MARK: - Load

    func testLoadSplitsPeopleByGroup() {
        let grouped = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        let ungrouped = TestFactory.makePerson(name: "Bob", cadenceId: cadenceId, groupIds: [])
        personRepo.people = [grouped, ungrouped]

        makeSUT()

        XCTAssertEqual(sut.people.count, 1)
        XCTAssertEqual(sut.people.first?.id, grouped.id)
        XCTAssertEqual(sut.available.count, 1)
        XCTAssertEqual(sut.available.first?.id, ungrouped.id)
    }

    func testLoadSortsByName() {
        let charlie = TestFactory.makePerson(name: "Charlie", cadenceId: cadenceId, groupIds: [group.id])
        let alice = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        let bob = TestFactory.makePerson(name: "Bob", cadenceId: cadenceId, groupIds: [])
        personRepo.people = [charlie, alice, bob]

        makeSUT()

        XCTAssertEqual(sut.people.map(\.displayName), ["Alice", "Charlie"])
        XCTAssertEqual(sut.available.map(\.displayName), ["Bob"])
    }

    // MARK: - Remove Group

    func testRemoveGroupRemovesGroupIdFromPerson() throws {
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id, otherGroupId])
        personRepo.people = [person]

        makeSUT()

        let groupedPerson = try XCTUnwrap(sut.people.first)
        sut.removeGroup(from: groupedPerson)

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertEqual(saved.groupIds, [otherGroupId])
    }

    func testRemoveGroupSavesToRepo() throws {
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        personRepo.people = [person]

        makeSUT()

        let groupedPerson = try XCTUnwrap(sut.people.first)
        sut.removeGroup(from: groupedPerson)

        XCTAssertFalse(personRepo.savedPersons.isEmpty, "removeGroup should save the updated person to the repository")
    }

    func testRemoveGroupPostsNotification() throws {
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        personRepo.people = [person]

        makeSUT()

        let groupedPerson = try XCTUnwrap(sut.people.first)

        let expectation = expectation(forNotification: .personDidChange, object: nil)

        sut.removeGroup(from: groupedPerson)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRemoveGroupReloadsLists() throws {
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        personRepo.people = [person]

        makeSUT()

        XCTAssertEqual(sut.people.count, 1, "Person should start in the people list")
        XCTAssertEqual(sut.available.count, 0)

        let groupedPerson = try XCTUnwrap(sut.people.first)
        sut.removeGroup(from: groupedPerson)

        XCTAssertEqual(sut.people.count, 0, "Person should no longer be in the people list after group removal")
        XCTAssertEqual(sut.available.count, 1, "Person should move to the available list after group removal")
        XCTAssertEqual(sut.available.first?.id, person.id)
    }

    // MARK: - Add Group

    func testAddGroupAppendsGroupId() throws {
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [])
        personRepo.people = [person]

        makeSUT()

        sut.addGroup(to: [person.id])

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertTrue(saved.groupIds.contains(group.id), "addGroup should append the group ID to the person's groupIds")
    }

    func testAddGroupSkipsDuplicate() throws {
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        personRepo.people = [person]

        makeSUT()

        sut.addGroup(to: [person.id])

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        let matchCount = saved.groupIds.filter { $0 == group.id }.count
        XCTAssertEqual(matchCount, 1, "Group ID should appear exactly once even when addGroup is called on a person who already has it")
    }

    func testAddGroupSavesEachPerson() {
        let alice = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [])
        let bob = TestFactory.makePerson(name: "Bob", cadenceId: cadenceId, groupIds: [])
        personRepo.people = [alice, bob]

        makeSUT()

        // savedPersons is empty after init (load doesn't call save)
        XCTAssertTrue(personRepo.savedPersons.isEmpty, "Precondition: no saves from init")

        sut.addGroup(to: [alice.id, bob.id])

        XCTAssertEqual(personRepo.savedPersons.count, 2, "addGroup should save each person individually")
    }

    func testAddGroupIgnoresUnknownIds() {
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [])
        personRepo.people = [person]

        makeSUT()

        let unknownId = UUID()
        let saveCountBefore = personRepo.savedPersons.count

        sut.addGroup(to: [unknownId])

        XCTAssertEqual(personRepo.savedPersons.count, saveCountBefore,
                       "addGroup should not save anything when given unknown person IDs")
    }
}
