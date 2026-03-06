//
//  CoreDataTouchEventRepositoryTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class CoreDataTouchEventRepositoryTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var repo: CoreDataTouchEventRepository!

    override func setUp() {
        super.setUp()
        let stack = CoreDataTestStack()
        context = stack.container.viewContext
        repo = CoreDataTouchEventRepository(context: context)
    }

    // MARK: - Fetch

    func testFetchNonExistentIdReturnsNil() {
        XCTAssertNil(repo.fetch(id: UUID()))
    }

    func testFetchAllForPersonOnEmptyReturnsEmpty() {
        XCTAssertTrue(repo.fetchAll(for: UUID()).isEmpty)
    }

    func testFetchAllReturnsSortedByDateDescending() throws {
        let personId = UUID()
        let older = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 1_000_000))
        let newer = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 2_000_000))

        try repo.save(older)
        try repo.save(newer)

        let results = repo.fetchAll(for: personId)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].at > results[1].at, "Newest event should be first")
    }

    func testFetchAllFiltersToCorrectPersonId() throws {
        let personA = UUID()
        let personB = UUID()

        try repo.save(TestFactory.makeTouchEvent(personId: personA))
        try repo.save(TestFactory.makeTouchEvent(personId: personB))
        try repo.save(TestFactory.makeTouchEvent(personId: personA))

        XCTAssertEqual(repo.fetchAll(for: personA).count, 2)
        XCTAssertEqual(repo.fetchAll(for: personB).count, 1)
    }

    func testFetchMostRecentReturnsLatestEvent() throws {
        let personId = UUID()
        let older = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 1_000_000))
        let newer = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 2_000_000))

        try repo.save(older)
        try repo.save(newer)

        let mostRecent = repo.fetchMostRecent(for: personId)
        XCTAssertEqual(mostRecent?.id, newer.id)
    }

    func testFetchMostRecentOnEmptyReturnsNil() {
        XCTAssertNil(repo.fetchMostRecent(for: UUID()))
    }

    // MARK: - Save / Batch

    func testBatchSaveMultipleEvents() throws {
        let personId = UUID()
        let events = [
            TestFactory.makeTouchEvent(personId: personId, method: .call),
            TestFactory.makeTouchEvent(personId: personId, method: .text),
            TestFactory.makeTouchEvent(personId: personId, method: .irl)
        ]

        try repo.batchSave(events)

        XCTAssertEqual(repo.fetchAll(for: personId).count, 3)
    }

    // MARK: - Delete

    func testDeleteNonExistentIdDoesNotThrow() {
        XCTAssertNoThrow(try repo.delete(id: UUID()))
    }
}
