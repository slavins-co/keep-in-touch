//
//  TagContactsViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class TagContactsViewModelTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var tag: Tag!
    private var otherTagId: UUID!
    private var groupId: UUID!
    private var sut: TagContactsViewModel!

    override func setUp() {
        super.setUp()
        personRepo = MockPersonRepository()
        tag = TestFactory.makeTag(id: UUID(), name: "Work")
        otherTagId = UUID()
        groupId = UUID()
    }

    /// Helper: create the SUT after configuring personRepo.people.
    /// The init calls load(), so people must be set first.
    private func makeSUT() {
        sut = TagContactsViewModel(tag: tag, personRepository: personRepo)
    }

    // MARK: - Load

    func testLoadSplitsPeopleByTag() {
        let tagged = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        let untagged = TestFactory.makePerson(name: "Bob", groupId: groupId, tagIds: [])
        personRepo.people = [tagged, untagged]

        makeSUT()

        XCTAssertEqual(sut.people.count, 1)
        XCTAssertEqual(sut.people.first?.id, tagged.id)
        XCTAssertEqual(sut.available.count, 1)
        XCTAssertEqual(sut.available.first?.id, untagged.id)
    }

    func testLoadSortsByName() {
        let charlie = TestFactory.makePerson(name: "Charlie", groupId: groupId, tagIds: [tag.id])
        let alice = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        let bob = TestFactory.makePerson(name: "Bob", groupId: groupId, tagIds: [])
        personRepo.people = [charlie, alice, bob]

        makeSUT()

        XCTAssertEqual(sut.people.map(\.displayName), ["Alice", "Charlie"])
        XCTAssertEqual(sut.available.map(\.displayName), ["Bob"])
    }

    // MARK: - Remove Tag

    func testRemoveTagRemovesTagIdFromPerson() throws {
        let person = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id, otherTagId])
        personRepo.people = [person]

        makeSUT()

        let taggedPerson = try XCTUnwrap(sut.people.first)
        sut.removeTag(from: taggedPerson)

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertEqual(saved.tagIds, [otherTagId])
    }

    func testRemoveTagSavesToRepo() throws {
        let person = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        personRepo.people = [person]

        makeSUT()

        let taggedPerson = try XCTUnwrap(sut.people.first)
        sut.removeTag(from: taggedPerson)

        XCTAssertFalse(personRepo.savedPersons.isEmpty, "removeTag should save the updated person to the repository")
    }

    func testRemoveTagPostsNotification() throws {
        let person = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        personRepo.people = [person]

        makeSUT()

        let taggedPerson = try XCTUnwrap(sut.people.first)

        let expectation = expectation(forNotification: .personDidChange, object: nil)

        sut.removeTag(from: taggedPerson)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRemoveTagReloadsLists() throws {
        let person = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        personRepo.people = [person]

        makeSUT()

        XCTAssertEqual(sut.people.count, 1, "Person should start in the people list")
        XCTAssertEqual(sut.available.count, 0)

        let taggedPerson = try XCTUnwrap(sut.people.first)
        sut.removeTag(from: taggedPerson)

        XCTAssertEqual(sut.people.count, 0, "Person should no longer be in the people list after tag removal")
        XCTAssertEqual(sut.available.count, 1, "Person should move to the available list after tag removal")
        XCTAssertEqual(sut.available.first?.id, person.id)
    }

    // MARK: - Add Tag

    func testAddTagAppendsTagId() throws {
        let person = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [])
        personRepo.people = [person]

        makeSUT()

        sut.addTag(to: [person.id])

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        XCTAssertTrue(saved.tagIds.contains(tag.id), "addTag should append the tag ID to the person's tagIds")
    }

    func testAddTagSkipsDuplicate() throws {
        let person = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        personRepo.people = [person]

        makeSUT()

        sut.addTag(to: [person.id])

        let saved = try XCTUnwrap(personRepo.savedPersons.last)
        let matchCount = saved.tagIds.filter { $0 == tag.id }.count
        XCTAssertEqual(matchCount, 1, "Tag ID should appear exactly once even when addTag is called on a person who already has it")
    }

    func testAddTagSavesEachPerson() {
        let alice = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [])
        let bob = TestFactory.makePerson(name: "Bob", groupId: groupId, tagIds: [])
        personRepo.people = [alice, bob]

        makeSUT()

        // savedPersons is empty after init (load doesn't call save)
        XCTAssertTrue(personRepo.savedPersons.isEmpty, "Precondition: no saves from init")

        sut.addTag(to: [alice.id, bob.id])

        XCTAssertEqual(personRepo.savedPersons.count, 2, "addTag should save each person individually")
    }

    func testAddTagIgnoresUnknownIds() {
        let person = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [])
        personRepo.people = [person]

        makeSUT()

        let unknownId = UUID()
        let saveCountBefore = personRepo.savedPersons.count

        sut.addTag(to: [unknownId])

        XCTAssertEqual(personRepo.savedPersons.count, saveCountBefore,
                       "addTag should not save anything when given unknown person IDs")
    }
}
