//
//  CoreDataPersonRepositoryTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class CoreDataPersonRepositoryTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var repo: CoreDataPersonRepository!

    override func setUp() {
        super.setUp()
        let stack = CoreDataTestStack()
        context = stack.container.viewContext
        repo = CoreDataPersonRepository(context: context)
    }

    func testFetchTrackedExcludesPausedAndUntracked() throws {
        let groupId = UUID()
        let active = makePerson(name: "Active", groupId: groupId, isPaused: false, isTracked: true)
        let paused = makePerson(name: "Paused", groupId: groupId, isPaused: true, isTracked: true)
        let untracked = makePerson(name: "Untracked", groupId: groupId, isPaused: false, isTracked: false)

        try repo.save(active)
        try repo.save(paused)
        try repo.save(untracked)

        let tracked = repo.fetchTracked(includePaused: false)
        XCTAssertEqual(tracked.count, 1)
        XCTAssertEqual(tracked.first?.displayName, "Active")

        let trackedIncludingPaused = repo.fetchTracked(includePaused: true)
        XCTAssertEqual(trackedIncludingPaused.count, 2)
    }

    func testFetchByGroupFiltersCorrectly() throws {
        let groupA = UUID()
        let groupB = UUID()
        let personA = makePerson(name: "A", groupId: groupA, isPaused: false, isTracked: true)
        let personB = makePerson(name: "B", groupId: groupB, isPaused: false, isTracked: true)

        try repo.save(personA)
        try repo.save(personB)

        let results = repo.fetchByGroup(id: groupA, includePaused: false)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.displayName, "A")
    }

    func testFetchByTagFiltersCorrectly() throws {
        let groupId = UUID()
        let tagId = UUID()
        let tagged = makePerson(name: "Tagged", groupId: groupId, isPaused: false, isTracked: true, tagIds: [tagId])
        let untagged = makePerson(name: "Untagged", groupId: groupId, isPaused: false, isTracked: true)

        try repo.save(tagged)
        try repo.save(untagged)

        let results = repo.fetchByTag(id: tagId, includePaused: false)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.displayName, "Tagged")
    }

    func testSearchByNameIsCaseInsensitive() throws {
        let groupId = UUID()
        let person = makePerson(name: "Sarah Chen", groupId: groupId, isPaused: false, isTracked: true)
        try repo.save(person)

        let results = repo.searchByName("sarah", includePaused: false)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.displayName, "Sarah Chen")
    }

    // MARK: - Edge Cases: Fetch

    func testFetchNonExistentIdReturnsNil() {
        XCTAssertNil(repo.fetch(id: UUID()))
    }

    func testFetchAllOnEmptyStoreReturnsEmpty() {
        XCTAssertTrue(repo.fetchAll().isEmpty)
    }

    func testFetchTrackedOnEmptyStoreReturnsEmpty() {
        XCTAssertTrue(repo.fetchTracked(includePaused: false).isEmpty)
        XCTAssertTrue(repo.fetchTracked(includePaused: true).isEmpty)
    }

    func testFetchByTagWithNoPeopleReturnsEmpty() {
        XCTAssertTrue(repo.fetchByTag(id: UUID(), includePaused: false).isEmpty)
    }

    func testSearchByNameNoMatchReturnsEmpty() throws {
        let person = makePerson(name: "Alice", groupId: UUID(), isPaused: false, isTracked: true)
        try repo.save(person)

        XCTAssertTrue(repo.searchByName("zzz", includePaused: false).isEmpty)
    }

    // MARK: - Edge Cases: Save / Delete

    func testSaveUpdatesExistingPerson() throws {
        let groupId = UUID()
        let person = makePerson(name: "Original", groupId: groupId, isPaused: false, isTracked: true)
        try repo.save(person)

        let updated = makePerson(id: person.id, name: "Updated", groupId: groupId, isPaused: false, isTracked: true)
        try repo.save(updated)

        let all = repo.fetchAll()
        XCTAssertEqual(all.count, 1, "Should upsert, not duplicate")
        XCTAssertEqual(all.first?.displayName, "Updated")
    }

    func testDeleteNonExistentIdDoesNotThrow() {
        XCTAssertNoThrow(try repo.delete(id: UUID()))
    }

    func testBatchSaveMultiplePersons() throws {
        let groupId = UUID()
        let people = [
            makePerson(name: "Alice", groupId: groupId, isPaused: false, isTracked: true),
            makePerson(name: "Bob", groupId: groupId, isPaused: false, isTracked: true),
            makePerson(name: "Carol", groupId: groupId, isPaused: false, isTracked: true)
        ]

        try repo.batchSave(people)

        XCTAssertEqual(repo.fetchAll().count, 3)
    }

    // MARK: - Overdue

    func testFetchOverdueReturnsPeoplePastSLA() throws {
        let groupId = UUID()
        let groupRepo = CoreDataGroupRepository(context: context)
        let group = TestFactory.makeGroup(id: groupId, name: "Weekly", frequencyDays: 7)
        try groupRepo.save(group)

        let overduePerson = makePerson(
            name: "Overdue",
            groupId: groupId,
            isPaused: false,
            isTracked: true,
            lastTouchAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        )
        try repo.save(overduePerson)

        let results = repo.fetchOverdue(referenceDate: Date())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.displayName, "Overdue")
    }

    func testFetchOverdueExcludesPausedPeople() throws {
        let groupId = UUID()
        let groupRepo = CoreDataGroupRepository(context: context)
        let group = TestFactory.makeGroup(id: groupId, name: "Weekly", frequencyDays: 7)
        try groupRepo.save(group)

        let pausedOverdue = makePerson(
            name: "PausedOverdue",
            groupId: groupId,
            isPaused: true,
            isTracked: true,
            lastTouchAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        )
        try repo.save(pausedOverdue)

        let results = repo.fetchOverdue(referenceDate: Date())
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Helpers

    private func makePerson(
        id: UUID = UUID(),
        name: String,
        groupId: UUID,
        isPaused: Bool,
        isTracked: Bool,
        tagIds: [UUID] = [],
        lastTouchAt: Date? = nil
    ) -> Person {
        Person(
            id: id,
            cnIdentifier: nil,
            displayName: name,
            initials: String(name.prefix(2)),
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: tagIds,
            lastTouchAt: lastTouchAt,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: isPaused,
            isTracked: isTracked,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            groupAddedAt: Date(),
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
    }
}
