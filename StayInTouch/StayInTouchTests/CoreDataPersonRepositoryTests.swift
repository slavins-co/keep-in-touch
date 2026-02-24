//
//  CoreDataPersonRepositoryTests.swift
//  StayInTouchTests
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

    private func makePerson(
        name: String,
        groupId: UUID,
        isPaused: Bool,
        isTracked: Bool,
        tagIds: [UUID] = []
    ) -> Person {
        Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: name,
            initials: String(name.prefix(2)),
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: tagIds,
            lastTouchAt: nil,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: isPaused,
            isTracked: isTracked,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            contactUnavailable: false,
            groupAddedAt: Date(),
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
    }
}
